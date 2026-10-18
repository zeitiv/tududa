import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;

import '../data/project_tasks_source.dart';
import '../../core/design/token_lookup.dart';
import '../../core/design/tokens.dart';
import '../../core/time/calendar_date.dart';
import '../../core/time/date_formatters.dart';
import '../../l10n/l10n_ext.dart';

/// Kanban board: one snapping column per task status.
///
/// Cards can be dragged (long press) onto another column, or moved through
/// the "Move to…" menu of each card (button, right click, or the screen
/// reader's custom actions), so no gesture is required.
class KanbanBoard extends StatefulWidget {
  final List<ProjectTaskRef> tasks;
  final Function(ProjectTaskRef, int) onTaskStatusChanged;
  final Function(ProjectTaskRef)? onTaskTap;

  const KanbanBoard({
    super.key,
    required this.tasks,
    required this.onTaskStatusChanged,
    this.onTaskTap,
  });

  @override
  State<KanbanBoard> createState() => _KanbanBoardState();
}

/// Mirror Tududi's task lifecycle so tasks do not disappear by status.
const _columns = [0, 6, 1, 4, 5, 2, 3];

String _statusName(int status, AppLocalizations strings) => switch (status) {
  0 => strings.kanbanStatusToDo,
  3 => strings.kanbanStatusArchived,
  6 => strings.kanbanStatusPlanned,
  1 => strings.kanbanStatusInProgress,
  2 => strings.kanbanStatusDone,
  4 => strings.kanbanStatusWaiting,
  5 => strings.kanbanStatusCancelled,
  _ => strings.kanbanStatusOther,
};

Color _statusColor(AppTokens t, int status) => switch (status) {
  1 => t.statusInProgress,
  2 => t.statusDone,
  3 => t.statusArchived,
  4 => t.statusWaiting,
  5 => t.statusCancelled,
  6 => t.statusPlanned,
  _ => t.statusNotStarted,
};

class _KanbanBoardState extends State<KanbanBoard> {
  PageController? _controller;
  double _fraction = 0;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  PageController _controllerFor(double fraction) {
    if (_controller == null || (_fraction - fraction).abs() > 0.001) {
      _controller?.dispose();
      _fraction = fraction;
      _controller = PageController(viewportFraction: fraction);
    }
    return _controller!;
  }

  void _move(BuildContext context, ProjectTaskRef task, int status) {
    widget.onTaskStatusChanged(task, status);
    final strings = context.l10n;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(strings.kanbanV2Moved(_statusName(status, strings))),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final theme = Theme.of(context);

    if (widget.tasks.isEmpty) {
      return Center(
        child: Text(
          strings.kanbanNoTasks,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 360.0;
        final columnWidth = (width * 0.86).clamp(240.0, 320.0);
        final controller = _controllerFor((columnWidth / width).clamp(0.2, 1));
        return PageView.builder(
          controller: controller,
          padEnds: false,
          itemCount: _columns.length,
          itemBuilder: (context, index) {
            final status = _columns[index];
            final columnTasks =
                widget.tasks.where((t) => t.status == status).toList()
                  ..sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
            return _KanbanColumn(
              status: status,
              title: _statusName(status, strings),
              tasks: columnTasks,
              onTaskTap: widget.onTaskTap,
              onDrop: (task) => widget.onTaskStatusChanged(task, status),
              onMove: (task, to) => _move(context, task, to),
            );
          },
        );
      },
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({
    required this.status,
    required this.title,
    required this.tasks,
    required this.onDrop,
    required this.onMove,
    this.onTaskTap,
  });

  final int status;
  final String title;
  final List<ProjectTaskRef> tasks;
  final void Function(ProjectTaskRef) onDrop;
  final void Function(ProjectTaskRef, int) onMove;
  final Function(ProjectTaskRef)? onTaskTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = context.tokens;
    final strings = context.l10n;
    final color = _statusColor(tokens, status);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: DragTarget<ProjectTaskRef>(
        onWillAcceptWithDetails: (details) => details.data.status != status,
        onAcceptWithDetails: (details) => onDrop(details.data),
        builder: (context, candidates, rejected) {
          final hovering = candidates.isNotEmpty;
          return AnimatedContainer(
            duration: tokens.motionShort,
            decoration: BoxDecoration(
              color: hovering
                  ? Color.alphaBlend(
                      color.withValues(alpha: 0.12),
                      scheme.surfaceContainerLow,
                    )
                  : scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(tokens.radiusLarge),
              border: Border.all(
                color: hovering ? color : scheme.outlineVariant,
                width: hovering ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  label: strings.kanbanV2ColumnSummary(title, tasks.length),
                  excludeSemantics: true,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      tokens.space4,
                      tokens.space3,
                      tokens.space4,
                      tokens.space2,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: tokens.space2),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Color.alphaBlend(
                              color.withValues(alpha: 0.14),
                              scheme.surfaceContainerLow,
                            ),
                            borderRadius: BorderRadius.circular(
                              tokens.radiusFull,
                            ),
                          ),
                          child: Text(
                            '${tasks.length}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(height: 3, color: color.withValues(alpha: 0.7)),
                Expanded(
                  child: tasks.isEmpty
                      ? Center(
                          child: Text(
                            hovering
                                ? strings.kanbanV2DropHere
                                : strings.kanbanV2EmptyColumn,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.all(tokens.space3),
                          itemCount: tasks.length,
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            return _DraggableCard(
                              key: ValueKey(task.uid.value),
                              task: task,
                              onTap: onTaskTap == null
                                  ? null
                                  : () => onTaskTap!(task),
                              onMove: (to) => onMove(task, to),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DraggableCard extends StatelessWidget {
  const _DraggableCard({
    super.key,
    required this.task,
    required this.onMove,
    this.onTap,
  });

  final ProjectTaskRef task;
  final VoidCallback? onTap;
  final void Function(int status) onMove;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final strings = context.l10n;
    final targets = [
      for (final s in _columns)
        if (s != task.status) s,
    ];

    return Semantics(
      customSemanticsActions: {
        for (final s in targets)
          CustomSemanticsAction(
            label: strings.kanbanV2MoveToStatus(_statusName(s, strings)),
          ): () =>
              onMove(s),
      },
      child: LongPressDraggable<ProjectTaskRef>(
        data: task,
        feedback: TweenAnimationBuilder<double>(
          tween: Tween(begin: 1, end: 1.04),
          duration: tokens.motionShort,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            elevation: tokens.elevationHigh,
            borderRadius: BorderRadius.circular(tokens.radiusMedium + 4),
            child: SizedBox(
              width: 260,
              child: _KanbanCard(task: task, onMove: onMove),
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.35,
          child: _KanbanCard(task: task, onMove: onMove),
        ),
        child: _KanbanCard(task: task, onTap: onTap, onMove: onMove),
      ),
    );
  }
}

class _KanbanCard extends StatelessWidget {
  final ProjectTaskRef task;
  final VoidCallback? onTap;
  final void Function(int status) onMove;

  const _KanbanCard({required this.task, required this.onMove, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = context.tokens;
    final strings = context.l10n;
    final radius = BorderRadius.circular(tokens.radiusMedium + 4);
    final overdue =
        task.dueDate != null &&
        task.dueDate!.isBefore(DateTime.now()) &&
        !task.isCompleted;
    final dueColor = overdue ? tokens.overdue : scheme.onSurfaceVariant;

    return Padding(
      padding: EdgeInsets.only(bottom: tokens.space3),
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onSecondaryTap: () => _showMenu(context),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 4,
                child: ColoredBox(color: tokens.priorityFor(task.priority)),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.space4,
                  tokens.space3,
                  tokens.space1,
                  tokens.space3,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              task.name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                decoration: task.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: task.isCompleted
                                    ? scheme.onSurfaceVariant
                                    : scheme.onSurface,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (task.dueDate != null) ...[
                            SizedBox(height: tokens.space2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 14,
                                  color: dueColor,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    DateFormats(Localizations.localeOf(context))
                                        .mediumDate(
                                          CalendarDate(
                                            task.dueDate!.year,
                                            task.dueDate!.month,
                                            task.dueDate!.day,
                                          ),
                                        ),
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(color: dueColor),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: IconButton(
                        tooltip: strings.kanbanV2MoveTo,
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.more_vert, size: 20),
                        onPressed: () => _showMenu(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMenu(BuildContext context) async {
    final strings = context.l10n;
    final box = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final rect = topLeft & box.size;
    final picked = await showMenu<int>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(rect.right - 40, rect.top + 32, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem<int>(
          enabled: false,
          child: Text(
            strings.kanbanV2MoveTo,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        for (final s in _columns)
          PopupMenuItem<int>(
            value: s,
            enabled: s != task.status,
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _statusColor(context.tokens, s),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(child: Text(_statusName(s, strings))),
                if (s == task.status) ...[
                  const SizedBox(width: 8),
                  Text('(${strings.kanbanV2CurrentColumn})'),
                ],
              ],
            ),
          ),
      ],
    );
    if (picked != null) onMove(picked);
  }
}
