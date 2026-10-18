import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../common/widgets/async_states.dart';
import '../../core/ids.dart';
import '../../l10n/l10n_ext.dart';
import '../../projects/data/project_tasks_source.dart';
import '../../projects/widgets/kanban_board.dart';
import '../domain/task.dart';
import '../providers/task_provider.dart';
import '../widgets/api_error_message.dart';
import '../widgets/bulk_action_bar.dart';
import '../widgets/task_tile.dart';

/// "All tasks" (under More): filter chips, list/board toggle and sort. Adding
/// tasks is done from the shell's global quick-add button.
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  bool _isKanbanView = false;

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(apiErrorMessage(context.l10n, error))),
    );
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
    final strings = context.l10n;
    final actions = ref.read(taskActionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.taskListTitle),
        actions: [
          IconButton(
            icon: Icon(
              _isKanbanView
                  ? Icons.view_list_rounded
                  : Icons.view_kanban_rounded,
            ),
            tooltip: _isKanbanView
                ? strings.taskViewList
                : strings.taskViewBoard,
            onPressed: () => setState(() => _isKanbanView = !_isKanbanView),
          ),
          PopupMenuButton<TaskSort>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: strings.taskSortTooltip,
            onSelected: (sort) {
              ref.read(taskSortProvider.notifier).setSort(sort);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: TaskSort.priority,
                child: Text(strings.taskSortPriority),
              ),
              PopupMenuItem(
                value: TaskSort.dueDate,
                child: Text(strings.taskSortDueDate),
              ),
              PopupMenuItem(
                value: TaskSort.name,
                child: Text(strings.taskSortName),
              ),
              PopupMenuItem(
                value: TaskSort.createdAt,
                child: Text(strings.taskSortCreated),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: const BulkActionBar(),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: TaskFilter.values.map((filter) {
                final isSelected = current == filter;
                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
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
          Expanded(
            child: AsyncStateView<List<Task>>(
              value: async,
              emptyIcon: _filterIcon(current),
              emptyTitle: _emptyText(current, strings),
              onRetry: () => ref.invalidate(taskListProvider(current)),
              data: (all) {
                final tasks = sortTasks(
                  all,
                  sortState.sort,
                  ascending: sortState.ascending,
                );
                if (_isKanbanView) {
                  return KanbanBoard(
                    tasks: [for (final t in tasks) _boardRef(t)],
                    onTaskTap: (r) => _openTask(_byUid(tasks, r.uid)),
                    onTaskStatusChanged: (r, newStatus) async {
                      final result = await actions.setStatus(
                        _byUid(tasks, r.uid),
                        TaskStatus.fromCode(newStatus),
                      );
                      if (result.error != null) _showError(result.error!);
                    },
                  );
                }
                return RefreshIndicator(
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
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: tasks.length,
                    itemBuilder: (context, i) => TaskTile(
                      key: ValueKey('task-${tasks[i].uid.value}'),
                      task: tasks[i],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _emptyText(TaskFilter filter, AppLocalizations strings) =>
      switch (filter) {
        TaskFilter.today => strings.taskEmptyToday,
        TaskFilter.completed => strings.taskEmptyCompleted,
        _ => strings.taskEmptyAll,
      };

  String _filterLabel(TaskFilter filter, AppLocalizations strings) {
    switch (filter) {
      case TaskFilter.today:
        return strings.taskFilterToday;
      case TaskFilter.upcoming:
        return strings.taskFilterUpcoming;
      case TaskFilter.someday:
        return strings.taskFilterSomeday;
      case TaskFilter.completed:
        return strings.taskFilterCompleted;
      case TaskFilter.all:
        return strings.taskFilterAll;
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
