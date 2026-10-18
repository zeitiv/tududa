package com.tududi.tududi.widget

import com.tududi.core.data.TaskPage
import com.tududi.core.data.TaskStatus
import com.tududi.core.data.TodayBoard
import com.tududi.core.data.TodoTask
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

@OptIn(ExperimentalCoroutinesApi::class)
class CompletionFeedbackTest {
    private val today = LocalDate.of(2026, 10, 18)
    private val a = TodoTask("a", "A", TaskStatus.NOT_STARTED, today, null, 0)
    private val b = TodoTask("b", "B", TaskStatus.NOT_STARTED, today.minusDays(2), null, 0)
    private val c = TodoTask("c", "C", TaskStatus.NOT_STARTED, today, null, 0)
    private val board = TodayBoard(open = listOf(a, b, c), overdue = listOf(b), done = emptyList())

    private fun TestScope.feedback() = CompletionFeedback(
        checkMillis = 450, strikeMillis = 650, collapseMillis = 300, undoMillis = 5_000, scope = backgroundScope,
    )

    @Test
    fun `play progresses check then strike then collapse then clears`() = runTest {
        val feedback = feedback()
        launch { feedback.play("b", board) }
        runCurrent()
        val started = feedback.state.value.getValue("b")
        assertEquals(CompletionPhase.CHECK, started.phase)
        assertEquals(TaskStatus.DONE, started.task.status)
        assertEquals(mapOf(TaskPage.TODAY to 1, TaskPage.OVERDUE to 0), started.positions)

        advanceTimeBy(451)
        assertEquals(CompletionPhase.STRIKE, feedback.state.value.getValue("b").phase)

        advanceTimeBy(650)
        assertEquals(CompletionPhase.COLLAPSE, feedback.state.value.getValue("b").phase)

        advanceTimeBy(300)
        assertTrue(feedback.state.value.isEmpty())
    }

    @Test
    fun `undo is offered after the sequence and expires`() = runTest {
        val feedback = feedback()
        launch { feedback.play("b", board) }
        runCurrent()
        assertNull(feedback.undo.value)

        advanceTimeBy(450 + 650 + 300 + 1)
        assertEquals("b", feedback.undo.value?.uid)
        assertEquals("B", feedback.undo.value?.name)

        advanceTimeBy(5_001)
        assertNull(feedback.undo.value)
    }

    @Test
    fun `cancel removes feedback immediately and a stale play does not resurrect it`() = runTest {
        val feedback = feedback()
        launch { feedback.play("a", board) }
        runCurrent()
        feedback.cancel("a")
        advanceTimeBy(451)
        assertNull(feedback.state.value["a"])
    }

    @Test
    fun `a cancelled play offers no undo and dismissUndo clears an offer`() = runTest {
        val feedback = feedback()
        val job = launch { feedback.play("a", board) }
        runCurrent()
        job.cancel()
        runCurrent()
        assertNull(feedback.undo.value)

        launch { feedback.play("c", board) }
        advanceTimeBy(450 + 650 + 300 + 1)
        assertNotNull(feedback.undo.value)
        feedback.dismissUndo()
        assertNull(feedback.undo.value)
    }

    @Test
    fun `replaying a task is not cleared by the earlier run`() = runTest {
        val feedback = feedback()
        val first = launch { feedback.play("a", board) }
        runCurrent()
        advanceTimeBy(300)
        launch { feedback.play("a", board) }
        runCurrent()
        first.cancel()
        runCurrent()
        assertEquals(CompletionPhase.CHECK, feedback.state.value.getValue("a").phase)
    }

    @Test
    fun `unknown task plays nothing`() = runTest {
        val feedback = CompletionFeedback(scope = backgroundScope)
        feedback.play("missing", board)
        feedback.play("a", null)
        assertTrue(feedback.state.value.isEmpty())
        assertNull(feedback.undo.value)
    }

    @Test
    fun `rowsFor reinserts completed tasks at their previous position`() {
        val doneB = b.copy(status = TaskStatus.DONE)
        val completions = mapOf(
            "b" to Completion(doneB, mapOf(TaskPage.TODAY to 1, TaskPage.OVERDUE to 0), CompletionPhase.CHECK, 1),
        )
        val todayRows = rowsFor(listOf(a, c), TaskPage.TODAY, completions)
        assertEquals(listOf("a", "b", "c"), todayRows.map { it.task.uid })
        assertEquals(listOf(null, CompletionPhase.CHECK, null), todayRows.map { it.phase })

        assertEquals(listOf("b"), rowsFor(emptyList(), TaskPage.OVERDUE, completions).map { it.task.uid })
        // The done page already contains the task; it gets the phase without duplication.
        val doneRows = rowsFor(listOf(doneB), TaskPage.DONE, completions)
        assertEquals(listOf(TaskRowModel(doneB, CompletionPhase.CHECK)), doneRows)
    }

    @Test
    fun `rowsFor keeps order for several completions and clamps positions`() {
        val completions = mapOf(
            "c" to Completion(c.copy(status = TaskStatus.DONE), mapOf(TaskPage.TODAY to 2), CompletionPhase.STRIKE, 2),
            "a" to Completion(a.copy(status = TaskStatus.DONE), mapOf(TaskPage.TODAY to 0), CompletionPhase.CHECK, 3),
        )
        assertEquals(listOf("a", "b", "c"), rowsFor(listOf(b), TaskPage.TODAY, completions).map { it.task.uid })
        assertEquals(listOf("a", "c"), rowsFor(emptyList(), TaskPage.TODAY, completions).map { it.task.uid })
    }

    @Test
    fun `rowsFor ignores phase for a task reverted to open`() {
        val completions = mapOf("a" to Completion(a.copy(status = TaskStatus.DONE), mapOf(TaskPage.TODAY to 0), CompletionPhase.CHECK, 1))
        assertEquals(listOf(TaskRowModel(a)), rowsFor(listOf(a), TaskPage.TODAY, completions))
    }
}
