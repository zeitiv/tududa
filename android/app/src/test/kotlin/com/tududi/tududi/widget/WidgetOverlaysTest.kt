package com.tududi.tududi.widget

import com.tududi.core.data.TaskStatus
import com.tududi.core.data.TodayBoard
import com.tududi.core.data.TodoTask
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime

class WidgetOverlaysTest {
    private val today = LocalDate.of(2026, 10, 18)
    private val a = TodoTask("a", "A", TaskStatus.NOT_STARTED, today, null, 0)
    private val b = TodoTask("b", "B", TaskStatus.NOT_STARTED, today.minusDays(1), null, 0)
    private val board = TodayBoard(open = listOf(a, b), overdue = listOf(b), done = emptyList())

    @Test
    fun `done overlay moves the task to the done list`() {
        val shown = WidgetOverlays.apply(board, mapOf("b" to Overlay(2, 0)), today)!!
        assertEquals(listOf("a"), shown.open.map { it.uid })
        assertEquals(listOf("b"), shown.done.map { it.uid })
        assertTrue(shown.overdue.isEmpty())
    }

    @Test
    fun `reopen overlay moves a done task back`() {
        val doneBoard = TodayBoard(open = listOf(a), overdue = emptyList(), done = listOf(b.copy(status = TaskStatus.DONE)))
        val shown = WidgetOverlays.apply(doneBoard, mapOf("b" to Overlay(0, 0)), today)!!
        assertEquals(listOf("a", "b"), shown.open.map { it.uid })
        assertEquals(listOf("b"), shown.overdue.map { it.uid })
    }

    @Test
    fun `prune drops confirmed and expired overlays`() {
        var now = 0L
        val overlays = WidgetOverlays { now }
        overlays.set("a", 2)
        overlays.set("b", 2)
        // The server agrees with "a" only.
        overlays.prune(TodayBoard(open = listOf(b), overdue = emptyList(), done = listOf(a.copy(status = TaskStatus.DONE))))
        assertEquals(setOf("b"), overlays.state.value.keys)
        now = WidgetOverlays.TTL_MILLIS + 1
        overlays.prune(board)
        assertTrue(overlays.state.value.isEmpty())
    }

    @Test
    fun `midnight delay rolls over to the next local day`() {
        val zone = ZoneId.of("Europe/Berlin")
        val evening = ZonedDateTime.of(2026, 10, 18, 23, 0, 0, 0, zone)
        assertEquals(3600L + 5, WidgetWork.delayUntilNextMidnight(evening).seconds)
        val justAfter = ZonedDateTime.of(2026, 10, 19, 0, 0, 1, 0, zone)
        assertEquals(24 * 3600L - 1 + 5, WidgetWork.delayUntilNextMidnight(justAfter).seconds)
        // DST ends on 2026-10-25 in Europe/Berlin: that day has 25 hours.
        val dstDay = ZonedDateTime.of(2026, 10, 25, 0, 0, 0, 0, zone)
        assertEquals(25 * 3600L + 5, WidgetWork.delayUntilNextMidnight(dstDay).seconds)
    }
}
