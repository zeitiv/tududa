package com.tududi.core.session

import com.tududi.core.net.TududiApi
import com.tududi.core.vault.Vault
import com.tududi.core.vault.VaultData
import kotlinx.coroutines.withTimeoutOrNull
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull

data class SessionState(
    val provisioned: Boolean,
    val serverUrl: String,
    val accountUid: String,
    val loginFailed: Boolean,
)

data class StoredCredentials(val serverUrl: String, val email: String, val password: String) {
    override fun toString(): String = "StoredCredentials(serverUrl=$serverUrl, email=$email, <redacted>)"
}

/** Thrown by [SessionManager.provision] for an unusable server URL or a refused http:// URL. */
class ProvisionException(message: String) : IllegalArgumentException(message)

/** Lifecycle of the native credentials, driven by the Flutter app through the bridge. */
class SessionManager(
    private val vault: Vault,
    private val api: TududiApi,
) {
    /**
     * Stores the credentials. When [accountUid] or [serverUrl] differs from what is stored, the
     * session cookies, login flags/backoff, board cache and change log are reset first.
     * Always re-enables silent login.
     */
    suspend fun provision(
        serverUrl: String,
        allowInsecureHttp: Boolean,
        email: String,
        password: String,
        accountUid: String,
    ) {
        val url = serverUrl.trim()
        val parsed = url.toHttpUrlOrNull() ?: throw ProvisionException("Invalid server URL")
        if (!parsed.isHttps && !allowInsecureHttp) {
            throw ProvisionException("http:// server requires allowInsecureHttp")
        }
        vault.update { old ->
            val changed = old.accountUid != accountUid || old.serverUrl != url
            val base = if (changed) {
                old.copy(
                    nativeCookies = emptyList(),
                    boardJson = null,
                    boardAtMillis = 0,
                    changes = emptyList(),
                    lastChangeSeq = 0,
                )
            } else {
                old
            }
            base.copy(
                serverUrl = url,
                allowInsecureHttp = allowInsecureHttp,
                email = email,
                password = password,
                accountUid = accountUid,
                autoLoginDisabled = false,
                loginBackoffUntilMillis = 0,
            )
        }
    }

    /** Best-effort server logout (bounded wait), then wipes the whole vault. */
    suspend fun clear() {
        withTimeoutOrNull(LOGOUT_TIMEOUT_MILLIS) { api.logout() }
        vault.clear()
    }

    suspend fun state(): SessionState = vault.read().let {
        SessionState(
            provisioned = it.serverUrl.isNotBlank() && it.hasCredentials,
            serverUrl = it.serverUrl,
            accountUid = it.accountUid,
            loginFailed = it.autoLoginDisabled,
        )
    }

    suspend fun credentials(): StoredCredentials? = vault.read().takeIf { it.hasCredentials && it.serverUrl.isNotBlank() }
        ?.let { StoredCredentials(it.serverUrl, it.email, it.password) }

    suspend fun readFlutterCookies(host: String): List<String> = vault.read().flutterCookies[host].orEmpty()

    suspend fun writeFlutterCookies(host: String, cookies: List<String>) {
        vault.update { d: VaultData ->
            d.copy(flutterCookies = if (cookies.isEmpty()) d.flutterCookies - host else d.flutterCookies + (host to cookies))
        }
    }

    companion object {
        const val LOGOUT_TIMEOUT_MILLIS = 5_000L
    }
}
