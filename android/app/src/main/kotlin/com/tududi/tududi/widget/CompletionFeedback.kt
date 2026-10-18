package com.tududi.tududi.widget

import com.tududi.core.data.TaskPage
import com.tududi.core.data.TaskStatus
import com.tududi.core.data.TodayBoard
import com.tududi.core.data.TodoTask
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.util.concurrent.atomic.AtomicLong

/**
 * Frames a task passes through after it is checked off in the widget. The row leaves the list
 * after [COLLAPSE]; Glance cannot animate, so each phase is one crisp re-render.
 */
enum class CompletionPhase {
    /** Checkbox fills, row is highlighted, "Done!" badge. */
    CHECK,

    /** Title is struck through and muted. */
    STRIKE,

    /** Row shrinks to a thin struck-through line. */
    COLLAPSE,
}

/** A task just completed from the widget, kept at its previous list positions until it is gone. */
data class Completion(
    val task: TodoTask,
    val positions: Map<TaskPage, Int>,
    val phase: CompletionPhase,
    val token: Long,
)

/** Inline "Completed X - Undo" strip shown for a few seconds after a completion. */
data class UndoOffer(val uid: String, val name: String, val token: Long)

data class TaskRowModel(val task: TodoTask, val phase: CompletionPhase? = null)

class CompletionFeedback(
    private val checkMillis: Long = 450,
    private val strikeMillis: Long = 650,
    private val collapseMillis: Long = 300,
    private val undoMillis: Long = 5_000,
    // Outlives the action callback that started the sequence, so the undo window can run its course.
    private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Default),
) {
    private val _state = MutableStateFlow<Map<String, Completion>>(emptyMap())
    val state: StateFlow<Map<String, Completion>> = _state.asStateFlow()

    private val _undo = MutableStateFlow<UndoOffer?>(null)
    val undo: StateFlow<UndoOffer?> = _undo.asStateFlow()

    private val tokens = AtomicLong()

    /**
     * Plays the check -> strike -> collapse frames for [uid] using its positions in [board];
     * returns once the row is gone and then offers undo. Cancelling plays no undo.
     */
    suspend fun play(uid: String, board: TodayBoard?) {
        if (board == null) return
        val task = (board.open + board.done).firstOrNull { it.uid == uid } ?: return
        val positions = TaskPage.entries
            .associateWith { page -> board.tasksFor(page).indexOfFirst { it.uid == uid } }
            .filterValues { it >= 0 }
        val token = tokens.incrementAndGet()
        val completion = Completion(task.copy(status = TaskStatus.DONE), positions, CompletionPhase.CHECK, token)
        _state.update { it + (uid to completion) }
        try {
            delay(checkMillis)
            setPhase(uid, token, completion, CompletionPhase.STRIKE)
            delay(strikeMillis)
            setPhase(uid, token, completion, CompletionPhase.COLLAPSE)
            delay(collapseMillis)
        } finally {
            // A newer play or a cancel may own this entry by now; only remove our own.
            _state.update { m -> if (m[uid]?.token == token) m - uid else m }
        }
        offerUndo(UndoOffer(uid, task.name, token))
    }

    private fun setPhase(uid: String, token: Long, completion: Completion, phase: CompletionPhase) {
        _state.update { m -> if (m[uid]?.token == token) m + (uid to completion.copy(phase = phase)) else m }
    }

    private fun offerUndo(offer: UndoOffer) {
        _undo.value = offer
        scope.launch {
            delay(undoMillis)
            _undo.update { if (it?.token == offer.token) null else it }
        }
    }

    fun dismissUndo() {
        _undo.value = null
    }

    fun cancel(uid: String) {
        _state.update { it - uid }
        _undo.update { if (it?.uid == uid) null else it }
    }
}

/** Merges in-flight completions into [tasks] so a checked-off row stays put while it plays. */
fun rowsFor(tasks: List<TodoTask>, page: TaskPage, completions: Map<String, Completion>): List<TaskRowModel> {
    val rows = tasks.mapTo(mutableListOf()) { task ->
        TaskRowModel(task, completions[task.uid]?.phase?.takeIf { task.isDone })
    }
    completions.values
        .filter { c -> c.positions[page] != null && rows.none { it.task.uid == c.task.uid } }
        .sortedBy { it.positions.getValue(page) }
        .forEach { c -> rows.add(c.positions.getValue(page).coerceAtMost(rows.size), TaskRowModel(c.task, c.phase)) }
    return rows
}
