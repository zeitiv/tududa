import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/task.dart';
import '../providers/task_provider.dart';

/// The one task row used by every list (Today, Upcoming, project, search...).
///
/// CONTRACT (other screens rely on exactly this signature; T5.1 replaces the
/// body with the full tile: indicators, inline title edit, swipe actions,
/// multi-select and undo, all driven by providers so callers pass only the
/// task):
class TaskTile extends ConsumerWidget {
  const TaskTile({
    super.key,
    required this.task,
    this.onTap,
    this.showProject = true,
    this.showDueDate = true,
  });

  final Task task;

  /// Defaults to opening the task detail screen.
  final VoidCallback? onTap;
  final bool showProject;
  final bool showDueDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Checkbox(
        value: task.isCompleted,
        onChanged: (_) => ref.read(taskActionsProvider).toggleComplete(task),
      ),
      title: Text(task.name),
      onTap: onTap ?? () => context.push('/tasks/${task.uid?.value ?? ''}'),
    );
  }
}
