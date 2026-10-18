package com.tududi.tududi.widget

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.time.Duration
import java.time.ZonedDateTime
import java.util.concurrent.TimeUnit

/** Scheduling of the widget's background refreshes (the provider's updatePeriodMillis is 0). */
object WidgetWork {
    const val PERIODIC = "tududa_widget_refresh"
    const val MIDNIGHT = "tududa_widget_midnight"
    const val DAY_CHANGED = "tududa_widget_day_changed"
    const val REFRESH_ONCE = "tududa_widget_refresh_once"
    const val PERIOD_MINUTES = 30L

    /** Margin after 00:00 so "today" has certainly rolled over on the server too. */
    private const val MIDNIGHT_SLACK_SECONDS = 5L

    private val needsNetwork = Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()

    /** Idempotent: the 30-minute refresh (network required) and the next midnight. */
    fun schedule(context: Context) {
        val wm = WorkManager.getInstance(context)
        wm.enqueueUniquePeriodicWork(
            PERIODIC,
            ExistingPeriodicWorkPolicy.KEEP,
            PeriodicWorkRequestBuilder<WidgetRefreshWorker>(PERIOD_MINUTES, TimeUnit.MINUTES)
                .setConstraints(needsNetwork)
                .build(),
        )
        scheduleMidnight(context, replace = false)
    }

    fun cancel(context: Context) {
        val wm = WorkManager.getInstance(context)
        wm.cancelUniqueWork(PERIODIC)
        wm.cancelUniqueWork(MIDNIGHT)
    }

    fun scheduleMidnight(context: Context, now: ZonedDateTime = ZonedDateTime.now(), replace: Boolean) {
        WorkManager.getInstance(context).enqueueUniqueWork(
            MIDNIGHT,
            if (replace) ExistingWorkPolicy.REPLACE else ExistingWorkPolicy.KEEP,
            OneTimeWorkRequestBuilder<MidnightWorker>()
                .setInitialDelay(delayUntilNextMidnight(now).toMillis(), TimeUnit.MILLISECONDS)
                .build(),
        )
    }

    /** Clock, time zone or locale changed: redraw now and re-arm midnight. */
    fun onClockChanged(context: Context) {
        WorkManager.getInstance(context).enqueueUniqueWork(
            DAY_CHANGED,
            ExistingWorkPolicy.REPLACE,
            OneTimeWorkRequestBuilder<MidnightWorker>().build(),
        )
    }

    /** One refresh, a few seconds from now: lets the Flutter outbox push before the board is refetched. */
    fun refreshSoon(context: Context, delaySeconds: Long = 3) {
        WorkManager.getInstance(context).enqueueUniqueWork(
            REFRESH_ONCE,
            ExistingWorkPolicy.REPLACE,
            OneTimeWorkRequestBuilder<WidgetRefreshWorker>()
                .setInitialDelay(delaySeconds, TimeUnit.SECONDS)
                .setConstraints(needsNetwork)
                .build(),
        )
    }

    /** Time from [now] to just after the next local midnight (DST-safe: computed on the calendar). */
    fun delayUntilNextMidnight(now: ZonedDateTime): Duration {
        val next = now.toLocalDate().plusDays(1).atStartOfDay(now.zone).plusSeconds(MIDNIGHT_SLACK_SECONDS)
        return Duration.between(now, next)
    }
}
