package com.tududi.tududi.bridge

import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/** Records what a Flutter call received. */
class RecordingResult : MethodChannel.Result {
    var success: Any? = null
    var errorCode: String? = null
    var errorMessage: String? = null
    var notImplemented = false
    var replies = 0

    override fun success(result: Any?) {
        success = result
        replies++
    }

    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
        this.errorCode = errorCode
        this.errorMessage = errorMessage
        replies++
    }

    override fun notImplemented() {
        notImplemented = true
        replies++
    }
}

class RecordingSink : EventChannel.EventSink {
    val events = mutableListOf<Any?>()
    override fun success(event: Any?) {
        events += event
    }

    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) = Unit
    override fun endOfStream() = Unit
}
