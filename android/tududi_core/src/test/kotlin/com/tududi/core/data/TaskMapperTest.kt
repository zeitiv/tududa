package com.tududi.core.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class TaskMapperTest {
    private val today = LocalDate.of(2026, 10, 18)

    private val body = """
        {
          "tasks": [
            {"id": 1, "uid": "a1", "name": "Write report", "status": 0, "due_date": "2026-10-18", "priority": 1,
             "Project": {"id": 3, "uid": "p3", "name": "Work"}},
            {"id": 2, "uid": "b2", "name": "Pay invoice", "status": "not_started", "due_date": "2026-10-14T00:00:00.000Z", "priority": "high"},
            {"id": 3, "uid": "c3", "name": "Already done", "status": 2, "due_date": "2026-10-18"},
            {"id": 4, "uid": "d4", "name": "Archived", "status": "archived"},
            {"id": 5, "uid": "e5", "name": "No date", "status": 1, "due_date": null}
          ],
          "tasks_overdue": [
            {"id": 2, "uid": "b2", "name": "Pay invoice", "status": 0, "due_date": "2026-10-14"}
          ],
          "tasks_completed_today": [
            {"id": 6, "uid": "f6", "name": "Morning run", "status": "done"}
          ],
          "metrics": {"total": 5}
        }
    """.trimIndent()

    @Test
    fun `maps open, overdue and done pages`() {
        val board = TaskMapper.parseBoard(body, today)

        assertEquals(listOf("b2", "a1", "e5"), board.open.map { it.uid })
        assertEquals(listOf("b2"), board.overdue.map { it.uid })
        assertEquals(setOf("c3", "f6"), board.done.map { it.uid }.toSet())
    }

    @Test
    fun `parses mixed status, priority, timestamps and project`() {
        val board = TaskMapper.parseBoard(body, today)
        val report = board.open.first { it.uid == "a1" }
        val invoice = board.open.first { it.uid == "b2" }

        assertEquals("Work", report.projectName)
        assertEquals(TaskStatus.NOT_STARTED, report.status)
        assertEquals(LocalDate.of(2026, 10, 14), invoice.dueDate)
        assertEquals(2, invoice.priority)
        assertTrue(invoice.isOverdue(today))
        assertFalse(report.isOverdue(today))
        assertEquals(TaskStatus.IN_PROGRESS, board.open.first { it.uid == "e5" }.status)
    }

    @Test
    fun `deduplicates tasks across helper lists`() {
        val board = TaskMapper.parseBoard(body, today)
        assertEquals(1, board.open.count { it.uid == "b2" })
    }

    @Test
    fun `excludes archived and cancelled tasks`() {
        val board = TaskMapper.parseBoard(body, today)
        assertTrue((board.open + board.done).none { it.uid == "d4" })
    }

    @Test
    fun `invalid dates and missing names are tolerated`() {
        assertNull(TaskMapper.parseDate("not-a-date"))
        assertNull(TaskMapper.parseDate(null))
        val board = TaskMapper.parseBoard("""{"tasks":[{"uid":"x"},{"uid":"y","name":"Ok","due_date":"bogus-value"}]}""", today)
        assertEquals(listOf("y"), board.open.map { it.uid })
        assertNull(board.open.single().dueDate)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `rejects responses without tasks array`() {
        TaskMapper.parseBoard("""{"error":"nope"}""", today)
    }

    @Test
    fun `due label uses today word and short dates`() {
        assertEquals("Heute", dueLabel(today, today, "Heute"))
        assertEquals("14 Oct", dueLabel(LocalDate.of(2026, 10, 14), today, "Today", java.util.Locale.ENGLISH))
        assertEquals("3 Jan 2027", dueLabel(LocalDate.of(2027, 1, 3), today, "Today", java.util.Locale.ENGLISH))
        assertNull(dueLabel(null, today, "Today"))
    }

    @Test
    fun `original_name is preferred over name when present`() {
        val board = TaskMapper.parseBoard(
            """{"tasks":[
              {"uid":"a","name":"Call mom","original_name":"Call mom tomorrow #family","status":0},
              {"uid":"b","name":"Plain","original_name":"  ","status":0},
              {"uid":"c","name":"Nulled","original_name":null,"status":0}
            ]}""",
            today,
        )
        assertEquals(
            mapOf("a" to "Call mom tomorrow #family", "b" to "Plain", "c" to "Nulled"),
            board.open.associate { it.uid to it.name },
        )
    }
}
