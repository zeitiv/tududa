package com.tududi.tududi.widget

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Time, time zone, date and locale changes: the widget's "today" and labels may be wrong now. */
class TimeChangeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_LOCALE_CHANGED,
            -> WidgetWork.onClockChanged(context.applicationContext)
        }
    }
}
