package com.tududi.tududi.widget

import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.glance.ImageProvider
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.testing.unit.GlanceAppWidgetUnitTest
import androidx.glance.appwidget.testing.unit.runGlanceAppWidgetUnitTest
import androidx.glance.testing.unit.hasContentDescription
import androidx.glance.testing.unit.hasText
import com.tududi.core.data.BoardState
import com.tududi.core.data.ConnectionStatus
import com.tududi.core.data.TaskPage
import com.tududi.core.data.TaskStatus
import com.tududi.core.data.TodayBoard
import com.tududi.core.data.TodoTask
import com.tududi.tududi.R
import org.junit.Test
import java.time.LocalDate

class TaskWidgetContentTest {
    private val today = LocalDate.of(2026, 10, 18)
    private val strings = testStrings
    private val overdue = TodoTask("b2", "Pay invoice", TaskStatus.NOT_STARTED, LocalDate.of(2026, 10, 14), "Home", 0)
    private val dueToday = TodoTask("a1", "Write report", TaskStatus.NOT_STARTED, today, null, 0)
    private val board = TodayBoard(open = listOf(overdue, dueToday), overdue = listOf(overdue), done = emptyList())
    private val dummy = actionRunCallback<RefreshAction>()

    /** The board right after the optimistic update for completing [dueToday]. */
    private val afterCompleting = TodayBoard(
        open = listOf(overdue),
        overdue = listOf(overdue),
        done = listOf(dueToday.copy(status = TaskStatus.DONE)),
    )

    private fun completion(phase: CompletionPhase) = mapOf(
        dueToday.uid to Completion(dueToday.copy(status = TaskStatus.DONE), mapOf(TaskPage.TODAY to 1), phase, token = 1),
    )

    // Medium layout (4x3 cells) unless a test asks for another size.
    private fun render(
        state: BoardState,
        page: TaskPage = TaskPage.TODAY,
        completions: Map<String, Completion> = emptyMap(),
        undo: UndoOffer? = null,
        size: DpSize = DpSize(300.dp, 160.dp),
        check: GlanceAppWidgetUnitTest.() -> Unit,
    ) = runGlanceAppWidgetUnitTest {
        setAppWidgetSize(size)
        provideComposable {
            TaskWidgetContent(state, page, strings, today, dummy, dummy, completions, undo, ring = { ImageProvider(R.drawable.ic_ring_track) })
        }
        check()
    }

    @Test
    fun `renders today tasks with checkboxes, dates, progress and add action`() = render(BoardState(board, ConnectionStatus.OK)) {
        onNode(hasText("Today")).assertExists()
        onNode(hasText("Write report")).assertExists()
        onNode(hasText("Pay invoice")).assertExists()
        onNode(hasText("Home")).assertExists()
        onNode(hasText("Due today")).assertExists()
        onNode(hasText("0 of 2 done")).assertExists()
        onNode(hasContentDescription("Mark done: Pay invoice")).assertExists()
        onNode(hasContentDescription("New task")).assertExists()
        onNode(hasContentDescription("Switch list: Today")).assertExists()
        onNode(hasContentDescription("Refresh")).assertExists()
        onNode(hasText("Done!")).assertDoesNotExist()
    }

    @Test
    fun `checkbox completes an open task`() = render(BoardState(board, ConnectionStatus.OK)) {
        onNode(hasContentDescription("Mark done: Write report")).assertExists()
    }

    @Test
    fun `overdue page shows only overdue tasks`() = render(BoardState(board, ConnectionStatus.OK), TaskPage.OVERDUE) {
        onNode(hasText("Overdue")).assertExists()
        onNode(hasText("Pay invoice")).assertExists()
        onNode(hasText("Write report")).assertDoesNotExist()
    }

    @Test
    fun `empty page shows empty message`() = render(BoardState(board, ConnectionStatus.OK), TaskPage.DONE) {
        onNode(hasText("None done")).assertExists()
    }

    @Test
    fun `signed out state prompts to open the app`() = render(BoardState(status = ConnectionStatus.LOGGED_OUT), size = DpSize(300.dp, 220.dp)) {
        onNode(hasText("Not signed in")).assertExists()
        onNode(hasText("Sign in to see tasks")).assertExists()
        onNode(hasText("Open Tududa")).assertExists()
    }

    @Test
    fun `login failed state explains and offers open app`() = render(BoardState(status = ConnectionStatus.LOGIN_FAILED), size = DpSize(300.dp, 220.dp)) {
        onNode(hasText("Sign-in failed")).assertExists()
        onNode(hasText("Login was rejected")).assertExists()
        onNode(hasText("Open Tududa")).assertExists()
    }

    @Test
    fun `short widget keeps the open app button in the signed out state`() = render(BoardState(status = ConnectionStatus.LOGGED_OUT)) {
        onNode(hasText("Not signed in")).assertExists()
        onNode(hasText("Open Tududa")).assertExists()
    }

    @Test
    fun `offline keeps cached tasks with notice`() = render(BoardState(board, ConnectionStatus.OFFLINE)) {
        onNode(hasText("Offline")).assertExists()
        onNode(hasText("Write report")).assertExists()
    }

    @Test
    fun `offline without cache offers refresh`() = render(BoardState(status = ConnectionStatus.OFFLINE), size = DpSize(300.dp, 220.dp)) {
        onNode(hasText("Can't reach server")).assertExists()
        onNode(hasText("Check Wi-Fi")).assertExists()
        onNode(hasText("Refresh")).assertExists()
    }

    @Test
    fun `checked task stays in the open list as done with a badge`() =
        render(BoardState(afterCompleting, ConnectionStatus.OK), completions = completion(CompletionPhase.CHECK)) {
            onNode(hasText("Write report")).assertExists()
            onNode(hasText("Done!")).assertExists()
            // The badge replaces the due date while the check frame shows.
            onNode(hasText("Due today")).assertDoesNotExist()
            // Tapping again during the sequence undoes the completion.
            onNode(hasContentDescription("Mark not done: Write report")).assertExists()
        }

    @Test
    fun `struck task stays without badge or date`() =
        render(BoardState(afterCompleting, ConnectionStatus.OK), completions = completion(CompletionPhase.STRIKE)) {
            onNode(hasText("Write report")).assertExists()
            onNode(hasContentDescription("Mark not done: Write report")).assertExists()
            onNode(hasText("Done!")).assertDoesNotExist()
            onNode(hasText("Due today")).assertDoesNotExist()
        }

    @Test
    fun `collapsing task is a thin line without checkbox target`() =
        render(BoardState(afterCompleting, ConnectionStatus.OK), completions = completion(CompletionPhase.COLLAPSE)) {
            onNode(hasText("Write report")).assertExists()
            onNode(hasContentDescription("Mark not done: Write report")).assertDoesNotExist()
            onNode(hasText("Done!")).assertDoesNotExist()
        }

    @Test
    fun `completed task leaves the open list once feedback ends`() =
        render(BoardState(afterCompleting, ConnectionStatus.OK)) {
            onNode(hasText("Write report")).assertDoesNotExist()
            onNode(hasText("Pay invoice")).assertExists()
            onNode(hasText("1 of 2 done")).assertExists()
        }

    @Test
    fun `last completion keeps the list visible instead of the empty message`() {
        val emptied = TodayBoard(open = emptyList(), overdue = emptyList(), done = listOf(dueToday.copy(status = TaskStatus.DONE)))
        render(BoardState(emptied, ConnectionStatus.OK), completions = completion(CompletionPhase.CHECK)) {
            onNode(hasText("Write report")).assertExists()
            onNode(hasText("Nothing left")).assertDoesNotExist()
        }
        render(BoardState(emptied, ConnectionStatus.OK)) {
            onNode(hasText("Nothing left")).assertExists()
            onNode(hasText("All done")).assertExists()
        }
    }

    @Test
    fun `done page lists completed tasks as reopenable`() =
        render(BoardState(afterCompleting, ConnectionStatus.OK), TaskPage.DONE) {
            onNode(hasText("Write report")).assertExists()
            onNode(hasContentDescription("Mark not done: Write report")).assertExists()
        }

    @Test
    fun `large layout shows list tabs with counts`() =
        render(BoardState(board, ConnectionStatus.OK), size = DpSize(300.dp, 300.dp)) {
            onNode(hasContentDescription("Today 2")).assertExists()
            onNode(hasContentDescription("Overdue 1")).assertExists()
            onNode(hasContentDescription("Done 0")).assertExists()
            onNode(hasText("Write report")).assertExists()
        }

    @Test
    fun `compact layout shows ring, add button and summary only`() =
        render(BoardState(board, ConnectionStatus.OK), size = DpSize(110.dp, 110.dp)) {
            onNode(hasContentDescription("0 of 2 tasks done today")).assertExists()
            onNode(hasContentDescription("New task")).assertExists()
            onNode(hasText("Today")).assertExists()
            onNode(hasText("0 of 2 done")).assertExists()
            onNode(hasText("Write report")).assertDoesNotExist()
        }

    @Test
    fun `undo strip is offered right after a completion`() =
        render(BoardState(afterCompleting, ConnectionStatus.OK), undo = UndoOffer("a1", "Write report", 1), size = DpSize(300.dp, 220.dp)) {
            onNode(hasText("Completed Write report")).assertExists()
            onNode(hasText("Undo")).assertExists()
            onNode(hasText("Pay invoice")).assertExists()
        }

    @Test
    fun `undo strip replaces the list in short widgets`() =
        render(BoardState(afterCompleting, ConnectionStatus.OK), undo = UndoOffer("a1", "Write report", 1), size = DpSize(300.dp, 120.dp)) {
            onNode(hasText("Undo")).assertExists()
            onNode(hasText("Pay invoice")).assertDoesNotExist()
        }
}
