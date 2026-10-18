import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../common/undo/undo_controller.dart';
import '../../core/api/patch.dart' show Patch;
import '../../core/design/token_lookup.dart';
import '../../core/design/tokens.dart';
import '../../l10n/l10n_ext.dart';
import '../data/task_patch.dart';
import '../domain/task.dart';
import '../domain/task_labels.dart';
import '../providers/task_provider.dart';
import 'postpone_sheet.dart';

/// The one-task actions behind swipe, the overflow menu and the accessibility
/// actions, each followed by an undo snackbar.
class TaskQuickActions {
  const TaskQuickActions._();

  /// Completes the task, or reopens it when it is done.
  static Future<void> toggleComplete(
    BuildContext context,
    WidgetRef ref,
    Task task,
  ) async {
    final r = await ref.read(taskActionsProvider).toggleComplete(task);
    if (!context.mounted || r.undo == null) return;
    final l = context.l10n;
    ref
        .read(undoControllerProvider)
        .show(
          context,
          task.isCompleted ? l.undoUpdated(1) : l.undoCompleted(1),
          r.undo,
        );
  }

  static Future<void> delete(
    BuildContext context,
    WidgetRef ref,
    Task task,
  ) async {
    final r = await ref.read(taskActionsProvider).delete(task.uid);
    if (!context.mounted) return;
    ref
        .read(undoControllerProvider)
        .show(context, context.l10n.undoDeleted(1), r.undo);
  }

  static Future<void> setPriority(
    BuildContext context,
    WidgetRef ref,
    Task task,
    Priority priority,
  ) async {
    final r = await ref
        .read(taskActionsProvider)
        .update(task.uid, TaskPatch(priority: Patch.set(priority)));
    if (!context.mounted) return;
    ref
        .read(undoControllerProvider)
        .show(context, context.l10n.undoUpdated(1), r.undo);
  }

  /// Asks for a priority, then applies it.
  static Future<void> pickPriority(
    BuildContext context,
    WidgetRef ref,
    Task task,
  ) async {
    final p = await showPrioritySheet(context, current: task.priority);
    if (p == null || !context.mounted) return;
    await setPriority(context, ref, task, p);
  }
}

/// Bottom sheet that returns the chosen priority.
Future<Priority?> showPrioritySheet(
  BuildContext context, {
  Priority? current,
}) => showModalBottomSheet<Priority>(
  context: context,
  showDragHandle: true,
  builder: (ctx) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final p in Priority.values.reversed)
          ListTile(
            minTileHeight: 48,
            leading: Icon(
              Icons.flag_outlined,
              color: ctx.tokens.priorityFor(p.code),
            ),
            title: Text(taskPriorityLabel(ctx.l10n, p)),
            trailing: p == current ? const Icon(Icons.check) : null,
            onTap: () => Navigator.pop(ctx, p),
          ),
      ],
    ),
  ),
);

/// Wraps a task row with swipe actions: a full swipe from the start edge
/// completes the task (undo snackbar), a swipe from the end edge reveals
/// Postpone and Priority. Slidable mirrors both for right-to-left locales.
class SwipeTaskTile extends ConsumerWidget {
  const SwipeTaskTile({
    super.key,
    required this.task,
    required this.child,
    this.enabled = true,
  });

  final Task task;
  final Widget child;

  /// False while selecting or editing: no swiping then.
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!enabled) return child;
    final l = context.l10n;
    final tokens = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    return Slidable(
      key: ValueKey('swipe-${task.uid.value}'),
      startActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.3,
        dismissible: DismissiblePane(
          dismissThreshold: 0.6,
          closeOnCancel: true,
          confirmDismiss: () async {
            await TaskQuickActions.toggleComplete(context, ref, task);
            return false;
          },
          onDismissed: () {},
        ),
        children: [
          SlidableAction(
            onPressed: (_) =>
                TaskQuickActions.toggleComplete(context, ref, task),
            backgroundColor: tokens.success,
            foregroundColor: scheme.surface,
            icon: task.isCompleted ? Icons.undo : Icons.check,
            label: task.isCompleted ? l.tileReopen : l.tileComplete,
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.55,
        children: [
          SlidableAction(
            onPressed: (_) => showPostponeSheet(context, ref, [task]),
            backgroundColor: scheme.secondaryContainer,
            foregroundColor: scheme.onSecondaryContainer,
            icon: Icons.schedule_send_outlined,
            label: l.postponeTitle,
          ),
          SlidableAction(
            onPressed: (_) => TaskQuickActions.pickPriority(context, ref, task),
            backgroundColor: scheme.tertiaryContainer,
            foregroundColor: scheme.onTertiaryContainer,
            icon: Icons.flag_outlined,
            label: l.bulkPriority,
          ),
        ],
      ),
      child: child,
    );
  }
}
