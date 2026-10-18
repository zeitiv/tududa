import 'package:flutter/material.dart';

import '../data/project_tasks_source.dart';
import '../../core/design/token_lookup.dart';
import '../../core/design/tokens.dart';
import '../../common/widgets/surface_card.dart';

import 'package:intl/intl.dart';

import '../../l10n/l10n_ext.dart';

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

class _KanbanBoardState extends State<KanbanBoard> {
  // Mirror Tududi's task lifecycle so tasks do not disappear by status.
  final List<int> _columns = [0, 6, 1, 4, 5, 2, 3];

  String _getStatusName(int status, AppLocalizations strings) {
    switch (status) {
      case 0:
        return strings.kanbanStatusToDo;
      case 3:
        return strings.kanbanStatusArchived;
      case 6:
        return strings.kanbanStatusPlanned;
      case 1:
        return strings.kanbanStatusInProgress;
      case 2:
        return strings.kanbanStatusDone;
      case 4:
        return strings.kanbanStatusWaiting;
      case 5:
        return strings.kanbanStatusCancelled;
      default:
        return strings.kanbanStatusOther;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;

    if (widget.tasks.isEmpty) {
      return Center(
        child: Text(
          strings.kanbanNoTasks,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _columns.length,
      itemBuilder: (context, index) {
        final status = _columns[index];
        final columnTasks = widget.tasks
            .where((t) => t.status == status)
            .toList();
        // Sort tasks in column (by order or ID)
        columnTasks.sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));

        return _buildKanbanColumn(
          context,
          status,
          _getStatusName(status, strings),
          columnTasks,
        );
      },
    );
  }

  Widget _buildKanbanColumn(
    BuildContext context,
    int status,
    String title,
    List<ProjectTaskRef> tasks,
  ) {
    final theme = Theme.of(context);

    return SurfaceCard(
      width: 280, // Fixed width for columns
      margin: const EdgeInsets.symmetric(horizontal: 8),
      borderRadius: BorderRadius.circular(24),
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${tasks.length}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: DragTarget<ProjectTaskRef>(
              onWillAcceptWithDetails: (details) {
                // Return true if dropping inside a different column
                return details.data.status != status;
              },
              onAcceptWithDetails: (details) {
                widget.onTaskStatusChanged(details.data, status);
              },
              builder: (context, candidateData, rejectedData) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: candidateData.isNotEmpty
                        ? theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.3,
                          )
                        : Colors.transparent,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return LongPressDraggable<ProjectTaskRef>(
                        data: task,
                        feedback: Material(
                          color: Colors.transparent,
                          child: Opacity(
                            opacity: 0.8,
                            child: SizedBox(
                              width: 256,
                              child: _KanbanCard(task: task),
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.5,
                          child: _KanbanCard(task: task),
                        ),
                        child: _KanbanCard(
                          task: task,
                          onTap: widget.onTaskTap != null
                              ? () => widget.onTaskTap!(task)
                              : null,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _KanbanCard extends StatelessWidget {
  final ProjectTaskRef task;
  final VoidCallback? onTap;

  const _KanbanCard({required this.task, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priorityColor = context.tokens.priorityFor(task.priority);

    return SurfaceCard(
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      task.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: task.isCompleted
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onSurface,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (task.priority > 0)
                    Icon(Icons.flag_rounded, size: 16, color: priorityColor),
                ],
              ),
              if (task.dueDate != null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color:
                          (task.dueDate!.isBefore(DateTime.now()) &&
                              !task.isCompleted)
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat.MMMd().format(task.dueDate!),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color:
                            (task.dueDate!.isBefore(DateTime.now()) &&
                                !task.isCompleted)
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
