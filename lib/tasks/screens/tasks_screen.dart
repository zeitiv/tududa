import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/ids.dart';
import '../../core/time/calendar_date.dart';
import '../../projects/data/project_tasks_source.dart';
import '../domain/task.dart';
import '../providers/task_provider.dart';
import '../widgets/api_error_message.dart';
import '../../core/theme/app_theme.dart';
import '../../common/widgets/glass_container.dart';
import '../../projects/widgets/kanban_board.dart';
import '../../l10n/strings.dart';

/// Main tasks screen with filter tabs (Today/Upcoming/Someday/Completed).
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  bool _isKanbanView = false;

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
  }

  // The board takes the projects feature's lightweight task view.
  ProjectTaskRef _boardRef(Task t) => ProjectTaskRef(
    id: t.serverId,
    uid: t.uid,
    name: t.name,
    status: t.status.code,
    priority: t.priority.code,
    dueDate: t.dueDate?.toLocalDateTime(),
    order: t.order,
  );

  Task _byUid(List<Task> tasks, TaskUid uid) =>
      tasks.firstWhere((t) => t.uid == uid);

  void _openTask(Task task) {
    if (task.uid.value.isNotEmpty) context.push('/tasks/${task.uid.value}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = ref.watch(selectedTaskFilterProvider);
    final sortState = ref.watch(taskSortProvider);
    final async = ref.watch(taskListProvider(current));
    final tasks = sortTasks(
      async.value ?? const <Task>[],
      sortState.sort,
      ascending: sortState.ascending,
    );
    final strings = context.l10n;
    final actions = ref.read(taskActionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.tasks),
        actions: [
          // Kanban/List toggle
          IconButton(
            icon: Icon(
              _isKanbanView
                  ? Icons.view_list_rounded
                  : Icons.view_kanban_rounded,
            ),
            tooltip: _isKanbanView ? strings.list : strings.board,
            onPressed: () => setState(() => _isKanbanView = !_isKanbanView),
          ),
          PopupMenuButton<TaskSort>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort',
            onSelected: (sort) {
              ref.read(taskSortProvider.notifier).setSort(sort);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: TaskSort.priority,
                child: Text('Priority'),
              ),
              const PopupMenuItem(
                value: TaskSort.dueDate,
                child: Text('Due Date'),
              ),
              const PopupMenuItem(value: TaskSort.name, child: Text('Name')),
              const PopupMenuItem(
                value: TaskSort.createdAt,
                child: Text('Date Created'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: TaskFilter.values.map((filter) {
                final isSelected = current == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_filterLabel(filter, strings)),
                    selected: isSelected,
                    onSelected: (_) {
                      ref
                          .read(selectedTaskFilterProvider.notifier)
                          .select(filter);
                    },
                    showCheckmark: false,
                    avatar: isSelected
                        ? null
                        : Icon(
                            _filterIcon(filter),
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Task content (list or kanban)
          Expanded(
            child: !async.hasValue && async.isLoading
                ? const Center(child: CircularProgressIndicator())
                : !async.hasValue && async.hasError
                ? _ErrorView(
                    error: apiErrorMessage(async.error!),
                    onRetry: () =>
                        ref.read(taskListProvider(current).notifier).refresh(),
                  )
                : tasks.isEmpty
                ? _EmptyView(filter: current)
                : _isKanbanView
                ? // Kanban board view
                  KanbanBoard(
                    tasks: [for (final t in tasks) _boardRef(t)],
                    onTaskTap: (ref) => _openTask(_byUid(tasks, ref.uid)),
                    onTaskStatusChanged: (ref, newStatus) async {
                      final result = await actions.setStatus(
                        _byUid(tasks, ref.uid),
                        TaskStatus.fromCode(newStatus),
                      );
                      if (result.error != null) _showError(result.error!);
                    },
                  )
                : // List view
                  RefreshIndicator(
                    onRefresh: () async {
                      try {
                        await ref
                            .read(taskListProvider(current).notifier)
                            .refresh();
                      } catch (e) {
                        _showError(e);
                      }
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return _TaskListItem(
                          task: task,
                          onTap: () => _openTask(task),
                          onToggle: () async {
                            final result = await actions.toggleComplete(task);
                            if (result.error != null) _showError(result.error!);
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/tasks/new'),
        icon: const Icon(Icons.add_rounded),
        label: Text(strings.newTask),
      ),
    );
  }

  String _filterLabel(TaskFilter filter, AppStrings strings) {
    switch (filter) {
      case TaskFilter.today:
        return strings.today;
      case TaskFilter.upcoming:
        return strings.upcoming;
      case TaskFilter.someday:
        return strings.someday;
      case TaskFilter.completed:
        return strings.completed;
      case TaskFilter.all:
        return strings.isZh ? '全部' : 'All';
    }
  }

  IconData _filterIcon(TaskFilter filter) {
    switch (filter) {
      case TaskFilter.today:
        return Icons.today_outlined;
      case TaskFilter.upcoming:
        return Icons.upcoming_outlined;
      case TaskFilter.someday:
        return Icons.cloud_outlined;
      case TaskFilter.completed:
        return Icons.check_circle_outline;
      case TaskFilter.all:
        return Icons.list_rounded;
    }
  }
}

class _TaskListItem extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  const _TaskListItem({
    required this.task,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priorityColor = AppTheme.getPriorityColor(
      task.priority.code,
      theme.colorScheme,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: GlassContainer(
        borderRadius: BorderRadius.circular(20),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 2,
          ),
          leading: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: task.isCompleted
                      ? theme.colorScheme.primary
                      : priorityColor.withValues(alpha: 0.6),
                  width: 2,
                ),
                color: task.isCompleted
                    ? theme.colorScheme.primary
                    : Colors.transparent,
              ),
              child: task.isCompleted
                  ? Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: theme.colorScheme.onPrimary,
                    )
                  : null,
            ),
          ),
          title: Text(
            task.name,
            style: theme.textTheme.bodyLarge?.copyWith(
              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
              color: task.isCompleted
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: _buildSubtitle(context),
          trailing: _buildTrailing(context),
          onTap: onTap,
        ),
      ),
    );
  }

  Widget? _buildSubtitle(BuildContext context) {
    final theme = Theme.of(context);
    final parts = <Widget>[];

    if (task.projectName != null) {
      parts.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_outlined,
              size: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                task.projectName!,
                style: theme.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    if (task.dueDate != null) {
      final isOverdue = task.isOverdue(
        CalendarDate.fromDateTime(DateTime.now()),
      );
      parts.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.schedule_rounded,
              size: 12,
              color: isOverdue
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 3),
            Text(
              DateFormat.MMMd().format(task.dueDate!.toLocalDateTime()),
              style: theme.textTheme.bodySmall?.copyWith(
                color: isOverdue ? theme.colorScheme.error : null,
                fontWeight: isOverdue ? FontWeight.w600 : null,
              ),
            ),
          ],
        ),
      );
    }

    if (task.isRecurring) {
      parts.add(
        Icon(Icons.repeat_rounded, size: 14, color: theme.colorScheme.tertiary),
      );
    }

    if (parts.isEmpty) return null;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(spacing: 12, runSpacing: 4, children: parts),
    );
  }

  Widget? _buildTrailing(BuildContext context) {
    final theme = Theme.of(context);
    if (task.priority != Priority.low) {
      final color = AppTheme.getPriorityColor(
        task.priority.code,
        theme.colorScheme,
      );
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          task.priority == Priority.high ? '!!!' : '!!',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      );
    }
    return null;
  }
}

class _EmptyView extends StatelessWidget {
  final TaskFilter filter;
  const _EmptyView({required this.filter});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = context.l10n;
    String message;
    IconData icon;
    switch (filter) {
      case TaskFilter.today:
        message = strings.noTasksToday;
        icon = Icons.celebration_outlined;
        break;
      case TaskFilter.completed:
        message = strings.noCompletedTasks;
        icon = Icons.check_circle_outline;
        break;
      default:
        message = strings.noTasksYet;
        icon = Icons.task_outlined;
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: onRetry,
            child: Text(context.l10n.retry),
          ),
        ],
      ),
    );
  }
}
