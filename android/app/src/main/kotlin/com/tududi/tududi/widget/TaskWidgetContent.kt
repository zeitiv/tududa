package com.tududi.tududi.widget

import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.ColorFilter
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalSize
import androidx.glance.action.Action
import androidx.glance.action.actionParametersOf
import androidx.glance.action.clickable
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.lazy.LazyColumn
import androidx.glance.appwidget.lazy.items
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxHeight
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.semantics.contentDescription
import androidx.glance.semantics.semantics
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextDecoration
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.tududi.core.data.BoardState
import com.tududi.core.data.ConnectionStatus
import com.tududi.core.data.TaskPage
import com.tududi.core.data.TodoTask
import com.tududi.core.data.dueLabel
import com.tududi.tududi.R
import java.time.LocalDate

/**
 * Stateless widget UI. [openApp] and [addTask] are passed in so the composable can be rendered
 * in JVM unit tests without an Android context; [ring] supplies the progress-arc bitmap for the
 * same reason. The layout follows the widget's size (compact / medium / large, see [WidgetSizes]).
 */
@Composable
fun TaskWidgetContent(
    state: BoardState,
    page: TaskPage,
    strings: WidgetStrings,
    today: LocalDate,
    openApp: Action,
    addTask: Action,
    completions: Map<String, Completion> = emptyMap(),
    undo: UndoOffer? = null,
    ring: (Float) -> ImageProvider = ProgressRing::imageFor,
) = WidgetTheme {
    val size = LocalSize.current
    val layout = WidgetSizes.layoutFor(size)
    val progress = Progress.of(state)
    val root = GlanceModifier
        .fillMaxSize()
        .background(ImageProvider(R.drawable.widget_background), colorFilter = ColorFilter.tint(WidgetColors.surface))
    if (layout == WidgetSizes.Layout.COMPACT) {
        Column(modifier = root.padding(horizontal = 8.dp, vertical = 6.dp)) {
            Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                ProgressRingView(progress, strings, WidgetDimens.ringCompact, ring)
                Spacer(GlanceModifier.defaultWeight())
                AddButton(strings, addTask)
            }
            CompactSummary(state, page, progress, strings, openApp)
        }
        return@WidgetTheme
    }
    val dense = size.height < 150.dp
    val vertical = if (dense) 4.dp else 8.dp
    Column(modifier = root.padding(start = 14.dp, end = 8.dp, top = vertical, bottom = vertical)) {
        Header(state, page, progress, strings, addTask, ring, showDots = layout == WidgetSizes.Layout.MEDIUM, dense = dense)
        if (layout == WidgetSizes.Layout.LARGE) Tabs(state, page, strings)
        StatusLine(state, strings)
        Box(modifier = GlanceModifier.fillMaxWidth().defaultWeight()) {
            // Short widgets have no room for both: the undo strip takes the list's place for its few seconds.
            if (undo != null && dense) UndoStrip(undo, strings) else Body(state, page, strings, today, openApp, completions, dense)
        }
        if (undo != null && !dense) UndoStrip(undo, strings)
    }
}

/** Daily progress: tasks done today out of everything planned for today. */
internal data class Progress(val done: Int, val total: Int, val open: Int) {
    val fraction: Float get() = if (total == 0) 0f else done.toFloat() / total

    companion object {
        fun of(state: BoardState): Progress {
            val board = state.board ?: return Progress(0, 0, 0)
            return Progress(done = board.done.size, total = board.open.size + board.done.size, open = board.open.size)
        }
    }
}

@Composable
private fun Header(
    state: BoardState,
    page: TaskPage,
    progress: Progress,
    strings: WidgetStrings,
    addTask: Action,
    ring: (Float) -> ImageProvider,
    showDots: Boolean,
    dense: Boolean,
) {
    val cycle = actionRunCallback<PageAction>(actionParametersOf(PageAction.DELTA to 1))
    Row(
        modifier = GlanceModifier.fillMaxWidth().height(if (dense) 48.dp else 56.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        ProgressRingView(progress, strings, if (dense) WidgetDimens.ringDense else WidgetDimens.ringLarge, ring)
        Spacer(GlanceModifier.width(10.dp))
        Column(
            modifier = GlanceModifier
                .defaultWeight()
                .fillMaxHeight()
                .let { if (showDots) it.clickable(cycle) else it }
                .semantics { contentDescription = if (showDots) "${strings.switchList}: ${strings.title(page)}" else strings.title(page) },
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = strings.title(page),
                    style = TextStyle(color = WidgetColors.onSurface, fontSize = 17.sp, fontWeight = FontWeight.Bold),
                    maxLines = 1,
                )
                if (showDots) {
                    Spacer(GlanceModifier.width(8.dp))
                    PageDots(page)
                }
            }
            Text(
                text = strings.progress(progress.done, progress.total),
                style = TextStyle(color = WidgetColors.onSurfaceVariant, fontSize = 12.sp),
                maxLines = 1,
            )
        }
        IconButton(R.drawable.ic_refresh, strings.refresh, actionRunCallback<RefreshAction>())
        AddButton(strings, addTask)
    }
}

/** Ring with the number of open tasks in its middle (a check mark once everything is done). */
@Composable
private fun ProgressRingView(progress: Progress, strings: WidgetStrings, size: Dp, ring: (Float) -> ImageProvider) {
    val label = if (progress.total > 0 && progress.open == 0) "✓" else progress.open.toString()
    Box(
        modifier = GlanceModifier
            .size(size)
            .semantics { contentDescription = strings.progressDescription(progress.done, progress.total) },
        contentAlignment = Alignment.Center,
    ) {
        Image(
            ImageProvider(R.drawable.ic_ring_track),
            contentDescription = null,
            modifier = GlanceModifier.fillMaxSize(),
            colorFilter = ColorFilter.tint(WidgetColors.surfaceVariant),
        )
        if (progress.fraction > 0f) {
            Image(
                ring(progress.fraction),
                contentDescription = null,
                modifier = GlanceModifier.fillMaxSize(),
                colorFilter = ColorFilter.tint(WidgetColors.primary),
            )
        }
        Text(
            label,
            style = TextStyle(color = WidgetColors.onSurface, fontSize = 15.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center),
        )
    }
}

@Composable
private fun CompactSummary(state: BoardState, page: TaskPage, progress: Progress, strings: WidgetStrings, openApp: Action) {
    val (title, subtitle) = when {
        state.isSignedOut -> (if (state.status == ConnectionStatus.LOGIN_FAILED) strings.loginFailed else strings.signedOut) to strings.openApp
        state.board == null && state.status == ConnectionStatus.OFFLINE -> strings.offlineEmpty to strings.refresh
        state.board == null && state.status == ConnectionStatus.ERROR -> strings.error to strings.openApp
        state.board == null -> strings.title(TaskPage.TODAY) to strings.loading
        else -> strings.title(page) to strings.progress(progress.done, progress.total)
    }
    Column(modifier = GlanceModifier.fillMaxWidth().padding(top = 2.dp).clickable(openApp)) {
        Text(title, style = TextStyle(color = WidgetColors.onSurface, fontSize = 14.sp, fontWeight = FontWeight.Bold), maxLines = 1)
        Text(subtitle, style = TextStyle(color = WidgetColors.onSurfaceVariant, fontSize = 12.sp), maxLines = 1)
    }
}

@Composable
private fun Tabs(state: BoardState, current: TaskPage, strings: WidgetStrings) {
    Row(modifier = GlanceModifier.fillMaxWidth().height(WidgetDimens.target), verticalAlignment = Alignment.CenterVertically) {
        TaskPage.entries.forEach { p ->
            val count = state.board?.tasksFor(p)?.size
            val selected = p == current
            val label = strings.title(p) + (count?.let { " $it" } ?: "")
            Box(
                modifier = GlanceModifier
                    .height(WidgetDimens.target)
                    .clickable(actionRunCallback<PageAction>(actionParametersOf(PageAction.PAGE to p.ordinal)))
                    .semantics { contentDescription = label },
                contentAlignment = Alignment.Center,
            ) {
                Box(
                    modifier = (
                        if (selected) {
                            GlanceModifier.background(ImageProvider(R.drawable.widget_chip), colorFilter = ColorFilter.tint(WidgetColors.primaryContainer))
                        } else {
                            GlanceModifier
                        }
                        ).height(WidgetDimens.chipVisual).padding(horizontal = 12.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        label,
                        style = TextStyle(
                            color = if (selected) WidgetColors.onPrimaryContainer else WidgetColors.onSurfaceVariant,
                            fontSize = 13.sp,
                            fontWeight = if (selected) FontWeight.Bold else FontWeight.Medium,
                        ),
                        maxLines = 1,
                    )
                }
            }
        }
    }
}

@Composable
private fun PageDots(page: TaskPage) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        TaskPage.entries.forEach { p ->
            Box(
                modifier = GlanceModifier
                    .size(if (p == page) 12.dp else 4.dp, 4.dp)
                    .cornerRadius(2.dp)
                    .background(if (p == page) WidgetColors.primary else WidgetColors.surfaceVariant),
            ) {}
            Spacer(GlanceModifier.width(3.dp))
        }
    }
}

@Composable
private fun IconButton(icon: Int, label: String, action: Action) {
    Box(
        modifier = GlanceModifier.size(WidgetDimens.target).clickable(action).semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) {
        TintedIcon(icon, WidgetColors.onSurfaceVariant, WidgetDimens.icon)
    }
}

/** Filled round "+" inside a full-size 48 dp target. */
@Composable
private fun AddButton(strings: WidgetStrings, addTask: Action) {
    Box(
        modifier = GlanceModifier
            .size(WidgetDimens.target)
            .clickable(addTask)
            .semantics { contentDescription = strings.addTask },
        contentAlignment = Alignment.Center,
    ) {
        // The clickable parent carries the label; null here avoids double announcements.
        Box(
            modifier = GlanceModifier
                .size(WidgetDimens.fabVisual)
                .background(ImageProvider(R.drawable.widget_fab), colorFilter = ColorFilter.tint(WidgetColors.primary)),
            contentAlignment = Alignment.Center,
        ) {
            TintedIcon(R.drawable.ic_add, WidgetColors.onPrimary, 22.dp)
        }
    }
}

@Composable
private fun TintedIcon(res: Int, tint: ColorProvider, size: Dp) {
    Image(
        ImageProvider(res),
        contentDescription = null,
        modifier = GlanceModifier.size(size),
        colorFilter = ColorFilter.tint(tint),
    )
}

@Composable
private fun StatusLine(state: BoardState, strings: WidgetStrings) {
    val text = when {
        state.status == ConnectionStatus.OFFLINE && state.board != null -> strings.offline
        state.status == ConnectionStatus.ERROR && state.board != null -> strings.error
        else -> null
    } ?: return
    Text(
        text,
        style = TextStyle(color = WidgetColors.warning, fontSize = 11.sp, fontWeight = FontWeight.Medium),
        maxLines = 1,
        modifier = GlanceModifier.padding(start = 2.dp, bottom = 2.dp),
    )
}

@Composable
private fun Body(
    state: BoardState,
    page: TaskPage,
    strings: WidgetStrings,
    today: LocalDate,
    openApp: Action,
    completions: Map<String, Completion>,
    dense: Boolean,
) {
    val refresh = actionRunCallback<RefreshAction>()
    val board = state.board
    when {
        state.isSignedOut -> {
            val failed = state.status == ConnectionStatus.LOGIN_FAILED
            Message(
                icon = R.drawable.ic_state_signed_out,
                title = if (failed) strings.loginFailed else strings.signedOut,
                body = if (failed) strings.loginFailedHint else strings.signedOutHint,
                button = strings.openApp,
                onClick = openApp,
                dense = dense,
            )
        }
        board == null && state.status == ConnectionStatus.OFFLINE ->
            Message(R.drawable.ic_state_offline, strings.offlineEmpty, strings.offlineEmptyHint, strings.refresh, refresh, dense, WidgetColors.warning)
        board == null && state.status != ConnectionStatus.IDLE && !state.loading ->
            Message(R.drawable.ic_state_error, strings.error, strings.errorHint, strings.refresh, refresh, dense, WidgetColors.warning)
        board == null -> Message(null, strings.loading, null, null, openApp, dense)
        else -> TaskList(rowsFor(board.tasksFor(page), page, completions), page, strings, today, openApp, dense)
    }
}

/** Centered state card. [dense] (short widgets) drops the icon and body and puts the button beside the title. */
@Composable
private fun Message(
    icon: Int?,
    title: String,
    body: String?,
    button: String?,
    onClick: Action,
    dense: Boolean,
    iconTint: ColorProvider = WidgetColors.primary,
) {
    if (dense) {
        Row(modifier = GlanceModifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
            Text(
                title,
                style = TextStyle(color = WidgetColors.onSurface, fontSize = 13.sp, fontWeight = FontWeight.Medium),
                maxLines = 2,
                modifier = GlanceModifier.defaultWeight().clickable(onClick),
            )
            if (button != null) PillButton(button, onClick)
        }
        return
    }
    Column(
        modifier = GlanceModifier.fillMaxSize().clickable(onClick),
        verticalAlignment = Alignment.CenterVertically,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        if (icon != null) {
            TintedIcon(icon, iconTint, 28.dp)
            Spacer(GlanceModifier.height(4.dp))
        }
        Text(
            title,
            style = TextStyle(color = WidgetColors.onSurface, fontSize = 14.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center),
            maxLines = 2,
        )
        if (body != null) {
            Text(
                body,
                style = TextStyle(color = WidgetColors.onSurfaceVariant, fontSize = 12.sp, textAlign = TextAlign.Center),
                maxLines = 3,
                modifier = GlanceModifier.padding(horizontal = 12.dp),
            )
        }
        if (button != null) PillButton(button, onClick)
    }
}

/** Text button: 36 dp pill inside a 48 dp target. */
@Composable
private fun PillButton(label: String, action: Action) {
    Box(modifier = GlanceModifier.height(WidgetDimens.target).clickable(action), contentAlignment = Alignment.Center) {
        Box(
            modifier = GlanceModifier
                .height(36.dp)
                .background(ImageProvider(R.drawable.widget_chip), colorFilter = ColorFilter.tint(WidgetColors.primary))
                .padding(horizontal = 16.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(label, style = TextStyle(color = WidgetColors.onPrimary, fontSize = 13.sp, fontWeight = FontWeight.Bold), maxLines = 1)
        }
    }
}

@Composable
private fun TaskList(rows: List<TaskRowModel>, page: TaskPage, strings: WidgetStrings, today: LocalDate, openApp: Action, dense: Boolean) {
    if (rows.isEmpty()) {
        // An emptied open list is an achievement, so it gets the check mark.
        Message(
            icon = R.drawable.ic_state_empty.takeIf { page != TaskPage.DONE },
            title = strings.empty(page),
            body = null,
            button = null,
            onClick = openApp,
            dense = dense,
        )
        return
    }
    LazyColumn(modifier = GlanceModifier.fillMaxSize()) {
        items(rows, itemId = { it.task.uid.hashCode().toLong() }) { row ->
            TaskRow(row, strings, today, openApp)
        }
    }
}

@Composable
private fun TaskRow(row: TaskRowModel, strings: WidgetStrings, today: LocalDate, openApp: Action) {
    val task = row.task
    val phase = row.phase
    if (phase == CompletionPhase.COLLAPSE) {
        // Last frame: the row has shrunk to a thin struck-through line.
        Row(
            modifier = GlanceModifier.fillMaxWidth().height(WidgetDimens.collapsedRowHeight).padding(start = 17.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            TintedIcon(R.drawable.ic_checkbox_filled, WidgetColors.primary, 14.dp)
            Spacer(GlanceModifier.width(14.dp))
            Text(
                task.name,
                style = TextStyle(color = WidgetColors.onSurfaceVariant, fontSize = 12.sp, textDecoration = TextDecoration.LineThrough),
                maxLines = 1,
            )
        }
        return
    }
    val toggleLabel = (if (task.isDone) strings.markOpen else strings.markDone) + ": " + task.name
    val struck = task.isDone && phase != CompletionPhase.CHECK
    val rowModifier = if (phase != null) {
        GlanceModifier.background(ImageProvider(R.drawable.widget_row_highlight), colorFilter = ColorFilter.tint(WidgetColors.primaryContainer))
    } else {
        GlanceModifier
    }
    Row(
        modifier = rowModifier.fillMaxWidth().height(WidgetDimens.rowHeight),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = GlanceModifier
                .size(WidgetDimens.target)
                .clickable(
                    actionRunCallback<ToggleTaskAction>(
                        actionParametersOf(ToggleTaskAction.UID to task.uid, ToggleTaskAction.DONE to !task.isDone),
                    ),
                )
                .semantics { contentDescription = toggleLabel },
            contentAlignment = Alignment.Center,
        ) {
            Checkbox(filled = task.isDone)
        }
        Spacer(GlanceModifier.width(2.dp))
        Column(
            modifier = GlanceModifier.defaultWeight().fillMaxHeight().clickable(openApp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                task.name,
                style = TextStyle(
                    color = if (struck) WidgetColors.onSurfaceVariant else WidgetColors.onSurface,
                    fontSize = 14.sp,
                    fontWeight = if (phase == CompletionPhase.CHECK) FontWeight.Medium else FontWeight.Normal,
                    textDecoration = if (struck) TextDecoration.LineThrough else TextDecoration.None,
                ),
                maxLines = 1,
            )
            if (phase == null) Meta(task, strings, today)
        }
        if (phase == CompletionPhase.CHECK) {
            Spacer(GlanceModifier.width(6.dp))
            Text(
                strings.completed,
                style = TextStyle(color = WidgetColors.onPrimaryContainer, fontSize = 12.sp, fontWeight = FontWeight.Bold),
                maxLines = 1,
                modifier = GlanceModifier.padding(end = 8.dp),
            )
        }
    }
}

@Composable
private fun Checkbox(filled: Boolean) {
    Box(modifier = GlanceModifier.size(WidgetDimens.checkbox), contentAlignment = Alignment.Center) {
        if (filled) {
            TintedIcon(R.drawable.ic_checkbox_filled, WidgetColors.primary, WidgetDimens.checkbox)
            TintedIcon(R.drawable.ic_check_mark, WidgetColors.onPrimary, 14.dp)
        } else {
            TintedIcon(R.drawable.ic_checkbox_open, WidgetColors.onSurfaceVariant, WidgetDimens.checkbox)
        }
    }
}

/** Second line of a row: due label (red when overdue) and project. */
@Composable
private fun Meta(task: TodoTask, strings: WidgetStrings, today: LocalDate) {
    val due = dueLabel(task.dueDate, today, strings.todayLabel)
    val project = task.projectName
    if (due == null && project == null) return
    val overdue = task.isOverdue(today)
    Row(verticalAlignment = Alignment.CenterVertically) {
        if (due != null) {
            Text(
                due,
                style = TextStyle(
                    color = if (overdue) WidgetColors.error else WidgetColors.onSurfaceVariant,
                    fontSize = 11.sp,
                    fontWeight = if (overdue) FontWeight.Medium else FontWeight.Normal,
                ),
                maxLines = 1,
            )
        }
        if (due != null && project != null) {
            Text(" · ", style = TextStyle(color = WidgetColors.onSurfaceVariant, fontSize = 11.sp), maxLines = 1)
        }
        if (project != null) {
            Text(project, style = TextStyle(color = WidgetColors.onSurfaceVariant, fontSize = 11.sp), maxLines = 1)
        }
    }
}

@Composable
private fun UndoStrip(undo: UndoOffer, strings: WidgetStrings) {
    Row(
        modifier = GlanceModifier
            .fillMaxWidth()
            .height(WidgetDimens.target)
            .background(ImageProvider(R.drawable.widget_chip), colorFilter = ColorFilter.tint(WidgetColors.surfaceVariant))
            .padding(start = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            strings.completedTask(undo.name),
            style = TextStyle(color = WidgetColors.onSurface, fontSize = 13.sp),
            maxLines = 1,
            modifier = GlanceModifier.defaultWeight(),
        )
        Box(
            modifier = GlanceModifier
                .height(WidgetDimens.target)
                .padding(horizontal = 14.dp)
                .clickable(actionRunCallback<UndoAction>(actionParametersOf(UndoAction.UID to undo.uid)))
                .semantics { contentDescription = strings.undo + ": " + undo.name },
            contentAlignment = Alignment.Center,
        ) {
            Text(strings.undo, style = TextStyle(color = WidgetColors.primary, fontSize = 13.sp, fontWeight = FontWeight.Bold), maxLines = 1)
        }
    }
}
