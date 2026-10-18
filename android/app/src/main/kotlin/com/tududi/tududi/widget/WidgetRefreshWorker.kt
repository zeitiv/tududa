package com.tududi.tududi.widget

import android.content.Context
import androidx.glance.appwidget.updateAll
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.tududi.tududi.tududa

/** Refetches the board and redraws; every 30 minutes with a network, and once after quick add. */
class WidgetRefreshWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        val core = applicationContext.tududa.core
        if (core.sessionManager.state().provisioned) core.repository.refresh()
        TaskWidget().updateAll(applicationContext)
        return Result.success()
    }
}
