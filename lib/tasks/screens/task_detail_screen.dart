import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../core/ids.dart';
import '../../core/time/calendar_date.dart';
import '../domain/task.dart';
import '../providers/task_provider.dart';
import '../widgets/api_error_message.dart';
import '../../core/theme/app_theme.dart';

/// Task detail screen showing full task info, subtasks, and actions.
class TaskDetailScreen extends ConsumerWidget {
  /// The task's uid (the route's `:id`).
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = TaskUid(taskId);
    final taskAsync = ref.watch(taskDetailProvider(uid));
    final theme = Theme.of(context);

    return taskAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(apiErrorMessage(e), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(taskDetailProvider(uid)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (task) {
        final today = CalendarDate.fromDateTime(DateTime.now());
        final priorityColor = AppTheme.getPriorityColor(
          task.priority.code,
          theme.colorScheme,
        );

        return Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => context.push('/tasks/$taskId/edit'),
              ),
              PopupMenuButton<String>(
                onSelected: (action) async {
                  if (action == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Task'),
                        content: const Text(
                          'Are you sure you want to delete this task?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && context.mounted) {
                      final result = await ref
                          .read(taskActionsProvider)
                          .delete(uid);
                      if (!context.mounted) return;
                      if (result.ok) {
                        context.pop();
                      } else {
                        _showError(context, result.error!);
                      }
                    }
                  } else if (action == 'toggle') {
                    final result = await ref
                        .read(taskActionsProvider)
                        .toggleComplete(task);
                    if (context.mounted && !result.ok) {
                      _showError(context, result.error!);
                    }
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(
                      task.isCompleted
                          ? 'Mark as Incomplete'
                          : 'Mark as Complete',
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status & Priority chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(
                      icon: task.isCompleted
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      label: _statusName(task.status),
                      color: task.isCompleted
                          ? Colors.green
                          : theme.colorScheme.primary,
                    ),
                    _InfoChip(
                      icon: Icons.flag_rounded,
                      label: _priorityName(task.priority),
                      color: priorityColor,
                    ),
                    if (task.isRecurring)
                      _InfoChip(
                        icon: Icons.repeat_rounded,
                        label: _recurrenceLabel(task),
                        color: theme.colorScheme.tertiary,
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  task.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: task.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(height: 16),

                // Meta info
                if (task.dueDate != null)
                  _MetaRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Due',
                    value: _dueLabel(task),
                    isOverdue: task.isOverdue(today),
                  ),
                if (task.deferUntil != null)
                  _MetaRow(
                    icon: Icons.schedule_outlined,
                    label: 'Defer until',
                    value: DateFormat.yMMMd().format(task.deferUntil!),
                  ),
                if (task.projectName != null)
                  _MetaRow(
                    icon: Icons.folder_outlined,
                    label: 'Project',
                    value: task.projectName!,
                  ),
                if (task.completedAt != null)
                  _MetaRow(
                    icon: Icons.check_circle_outline,
                    label: 'Completed',
                    value: DateFormat.yMMMd().format(task.completedAt!),
                  ),

                // Tags
                if (task.tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: task.tags
                        .map(
                          (tag) => Chip(
                            label: Text(
                              tag.name,
                              style: theme.textTheme.labelSmall,
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(),
                  ),
                ],

                // Note / Description
                if (task.note != null && task.note!.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),
                  MarkdownBody(
                    data: task.note!,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                        .copyWith(p: theme.textTheme.bodyMedium),
                  ),
                ],

                // Subtasks
                if (task.hasSubtasks) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(
                    'Subtasks',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...task.subtasks.map(
                    (sub) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        sub.isCompleted
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: sub.isCompleted
                            ? Colors.green
                            : theme.colorScheme.outline,
                        size: 22,
                      ),
                      title: Text(
                        sub.name,
                        style: TextStyle(
                          decoration: sub.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      dense: true,
                    ),
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showError(BuildContext context, Object error) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
  }

  String _dueLabel(Task task) {
    final date = DateFormat.yMMMd().format(task.dueDate!.toLocalDateTime());
    return task.dueTime == null ? date : '$date ${task.dueTime!.format()}';
  }

  String _statusName(TaskStatus status) => switch (status) {
    TaskStatus.notStarted => 'Not Started',
    TaskStatus.inProgress => 'In Progress',
    TaskStatus.done => 'Done',
    TaskStatus.archived => 'Archived',
    TaskStatus.waiting => 'Waiting',
    TaskStatus.cancelled => 'Cancelled',
    TaskStatus.planned => 'Planned',
    TaskStatus.unknown => 'Unknown',
  };

  String _priorityName(Priority priority) => switch (priority) {
    Priority.low => 'Low',
    Priority.medium => 'Medium',
    Priority.high => 'High',
  };

  String _recurrenceLabel(Task task) {
    final interval = task.recurrenceInterval ?? 1;
    switch (task.recurrenceType) {
      case 'daily':
        return interval == 1 ? 'Daily' : 'Every $interval days';
      case 'weekly':
        return interval == 1 ? 'Weekly' : 'Every $interval weeks';
      case 'monthly':
        return interval == 1 ? 'Monthly' : 'Every $interval months';
      case 'monthly_weekday':
        return 'Monthly (weekday)';
      case 'monthly_last_day':
        return 'Monthly (last day)';
      default:
        return task.recurrenceType;
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isOverdue;

  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isOverdue = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isOverdue
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: isOverdue ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
