package com.tududi.tududi.bridge

import com.tududi.core.TududiCore
import com.tududi.core.session.ProvisionException
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.BinaryMessenger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * `tududa/session`: credentials and cookies in the encrypted vault (contract: android/CHANNELS.md).
 *
 * [core] is a provider so the Keystore-backed vault is only opened on the IO dispatcher, never while
 * the engine is being set up. [onSessionChanged] runs in the background after `provision` and
 * `clear` to reload the widget's board.
 */
class SessionBridge(
    private val core: () -> TududiCore,
    private val onSessionChanged: suspend () -> Unit,
    scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.IO),
    postToMain: (Runnable) -> Unit = MainThread::post,
    private val background: CoroutineScope = scope,
) : ChannelBridge(scope, postToMain) {

    fun attach(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override suspend fun dispatch(call: MethodCall): Any? {
        val sessions = core().sessionManager
        return when (call.method) {
            "provision" -> {
                val serverUrl = call.require("serverUrl", String::class.java)
                val allowInsecure = call.require("allowInsecureHttp", Boolean::class.javaObjectType)
                val email = call.require("email", String::class.java)
                val password = call.require("password", String::class.java)
                val accountUid = call.require("accountUid", String::class.java)
                try {
                    sessions.provision(serverUrl, allowInsecure, email, password, accountUid)
                } catch (e: ProvisionException) {
                    throw BridgeException("INVALID_ARGUMENT", e.message ?: "Invalid server URL")
                }
                notifyChanged()
                null
            }
            "clear" -> {
                sessions.clear()
                notifyChanged()
                null
            }
            "getCredentials" -> sessions.credentials()?.let {
                mapOf("serverUrl" to it.serverUrl, "email" to it.email, "password" to it.password)
            }
            "readCookies" -> sessions.readFlutterCookies(call.require("host", String::class.java))
            "writeCookies" -> {
                val host = call.require("host", String::class.java)
                val cookies = call.require("cookies", List::class.java).map {
                    it as? String ?: throw BridgeException("INVALID_ARGUMENT", "cookies must be strings")
                }
                sessions.writeFlutterCookies(host, cookies)
                null
            }
            "state" -> sessions.state().let {
                mapOf(
                    "provisioned" to it.provisioned,
                    "serverUrl" to it.serverUrl,
                    "accountUid" to it.accountUid,
                    "loginFailed" to it.loginFailed,
                )
            }
            else -> NotImplemented
        }
    }

    // Reply first; the (possibly slow) board refetch must not hold up the Dart caller.
    private fun notifyChanged() {
        background.launch { runCatching { onSessionChanged() } }
    }

    companion object {
        const val CHANNEL = "tududa/session"
    }
}
