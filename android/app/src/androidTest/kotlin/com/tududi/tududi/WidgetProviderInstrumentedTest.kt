package com.tududi.tududi

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.test.core.app.ApplicationProvider
import com.tududi.tududi.widget.TaskWidgetReceiver
import com.tududi.tududi.widget.TimeChangeReceiver
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** The manifest wiring a launcher relies on: widget provider, time receiver, quick-add activity. */
class WidgetProviderInstrumentedTest {
    private val context: Context = ApplicationProvider.getApplicationContext()

    @Test
    fun widgetProviderIsRegisteredWithoutPeriodicUpdates() {
        val component = ComponentName(context, TaskWidgetReceiver::class.java)
        val info = AppWidgetManager.getInstance(context).installedProviders.firstOrNull { it.provider == component }
        assertNotNull("Task widget provider is not registered", info)
        // Refreshes come from WorkManager, never from the provider's own timer.
        assertEquals(0, info!!.updatePeriodMillis)
        assertTrue(info.minResizeWidth > 0)
    }

    @Test
    fun timeChangeReceiverListensForClockAndLocaleChanges() {
        val pm = context.packageManager
        val receivers = pm.queryBroadcastReceivers(Intent(Intent.ACTION_TIMEZONE_CHANGED).setPackage(context.packageName), 0)
        assertTrue(receivers.any { it.activityInfo.name == TimeChangeReceiver::class.java.name })
    }

    @Test
    fun quickAddActivityIsResolvableInsideTheApp() {
        val resolved = context.packageManager.resolveActivity(QuickAddActivity.intent(context), PackageManager.MATCH_DEFAULT_ONLY)
        assertNotNull(resolved)
    }

    @Test
    fun todayDeepLinkResolvesToMainActivity() {
        val resolved = context.packageManager.resolveActivity(
            com.tududi.tududi.widget.TaskWidget.openAppIntent(context),
            PackageManager.MATCH_DEFAULT_ONLY,
        )
        assertEquals(MainActivity::class.java.name, resolved!!.activityInfo.name)
    }
}
