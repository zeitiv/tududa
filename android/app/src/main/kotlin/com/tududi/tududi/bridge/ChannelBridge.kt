package com.tududi.tududi.bridge

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/** Error reported to Dart as a `PlatformException(code, message)`. */
class BridgeException(val code: String, message: String) : Exception(message)

/** Marker result: the method is unknown. */
internal object NotImplemented

/**
 * Shared plumbing of the channel handlers: every call runs on [scope] (IO by default) and its
 * reply is posted on the main thread through [postToMain]. Subclasses implement [dispatch] as a
 * plain suspend function, which is also what the unit tests call.
 */
abstract class ChannelBridge(
    protected val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.IO),
    protected val postToMain: (Runnable) -> Unit = MainThread::post,
) : MethodChannel.MethodCallHandler {

    internal abstract suspend fun dispatch(call: MethodCall): Any?

    final override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            val outcome = try {
                Result.success(dispatch(call))
            } catch (e: CancellationException) {
                throw e
            } catch (e: Throwable) {
                Result.failure(e)
            }
            postToMain(
                Runnable {
                    outcome.fold(
                        onSuccess = { if (it === NotImplemented) result.notImplemented() else result.success(it) },
                        onFailure = { e ->
                            when (e) {
                                is BridgeException -> result.error(e.code, e.message, null)
                                // Only the type: messages of unexpected errors must never carry secrets.
                                else -> result.error("NATIVE_ERROR", e.javaClass.simpleName, null)
                            }
                        },
                    )
                },
            )
        }
    }

    protected fun <T> MethodCall.require(key: String, type: Class<T>): T {
        val value = argument<Any?>(key) ?: throw BridgeException("INVALID_ARGUMENT", "Missing argument: $key")
        if (!type.isInstance(value)) throw BridgeException("INVALID_ARGUMENT", "Wrong type for argument: $key")
        return type.cast(value)!!
    }

    protected fun MethodCall.requireLong(key: String): Long =
        (argument<Any?>(key) as? Number)?.toLong() ?: throw BridgeException("INVALID_ARGUMENT", "Missing number argument: $key")
}

internal object MainThread {
    private val handler by lazy { Handler(Looper.getMainLooper()) }
    fun post(r: Runnable) {
        handler.post(r)
    }
}
