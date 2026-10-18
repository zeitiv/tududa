package com.tududi.tududi.widget

import android.content.Context
import com.tududi.core.data.TaskPage
import com.tududi.tududi.R

/** Pre-resolved strings so the widget content can be rendered (and tested) without resources. */
data class WidgetStrings(
    val pageToday: String,
    val pageOverdue: String,
    val pageDone: String,
    val emptyToday: String,
    val emptyOverdue: String,
    val emptyDone: String,
    val signedOut: String,
    val signedOutHint: String,
    val loginFailed: String,
    val loginFailedHint: String,
    val openApp: String,
    val offline: String,
    val offlineEmpty: String,
    val offlineEmptyHint: String,
    val error: String,
    val errorHint: String,
    val loading: String,
    val addTask: String,
    val refresh: String,
    val switchList: String,
    val markDone: String,
    val markOpen: String,
    val undo: String,
    val todayLabel: String,
    val completed: String,
    /** Format with (done, total). */
    val progressFormat: String,
    val progressAll: String,
    val progressNone: String,
    /** Accessibility text, format with (done, total). */
    val progressDescriptionFormat: String,
    /** Format with (task name). */
    val completedTaskFormat: String,
) {
    fun title(page: TaskPage) = when (page) {
        TaskPage.TODAY -> pageToday
        TaskPage.OVERDUE -> pageOverdue
        TaskPage.DONE -> pageDone
    }

    fun empty(page: TaskPage) = when (page) {
        TaskPage.TODAY -> emptyToday
        TaskPage.OVERDUE -> emptyOverdue
        TaskPage.DONE -> emptyDone
    }

    fun progress(done: Int, total: Int): String = when {
        total == 0 -> progressNone
        done >= total -> progressAll
        else -> progressFormat.format(done, total)
    }

    fun progressDescription(done: Int, total: Int): String = progressDescriptionFormat.format(done, total)

    fun completedTask(name: String): String = completedTaskFormat.format(name)

    companion object {
        fun from(c: Context) = WidgetStrings(
            pageToday = c.getString(R.string.page_today),
            pageOverdue = c.getString(R.string.page_overdue),
            pageDone = c.getString(R.string.page_done),
            emptyToday = c.getString(R.string.empty_today),
            emptyOverdue = c.getString(R.string.empty_overdue),
            emptyDone = c.getString(R.string.empty_done),
            signedOut = c.getString(R.string.state_signed_out),
            signedOutHint = c.getString(R.string.state_signed_out_hint),
            loginFailed = c.getString(R.string.state_login_failed),
            loginFailedHint = c.getString(R.string.state_login_failed_hint),
            openApp = c.getString(R.string.action_open_app),
            offline = c.getString(R.string.state_offline),
            offlineEmpty = c.getString(R.string.state_offline_empty),
            offlineEmptyHint = c.getString(R.string.state_offline_empty_hint),
            error = c.getString(R.string.state_error),
            errorHint = c.getString(R.string.state_error_hint),
            loading = c.getString(R.string.state_loading),
            addTask = c.getString(R.string.action_add_task),
            refresh = c.getString(R.string.action_refresh),
            switchList = c.getString(R.string.action_switch_list),
            markDone = c.getString(R.string.action_mark_done),
            markOpen = c.getString(R.string.action_mark_open),
            undo = c.getString(R.string.action_undo),
            todayLabel = c.getString(R.string.due_today),
            completed = c.getString(R.string.widget_completed),
            progressFormat = c.getString(R.string.widget_progress),
            progressAll = c.getString(R.string.widget_progress_all),
            progressNone = c.getString(R.string.widget_progress_none),
            progressDescriptionFormat = c.getString(R.string.widget_progress_description),
            completedTaskFormat = c.getString(R.string.widget_completed_task),
        )
    }
}
