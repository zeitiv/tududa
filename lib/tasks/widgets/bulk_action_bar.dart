import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/undo/undo_controller.dart';
import '../../core/api/patch.dart' show Patch;
import '../../l10n/l10n_ext.dart';
import '../../tags/providers/tag_provider.dart';
import '../data/task_patch.dart';
import '../domain/task.dart';
import '../providers/project_options_provider.dart';
import '../providers/task_provider.dart';
import 'postpone_sheet.dart';
import 'selection_controller.dart';
import 'swipe_task_tile.dart' show showPrioritySheet;

/// Bottom bar for the tasks picked in selection mode: count, clear and the
/// bulk actions. Hidden while nothing is selected, so list screens can place
/// it unconditionally (e.g. `bottomNavigationBar: const BulkActionBar()`).
class BulkActionBar extends ConsumerWidget {
  const BulkActionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(taskSelectionProvider);
    if (selected.isEmpty) return const SizedBox.shrink();
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final selection = ref.read(taskSelectionProvider.notifier);

    Widget action(IconData icon, String label, VoidCallback onTap) =>
        IconButton(
          icon: Icon(icon),
          tooltip: label,
          onPressed: onTap,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        );

    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(
            children: [
              action(Icons.close, l.bulkClear, selection.clear),
              Text(
                l.bulkSelectedCount(selected.length),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      action(
                        Icons.check_circle_outline,
                        l.bulkComplete,
                        () => _complete(context, ref),
                      ),
                      action(
                        Icons.schedule_send_outlined,
                        l.bulkPostpone,
                        () => _postpone(context, ref),
                      ),
                      action(
                        Icons.flag_outlined,
                        l.bulkPriority,
                        () => _priority(context, ref),
                      ),
                      action(
                        Icons.drive_file_move_outline,
                        l.bulkMoveProject,
                        () => _moveToProject(context, ref),
                      ),
                      action(
                        Icons.sell_outlined,
                        l.bulkTag,
                        () => _tag(context, ref),
                      ),
                      action(
                        Icons.delete_outline,
                        l.bulkDelete,
                        () => _delete(context, ref),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Task> _tasks(WidgetRef ref) =>
      ref.read(taskSelectionProvider.notifier).tasks;

  /// Shows the undo snackbar, then leaves selection mode.
  void _done(
    BuildContext context,
    WidgetRef ref,
    String message,
    List<UndoToken> tokens,
  ) {
    ref.read(undoControllerProvider).showAll(context, message, tokens);
    ref.read(taskSelectionProvider.notifier).clear();
  }

  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    final actions = ref.read(taskActionsProvider);
    final tokens = <UndoToken>[];
    final tasks = _tasks(ref);
    for (final t in tasks) {
      final r = await actions.complete(t);
      if (r.undo != null) tokens.add(r.undo!);
    }
    if (!context.mounted) return;
    _done(context, ref, context.l10n.undoCompleted(tasks.length), tokens);
  }

  Future<void> _postpone(BuildContext context, WidgetRef ref) async {
    await showPostponeSheet(context, ref, _tasks(ref));
    if (context.mounted) ref.read(taskSelectionProvider.notifier).clear();
  }

  Future<void> _priority(BuildContext context, WidgetRef ref) async {
    final p = await showPrioritySheet(context);
    if (p == null || !context.mounted) return;
    await _bulk(context, ref, TaskPatch(priority: Patch.set(p)));
  }

  Future<void> _bulk(
    BuildContext context,
    WidgetRef ref,
    TaskPatch patch,
  ) async {
    final tasks = _tasks(ref);
    final r = await ref.read(taskActionsProvider).bulk([
      for (final t in tasks) t.uid,
    ], patch);
    if (!context.mounted) return;
    _done(context, ref, context.l10n.undoUpdated(tasks.length), [?r.undo]);
  }

  Future<void> _moveToProject(BuildContext context, WidgetRef ref) async {
    final projects = ref.read(projectOptionsProvider).value ?? const [];
    final l = context.l10n;
    // A ProjectOption is wrapped so "no project" (null) differs from dismiss.
    final picked = await showModalBottomSheet<({ProjectOption? project})>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              minTileHeight: 48,
              leading: const Icon(Icons.folder_off_outlined),
              title: Text(l.bulkNoProject),
              onTap: () => Navigator.pop(ctx, (project: null)),
            ),
            for (final p in projects)
              ListTile(
                minTileHeight: 48,
                leading: const Icon(Icons.folder_outlined),
                title: Text(p.name),
                onTap: () => Navigator.pop(ctx, (project: p)),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !context.mounted) return;
    final p = picked.project;
    await _bulk(
      context,
      ref,
      TaskPatch(projectUid: p == null ? const Patch.clear() : Patch.set(p.uid)),
    );
  }

  Future<void> _tag(BuildContext context, WidgetRef ref) async {
    final tags = ref.read(tagListProvider).value ?? const [];
    final name = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final t in tags)
              ListTile(
                minTileHeight: 48,
                leading: const Icon(Icons.sell_outlined),
                title: Text(t.name),
                onTap: () => Navigator.pop(ctx, t.name),
              ),
          ],
        ),
      ),
    );
    if (name == null || !context.mounted) return;
    // `tags` replaces the whole set, so every task gets its own merged list.
    final actions = ref.read(taskActionsProvider);
    final tasks = _tasks(ref);
    final tokens = <UndoToken>[];
    for (final t in tasks) {
      final names = [for (final x in t.tags) x.name];
      if (names.contains(name)) continue;
      final r = await actions.update(
        t.uid,
        TaskPatch(tags: Patch.set([...names, name])),
      );
      if (r.undo != null) tokens.add(r.undo!);
    }
    if (!context.mounted) return;
    _done(context, ref, context.l10n.undoUpdated(tasks.length), tokens);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final actions = ref.read(taskActionsProvider);
    final tokens = <UndoToken>[];
    final tasks = _tasks(ref);
    for (final t in tasks) {
      final r = await actions.delete(t.uid);
      if (r.undo != null) tokens.add(r.undo!);
    }
    if (!context.mounted) return;
    _done(context, ref, context.l10n.undoDeleted(tasks.length), tokens);
  }
}
