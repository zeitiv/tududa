package com.tududi.tududi.bridge

import com.tududi.tududi.TududaApplication
import io.flutter.plugin.common.BinaryMessenger

/** Registers the native bridges on a Flutter engine (the app's own and the quick-add engine). */
object Bridges {
    fun register(messenger: BinaryMessenger, app: TududaApplication) {
        SessionBridge(core = { app.core }, onSessionChanged = app::onSessionChanged).attach(messenger)
        WidgetBridge(core = { app.core }, overlays = app.overlays, renderWidgets = app::renderWidgets).attach(messenger)
    }
}
