package com.tududi.core.vault

import com.tududi.core.sync.WidgetChange
import kotlinx.serialization.Serializable

/**
 * Everything the native side persists, as one encrypted blob (see [Vault]).
 *
 * The [WidgetChange] log lives here too so that "task confirmed by the server" and "change
 * recorded" can be written atomically, and so it is wiped together with the credentials.
 */
@Serializable
data class VaultData(
    val serverUrl: String = "",
    val allowInsecureHttp: Boolean = false,
    val email: String = "",
    val password: String = "",
    val accountUid: String = "",
    /** OkHttp `Cookie.toString()` values for the native client. */
    val nativeCookies: List<String> = emptyList(),
    /** Cookies of the Flutter (Dart) client, keyed by host. */
    val flutterCookies: Map<String, List<String>> = emptyMap(),
    val autoLoginDisabled: Boolean = false,
    val loginBackoffUntilMillis: Long = 0,
    /** Raw JSON of the last Today response (the widget's offline cache). */
    val boardJson: String? = null,
    val boardAtMillis: Long = 0,
    val changes: List<WidgetChange> = emptyList(),
    /** Last sequence number handed out; never decreases except by [Vault.clear]. */
    val lastChangeSeq: Long = 0,
) {
    val hasCredentials: Boolean get() = email.isNotBlank() && password.isNotBlank()

    /** Never prints the password, cookies or cached tasks. */
    override fun toString(): String =
        "VaultData(serverUrl=$serverUrl, email=$email, accountUid=$accountUid, <secrets redacted>)"
}
