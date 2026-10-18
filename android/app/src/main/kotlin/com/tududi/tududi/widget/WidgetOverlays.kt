package com.tududi.tududi.widget

import com.tududi.core.data.TaskStatus
import com.tududi.core.data.TodayBoard
import com.tududi.core.data.TodoTask
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import java.time.LocalDate

/** A status change made in the Flutter app that the server does not know about yet. */
data class Overlay(val status: Int, val atMillis: Long)

/**
 * Locally made, not yet synced status changes (`tududa/widget` `overlay`), shown on the widget
 * only. An entry disappears once a server board agrees with it, or after [TTL_MILLIS].
 */
class WidgetOverlays(private val clock: () -> Long = { System.currentTimeMillis() }) {
    private val _state = MutableStateFlow<Map<String, Overlay>>(emptyMap())
    val state: StateFlow<Map<String, Overlay>> = _state.asStateFlow()

    fun set(uid: String, status: Int) {
        _state.update { it + (uid to Overlay(status, clock())) }
    }

    fun clear() {
        _state.value = emptyMap()
    }

    /** Drops entries the [board] already reflects, and expired ones. */
    fun prune(board: TodayBoard?) {
        val now = clock()
        val known = board?.let { b -> (b.open + b.done).associateBy { it.uid } }.orEmpty()
        _state.update { m ->
            m.filter { (uid, o) -> now - o.atMillis < TTL_MILLIS && known[uid]?.status?.code != o.status }
        }
    }

    companion object {
        const val TTL_MILLIS = 10 * 60 * 1000L

        /** [board] as the user expects it after the overlay changes. */
        fun apply(board: TodayBoard?, overlays: Map<String, Overlay>, today: LocalDate): TodayBoard? {
            if (board == null || overlays.isEmpty()) return board
            var open = board.open
            var done = board.done
            for ((uid, overlay) in overlays) {
                val task = (open + done).firstOrNull { it.uid == uid } ?: continue
                if (task.status.code == overlay.status) continue
                val updated: TodoTask = task.copy(status = TaskStatus.fromCode(overlay.status))
                open = open.filterNot { it.uid == uid }
                done = done.filterNot { it.uid == uid }
                if (updated.isDone) done = done + updated else if (!updated.isClosed) open = open + updated
            }
            return TodayBoard(open = open, overdue = open.filter { it.isOverdue(today) }, done = done)
        }
    }
}
