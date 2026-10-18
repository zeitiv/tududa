package com.tududi.core

import com.tududi.core.vault.InMemoryVault
import com.tududi.core.vault.VaultData
import okhttp3.mockwebserver.Dispatcher
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.RecordedRequest
import java.util.concurrent.CopyOnWriteArrayList

/**
 * Minimal in-memory imitation of the Tududi session + CSRF behaviour, based on the real web
 * client's calls: login sets a session cookie, `/api/csrf-token` returns a per-session token
 * that mutating requests must echo in `x-csrf-token`.
 */
class FakeTududi(
    private val email: String = "user@example.com",
    private val password: String = "secret-pass",
) : Dispatcher() {
    val server = MockWebServer().apply { dispatcher = this@FakeTududi }
    val requests = CopyOnWriteArrayList<RecordedRequest>()
    val sessions = mutableMapOf<String, String>() // session id -> csrf token
    var loginCount = 0
    var logoutCount = 0
    var lastLogoutCookie: String? = null
    var todayBody = """{"tasks":[{"uid":"a1","name":"Task A","status":0,"due_date":"2026-10-18"}]}"""

    /** After this many rejected logins the server answers 429 (lockout) to every login. 0 = never. */
    var lockoutAfterBadLogins = 0
    var retryAfterSeconds: Int? = null
    private var badLogins = 0
    private var counter = 0

    fun url() = server.url("/")

    /** Expire every server session (the next authenticated call gets 401). */
    fun expireAllSessions() = sessions.clear()

    /** Expire one session only. */
    fun expireSession(sid: String) = sessions.remove(sid)

    /** Rotate the CSRF token of one session. */
    fun rotateCsrf(sid: String) {
        sessions[sid] = "rotated-${++counter}"
    }

    fun lockedOut() = lockoutAfterBadLogins > 0 && badLogins >= lockoutAfterBadLogins

    override fun dispatch(request: RecordedRequest): MockResponse {
        requests += request
        val path = request.requestUrl!!.encodedPath
        if (path == "/api/login" && request.method == "POST") {
            loginCount++
            if (lockedOut()) {
                return MockResponse().setResponseCode(429).apply {
                    retryAfterSeconds?.let { addHeader("Retry-After", it.toString()) }
                }.setBody("""{"error":"Too many attempts"}""")
            }
            val body = request.body.readUtf8()
            if (!body.contains("\"$email\"") || !body.contains("\"$password\"")) {
                badLogins++
                return MockResponse().setResponseCode(401).setBody("""{"errors":["Invalid credentials"]}""")
            }
            val sid = "sid-${++counter}"
            sessions[sid] = "csrf-$counter"
            return MockResponse().addHeader("Set-Cookie", "tududi.sid=$sid; Path=/; HttpOnly")
                .setBody("""{"user":{"email":"$email"}}""")
        }
        val sid = request.getHeader("Cookie")?.substringAfter("tududi.sid=", "")?.substringBefore(';')
        if (path == "/api/logout") {
            logoutCount++
            lastLogoutCookie = request.getHeader("Cookie")
            sid?.let { sessions.remove(it) }
            return MockResponse().setBody("""{"message":"ok"}""")
        }
        val csrf = sid?.let { sessions[it] } ?: return MockResponse().setResponseCode(401)
            .setBody("""{"error":"Authentication required"}""")
        if (request.method != "GET" && request.getHeader("x-csrf-token") != csrf) {
            return MockResponse().setResponseCode(403).setBody("""{"error":"invalid csrf token"}""")
        }
        return when {
            path == "/api/csrf-token" -> MockResponse().setBody("""{"csrfToken":"$csrf"}""")
            path == "/api/tasks" -> MockResponse().setBody(todayBody)
            path.startsWith("/api/task/") && request.method == "PATCH" -> MockResponse().setBody("""{"uid":"a1"}""")
            else -> MockResponse().setResponseCode(404)
        }
    }
}

/** Vault provisioned for [fake] (credentials default to the fake's valid ones). */
fun provisionedVault(
    fake: FakeTududi,
    email: String = "user@example.com",
    password: String = "secret-pass",
    accountUid: String = "acc-1",
) = InMemoryVault(
    VaultData(
        serverUrl = fake.url().toString(),
        allowInsecureHttp = true,
        email = email,
        password = password,
        accountUid = accountUid,
    ),
)
