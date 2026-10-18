package com.tududi.tududi.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.state.updateAppWidgetState
import androidx.glance.appwidget.updateAll
import androidx.glance.currentState
import com.tududi.core.data.TaskPage
import com.tududi.tududi.QuickAddActivity
import com.tududi.tududi.QuickAddEngine
import com.tududi.tududi.tududa
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import java.time.LocalDate

/** Deep link the widget uses to open the app on the Today tab. */
const val TODAY_LINK = "tududa://today"

class TaskWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Responsive(WidgetSizes.all)

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val app = context.tududa
        val repo = app.core.repository
        // First frame comes from the encrypted cache, so the widget never starts blank.
        repo.restoreCache()
        val strings = WidgetStrings.from(context)
        val openApp = actionStartActivity(openAppIntent(context))
        val addTask = actionStartActivity(QuickAddActivity.intent(context))

        provideContent {
            val state by repo.state.collectAsState()
            val completed by completions.state.collectAsState()
            val undo by completions.undo.collectAsState()
            val overlays by app.overlays.state.collectAsState()
            val today = LocalDate.now()
            val pageIndex = currentState<Preferences>()[PAGE_KEY] ?: 0
            LaunchedEffect(Unit) { repo.refreshIfStale() }
            TaskWidgetContent(
                state = state.copy(board = WidgetOverlays.apply(state.board, overlays, today)),
                page = TaskPage.entries[pageIndex.mod(TaskPage.entries.size)],
                strings = strings,
                today = today,
                openApp = openApp,
                addTask = addTask,
                completions = completed,
                undo = undo,
            )
        }
    }

    companion object {
        val PAGE_KEY = intPreferencesKey("page")

        /** Process-wide so the toggle callback and the running widget session share it. */
        val completions = CompletionFeedback()

        fun openAppIntent(context: Context): Intent =
            Intent(Intent.ACTION_VIEW, Uri.parse(TODAY_LINK)).setPackage(context.packageName)
    }
}

class TaskWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = TaskWidget()

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        WidgetWork.schedule(context)
    }

    // Idempotent: also re-arms the workers after a reboot or an app update.
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        WidgetWork.schedule(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        WidgetWork.cancel(context)
    }
}

class ToggleTaskAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val uid = parameters[UID] ?: return
        val done = parameters[DONE] ?: true
        val repo = context.tududa.core.repository
        val feedback = TaskWidget.completions
        // The user is at the home screen and may reach for "+" next.
        QuickAddEngine.prewarm(context)
        repo.restoreCache()
        if (!done) {
            // Reopening (also from a playing row) is immediate.
            feedback.cancel(uid)
            repo.setDone(uid, false)
            return
        }
        Haptics.tick(context)
        val board = repo.state.value.board
        coroutineScope {
            // Undispatched so the first frame exists before the optimistic update removes the row.
            val playing = launch(start = CoroutineStart.UNDISPATCHED) { feedback.play(uid, board) }
            TaskWidget().update(context, glanceId)
            if (!repo.setDone(uid, true)) playing.cancel()
        }
    }

    companion object {
        val UID = ActionParameters.Key<String>("uid")
        val DONE = ActionParameters.Key<Boolean>("done")
    }
}

/** "Undo" in the strip shown right after a completion. */
class UndoAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val uid = parameters[UID] ?: return
        TaskWidget.completions.dismissUndo()
        TaskWidget().update(context, glanceId)
        context.tududa.core.repository.setDone(uid, false)
    }

    companion object {
        val UID = ActionParameters.Key<String>("uid")
    }
}

/** Switches the shown list: to [PAGE] when given, else by [DELTA] pages. */
class PageAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        updateAppWidgetState(context, glanceId) { prefs ->
            val current = prefs[TaskWidget.PAGE_KEY] ?: 0
            val next = parameters[PAGE] ?: (current + (parameters[DELTA] ?: 1))
            prefs[TaskWidget.PAGE_KEY] = next.mod(TaskPage.entries.size)
        }
        TaskWidget().update(context, glanceId)
    }

    companion object {
        val DELTA = ActionParameters.Key<Int>("delta")
        val PAGE = ActionParameters.Key<Int>("page")
    }
}

class RefreshAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        QuickAddEngine.prewarm(context)
        context.tududa.core.repository.refresh()
        TaskWidget().updateAll(context)
    }
}
