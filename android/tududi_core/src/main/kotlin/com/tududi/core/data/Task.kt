package com.tududi.core.data

import java.time.LocalDate

/** Mirrors Tududi's numeric task status codes (see the web client's status enum). */
enum class TaskStatus(val code: Int, val apiName: String) {
    NOT_STARTED(0, "not_started"),
    IN_PROGRESS(1, "in_progress"),
    DONE(2, "done"),
    ARCHIVED(3, "archived"),
    WAITING(4, "waiting"),
    CANCELLED(5, "cancelled"),
    PLANNED(6, "planned");

    companion object {
        fun fromCode(code: Int): TaskStatus = entries.firstOrNull { it.code == code } ?: NOT_STARTED
        fun fromName(name: String): TaskStatus =
            entries.firstOrNull { it.apiName.equals(name, ignoreCase = true) } ?: NOT_STARTED
    }
}

data class TodoTask(
    val uid: String,
    val name: String,
    val status: TaskStatus,
    val dueDate: LocalDate?,
    val projectName: String?,
    val priority: Int,
) {
    val isDone: Boolean get() = status == TaskStatus.DONE
    val isClosed: Boolean get() = status == TaskStatus.ARCHIVED || status == TaskStatus.CANCELLED

    fun isOverdue(today: LocalDate): Boolean = !isDone && dueDate != null && dueDate.isBefore(today)
}

enum class TaskPage { TODAY, OVERDUE, DONE }

/** The Today view split into the pages shown in the widget pager. */
data class TodayBoard(
    val open: List<TodoTask>,
    val overdue: List<TodoTask>,
    val done: List<TodoTask>,
) {
    fun tasksFor(page: TaskPage): List<TodoTask> = when (page) {
        TaskPage.TODAY -> open
        TaskPage.OVERDUE -> overdue
        TaskPage.DONE -> done
    }

    companion object {
        val EMPTY = TodayBoard(emptyList(), emptyList(), emptyList())
    }
}
