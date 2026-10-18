package com.tududi.tududi

import android.app.ActivityManager
import android.content.Context
import android.os.Handler
import android.os.Looper
import com.tududi.tududi.bridge.Bridges
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * The pre-warmed Flutter engine behind [QuickAddActivity]. It runs `quickAddMain` from
 * `package:tududa/quick_add_main.dart` (its own entrypoint, no app shell) and stays cached after
 * the activity finishes, so the next "+" opens instantly. The session/widget bridges are registered
 * on it at creation; only the `tududa/quickadd` channel needs the activity.
 */
object QuickAddEngine {
    const val ENGINE_ID = "tududa_quick_add"
    const val LIBRARY_URI = "package:tududa/quick_add_main.dart"
    const val ENTRYPOINT = "quickAddMain"

    /** Existing engine, or a new one started right away. Main thread only. */
    fun get(context: Context): FlutterEngine {
        val cache = FlutterEngineCache.getInstance()
        cache.get(ENGINE_ID)?.let { return it }
        val app = context.applicationContext
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(app)
        loader.ensureInitializationComplete(app, null)
        val engine = FlutterEngine(app)
        Bridges.register(engine.dartExecutor.binaryMessenger, app.tududa)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(loader.findAppBundlePath(), LIBRARY_URI, ENTRYPOINT),
        )
        cache.put(ENGINE_ID, engine)
        return engine
    }

    /** Starts the engine in the background of a user interaction; skipped on low-RAM devices. */
    fun prewarm(context: Context) {
        val app = context.applicationContext
        val am = app.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
        if (am?.isLowRamDevice == true) return
        if (FlutterEngineCache.getInstance().contains(ENGINE_ID)) return
        Handler(Looper.getMainLooper()).post { runCatching { get(app) } }
    }

    /** Drops the engine (e.g. to free memory). The next [get] starts a fresh one. */
    fun release() {
        val cache = FlutterEngineCache.getInstance()
        val engine = cache.get(ENGINE_ID) ?: return
        cache.remove(ENGINE_ID)
        engine.destroy()
    }
}
