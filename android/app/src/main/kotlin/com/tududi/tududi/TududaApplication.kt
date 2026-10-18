package com.tududi.tududi

import android.app.Application
import android.content.Context
import androidx.glance.appwidget.updateAll
import com.tududi.core.TududiCore
import com.tududi.tududi.widget.TaskWidget
import com.tududi.tududi.widget.WidgetOverlays

class TududaApplication : Application() {
    /** Status changes made in the app that the server does not know yet (widget display only). */
    val overlays = WidgetOverlays()

    /**
     * The native core. Created on first use, off the main thread where possible: it opens the
     * Keystore-backed vault. Every repository change redraws the widgets.
     */
    val core: TududiCore by lazy {
        TududiCore.from(this).also { core ->
            core.repository.addOnChangedListener {
                overlays.prune(core.repository.state.value.board)
                renderWidgets()
            }
        }
    }

    suspend fun renderWidgets() {
        TaskWidget().updateAll(this)
    }

    /** The vault changed under the repository (provision / clear): reload and refetch. */
    suspend fun onSessionChanged() {
        overlays.clear()
        core.repository.reset()
        core.repository.refresh()
    }
}

val Context.tududa: TududaApplication
    get() = applicationContext as TududaApplication
