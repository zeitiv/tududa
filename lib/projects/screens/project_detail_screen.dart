import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/project_provider.dart';
import '../../common/widgets/surface_card.dart';
import '../../core/api/api_error.dart';
import '../../core/ids.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/sync/sync_handler.dart';
import '../data/project_tasks_source.dart';
import '../../core/design/token_lookup.dart';
import '../../core/design/tokens.dart';
import '../widgets/kanban_board.dart';
import '../../l10n/l10n_ext.dart';
import '../widgets/project_status_label.dart';

/// Project detail screen with tasks and notes.
class ProjectDetailScreen extends ConsumerStatefulWidget {
  final dynamic projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  ConsumerState<ProjectDetailScreen> createState() =>
      _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  bool _isKanbanView = true;

  ProjectUid get _uid => ProjectUid(widget.projectId.toString());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final projectAsync = ref.watch(projectDetailProvider(_uid));
    final strings = context.l10n;

    return projectAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(
            e is NotFoundError
                ? strings.projectNotFound
                : strings.projectLoadError('$e'),
          ),
        ),
      ),
      data: (project) {
        final tasksAsync = ref.watch(projectTasksProvider(_uid));
        final tasks = tasksAsync.value ?? const <ProjectTaskRef>[];

        final statusColor = context.tokens.projectStatusFor(project.status);

        return Scaffold(
          appBar: AppBar(
            title: Text(project.name),
            actions: [
              IconButton(
                tooltip: strings.projectEdit,
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => context.push('/projects/${_uid.value}/edit'),
              ),
              PopupMenuButton<String>(
                onSelected: (action) async {
                  if (action == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(strings.projectDeleteTitle),
                        content: Text(strings.projectDeleteMessage),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(strings.projectCancel),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(strings.projectDelete),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && context.mounted) {
                      try {
                        await ref
                            .read(projectListProvider.notifier)
                            .delete(_uid);
                        if (context.mounted) context.pop();
                      } on ApiError catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(e.message)));
                        }
                      }
                    }
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      strings.projectDelete,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () =>
                ref.read(syncEngineProvider).requestSync(SyncReason.manual),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Project header card
                SurfaceCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              projectStatusLabel(strings, project.status),
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (project.priorityName != null)
                            Icon(
                              Icons.flag_rounded,
                              color: context.tokens.priorityForName(
                                project.priorityName,
                              ),
                              size: 20,
                            ),
                        ],
                      ),
                      if (project.description != null &&
                          project.description!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          project.description!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (project.areaName != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.layers_outlined,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              strings.projectAreaLabel(project.areaName!),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Tasks section
                Row(
                  children: [
                    Text(
                      strings.projectTasksHeading,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () =>
                          context.push('/tasks/new?projectId=${project.id}'),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(strings.projectAddTask),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.view_kanban_rounded),
                        label: Text(strings.projectViewBoard),
                      ),
                      ButtonSegment(
                        value: false,
                        icon: const Icon(Icons.view_list_rounded),
                        label: Text(strings.projectViewList),
                      ),
                    ],
                    selected: {_isKanbanView},
                    onSelectionChanged: (Set<bool> newSelection) {
                      setState(() {
                        _isKanbanView = newSelection.first;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 4),
                if (tasksAsync.isLoading && !tasksAsync.hasValue)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (tasksAsync.hasError && !tasksAsync.hasValue)
                  Center(
                    child: Text(
                      strings.projectLoadError('${tasksAsync.error}'),
                    ),
                  )
                else if (tasks.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          strings.kanbanNoTasks,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  )
                else if (_isKanbanView)
                  SizedBox(
                    height: 500, // Fixed height for horizontal board
                    child: KanbanBoard(
                      tasks: tasks,
                      onTaskTap: (task) {
                        context.push('/tasks/${task.uid.value}');
                      },
                      onTaskStatusChanged: (task, newStatus) async {
                        try {
                          await ref
                              .read(projectTasksProvider(_uid).notifier)
                              .setStatus(task, newStatus);
                        } on ApiError catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(e.message)));
                          }
                        }
                      },
                    ),
                  )
                else
                  ...tasks.map(
                    (task) => ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: Icon(
                        task.isCompleted
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: task.isCompleted
                            ? Colors.green
                            : theme.colorScheme.outline,
                      ),
                      title: Text(
                        task.name,
                        style: TextStyle(
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      onTap: () => context.push('/tasks/${task.uid.value}'),
                    ),
                  ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }
}
