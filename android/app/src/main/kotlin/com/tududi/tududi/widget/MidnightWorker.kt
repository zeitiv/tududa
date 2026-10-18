package com.tududi.tududi.widget

import android.content.Context
import androidx.glance.appwidget.updateAll
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.tududi.tududi.tududa

/** At midnight (and after clock, zone or locale changes): recompute "today" and "overdue", redraw. */
class MidnightWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        val core = applicationContext.tududa.core
        // Reloads the cached board so overdue/due labels are derived for the new date, then tries the server.
        core.repository.reset()
        core.repository.restoreCache()
        TaskWidget().updateAll(applicationContext)
        if (core.sessionManager.state().provisioned) core.repository.refresh()
        TaskWidget().updateAll(applicationContext)
        WidgetWork.scheduleMidnight(applicationContext, replace = true)
        return Result.success()
    }
}
