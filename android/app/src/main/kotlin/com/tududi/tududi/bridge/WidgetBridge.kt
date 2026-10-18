package com.tududi.tududi.bridge

import com.tududi.core.TududiCore
import com.tududi.tududi.widget.WidgetOverlays
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * `tududa/widget` (methods) and `tududa/widget/events` (change sequence stream); contract in
 * android/CHANNELS.md. [renderWidgets] redraws all widget instances from the repository state.
 */
class WidgetBridge(
    private val core: () -> TududiCore,
    private val overlays: WidgetOverlays,
    private val renderWidgets: suspend () -> Unit,
    scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.IO),
    postToMain: (Runnable) -> Unit = MainThread::post,
    private val background: CoroutineScope = scope,
) : ChannelBridge(scope, postToMain) {

    fun attach(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
        EventChannel(messenger, EVENTS_CHANNEL).setStreamHandler(events)
    }

    override suspend fun dispatch(call: MethodCall): Any? =
        when (call.method) {
            "refresh" -> {
                renderWidgets()
                // Refetch in the background; the repository listener redraws when it lands.
                background.launch { runCatching { core().repository.refresh() } }
                null
            }
            "overlay" -> {
                overlays.set(call.require("uid", String::class.java), call.requireLong("status").toInt())
                renderWidgets()
                null
            }
            "pendingChanges" -> core().changeLog.since(call.requireLong("sinceSeq")).map {
                mapOf("seq" to it.seq, "uid" to it.uid, "status" to it.status, "atMillis" to it.atMillis)
            }
            "ack" -> {
                core().changeLog.ack(call.requireLong("seq"))
                null
            }
            else -> NotImplemented
        }

    /** Emits the latest change sequence on listen and whenever it moves. */
    val events = object : EventChannel.StreamHandler {
        private var job: Job? = null

        override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
            job?.cancel()
            job = scope.launch {
                core().changeLog.latestSeqFlow.collect { seq ->
                    postToMain(Runnable { sink.success(seq) })
                }
            }
        }

        override fun onCancel(arguments: Any?) {
            job?.cancel()
            job = null
        }
    }

    companion object {
        const val CHANNEL = "tududa/widget"
        const val EVENTS_CHANNEL = "tududa/widget/events"
    }
}
