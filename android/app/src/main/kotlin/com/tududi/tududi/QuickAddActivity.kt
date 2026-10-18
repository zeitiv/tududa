package com.tududi.tududi

import android.content.Context
import android.content.Intent
import android.os.Bundle
import com.tududi.tududi.widget.WidgetWork
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Transparent host of the Flutter quick-add sheet, opened from the widget's "+".
 *
 * Channel `tududa/quickadd`:
 *  - Dart -> native `close`: finishes the activity and schedules a widget refresh.
 *  - native -> Dart `open`: sent whenever the activity comes to the front, so a reused engine can
 *    reset the sheet to an empty state. It may arrive before Dart registered its handler (cold
 *    engine); Dart shows a fresh sheet on startup anyway.
 */
class QuickAddActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Make sure the cached engine exists before FlutterActivity asks for it.
        QuickAddEngine.get(this)
        super.onCreate(savedInstanceState)
    }

    override fun getCachedEngineId(): String = QuickAddEngine.ENGINE_ID

    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

    override fun getDartEntrypointLibraryUri(): String = QuickAddEngine.LIBRARY_URI

    override fun getDartEntrypointFunctionName(): String = QuickAddEngine.ENTRYPOINT

    // The bridges and plugins were registered when the engine was created.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "close" -> {
                        close()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onResume() {
        super.onResume()
        channel?.invokeMethod("open", null)
    }

    private fun close() {
        if (isFinishing) return
        // Give the Dart outbox a moment to push the new task, then refetch and redraw the widgets.
        WidgetWork.refreshSoon(applicationContext)
        finish()
        @Suppress("DEPRECATION")
        overridePendingTransition(0, 0)
    }

    companion object {
        const val CHANNEL = "tududa/quickadd"

        fun intent(context: Context): Intent =
            Intent(context, QuickAddActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
}
