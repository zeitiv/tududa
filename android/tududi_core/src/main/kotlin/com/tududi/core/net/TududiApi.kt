package com.tududi.core.net

import com.tududi.core.data.TaskStatus
import com.tududi.core.vault.Vault
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import java.io.IOException
import java.util.concurrent.atomic.AtomicBoolean

sealed class ApiException(message: String, cause: Throwable? = null) : Exception(message, cause) {
    /** No valid session (HTTP 401), or no server provisioned. */
    class Unauthorized : ApiException("Not signed in")

    /** Login rejected the supplied credentials. */
    class InvalidCredentials : ApiException("Invalid credentials")

    /** Server could not be reached (offline, Tailscale down, DNS, timeout). */
    class Unreachable(cause: Throwable) : ApiException("Server unreachable", cause)

    /** HTTP 429. [retryAfterSeconds] is the `Retry-After` header when the server sent one. */
    class RateLimited(val retryAfterSeconds: Long?) : ApiException("Rate limited")

    /** Refused to send the password over plain http:// without explicit opt-in. */
    class InsecureTransport : ApiException("Refusing to send credentials over http://")

    class Server(val code: Int, message: String) : ApiException(message)
}

/**
 * Thin client for the Tududi endpoints used by the widget: `POST /api/login`, `GET /api/logout`,
 * `GET /api/csrf-token`, `GET /api/tasks?type=today`, `PATCH /api/task/{uid}`. Authentication is
 * the session cookie (handled by the client's cookie jar); mutating requests carry `x-csrf-token`.
 * The server URL is read from the [vault] on every call.
 */
class TududiApi(
    private val vault: Vault,
    private val client: OkHttpClient,
) {
    private val json = Json { ignoreUnknownKeys = true }
    private val jsonType = "application/json".toMediaType()

    @Volatile
    private var csrfToken: String? = null

    suspend fun login(email: String, password: String) {
        val base = baseUrl()
        if (!base.isHttps && !vault.read().allowInsecureHttp) throw ApiException.InsecureTransport()
        val body = buildJsonObject {
            put("email", email)
            put("password", password)
        }
        csrfToken = null
        val response = execute(newRequest(base, "login").post(body.toString().toRequestBody(jsonType)).build())
        response.use {
            when {
                it.isSuccessful -> Unit
                it.code == 429 -> throw rateLimited(it)
                it.code == 401 || it.code == 400 -> throw ApiException.InvalidCredentials()
                else -> throw serverError(it)
            }
        }
    }

    /** Best effort: invalidates the server session; failures are ignored. */
    suspend fun logout() {
        csrfToken = null
        try {
            val base = baseUrl()
            execute(newRequest(base, "logout").get().build()).close()
        } catch (_: Exception) {
        }
    }

    /** Returns the raw JSON of the Today view. */
    suspend fun fetchToday(): String =
        call(newRequest(baseUrl(), listOf("tasks"), listOf("type" to "today", "include_lists" to "true")).get().build())

    /** Reopening (anything but DONE) also sends `completed_at: null`. */
    suspend fun setStatus(uid: String, status: TaskStatus): String {
        val body = buildJsonObject {
            put("status", status.code)
            if (status != TaskStatus.DONE) put("completed_at", JsonNull)
        }
        return mutate { base -> newRequest(base, "task", uid).patch(body.toString().toRequestBody(jsonType)) }
    }

    /** Runs a mutating request with a CSRF token, refreshing the token once on 403. */
    private suspend fun mutate(build: (HttpUrl) -> Request.Builder): String {
        repeat(2) { attempt ->
            val token = csrfToken ?: fetchCsrfToken().also { csrfToken = it }
            val response = execute(build(baseUrl()).header("x-csrf-token", token).build())
            response.use {
                if (it.code == 403 && attempt == 0) {
                    csrfToken = null
                    return@repeat
                }
                return readBody(it)
            }
        }
        throw ApiException.Server(403, "CSRF validation failed")
    }

    private suspend fun fetchCsrfToken(): String {
        val body = call(newRequest(baseUrl(), "csrf-token").get().build())
        val obj = json.parseToJsonElement(body) as? JsonObject
        return (obj?.get("csrfToken") as? JsonPrimitive)?.content
            ?: throw ApiException.Server(500, "No CSRF token in response")
    }

    private suspend fun call(request: Request): String = execute(request).use { readBody(it) }

    private fun readBody(response: Response): String {
        if (response.code == 401) {
            csrfToken = null
            throw ApiException.Unauthorized()
        }
        if (response.code == 429) throw rateLimited(response)
        if (!response.isSuccessful) throw serverError(response)
        return response.body?.string().orEmpty()
    }

    private fun rateLimited(response: Response) =
        ApiException.RateLimited(response.header("Retry-After")?.trim()?.toLongOrNull())

    private fun serverError(response: Response): ApiException.Server {
        val message = runCatching {
            val o = json.parseToJsonElement(response.body?.string().orEmpty()) as JsonObject
            o["error"]?.jsonPrimitive?.content
        }.getOrNull() ?: "HTTP ${response.code}"
        return ApiException.Server(response.code, message)
    }

    private suspend fun baseUrl(): HttpUrl =
        vault.read().serverUrl.trim().toHttpUrlOrNull() ?: throw ApiException.Unauthorized()

    private fun newRequest(base: HttpUrl, vararg segments: String): Request.Builder =
        newRequest(base, segments.toList(), emptyList())

    private fun newRequest(base: HttpUrl, segments: List<String>, query: List<Pair<String, String>>): Request.Builder {
        val url = base.newBuilder().addPathSegment("api")
        segments.forEach { url.addPathSegment(it) }
        query.forEach { (k, v) -> url.addQueryParameter(k, v) }
        return Request.Builder().url(url.build()).header("Accept", "application/json")
    }

    private suspend fun execute(request: Request): Response = withContext(Dispatchers.IO) {
        val call = client.newCall(request)
        coroutineScope {
            // Abort the blocking call when the coroutine is cancelled (e.g. a timeout). Once
            // execute() returned the call must stay alive so the caller can read the body.
            val finished = AtomicBoolean(false)
            val watcher = launch(start = CoroutineStart.UNDISPATCHED) {
                try {
                    awaitCancellation()
                } finally {
                    if (!finished.get()) call.cancel()
                }
            }
            try {
                call.execute()
            } catch (e: IOException) {
                throw ApiException.Unreachable(e)
            } finally {
                finished.set(true)
                watcher.cancel()
            }
        }
    }
}
