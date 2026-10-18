import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/undo/undo_controller.dart';
import '../../core/design/tokens.dart';
import '../../l10n/l10n_ext.dart';
import '../domain/task.dart';
import '../providers/task_provider.dart';
import 'api_error_message.dart';

String _idOf(Task t) => t.localId ?? t.uid.value;

/// The subtasks of [parent]: add inline, complete with a checkbox, delete and
/// reorder by dragging.
///
/// Everything goes through `taskActionsProvider`, so it works while the
/// parent is still waiting to sync. The data layer has no way to persist a
/// subtask order (the parent's `subtasks[]` is read-only for the app), so a
/// reorder only lasts while this widget is mounted.
class SubtaskList extends ConsumerStatefulWidget {
  const SubtaskList({super.key, required this.parent});

  final Task parent;

  @override
  ConsumerState<SubtaskList> createState() => _SubtaskListState();
}

class _SubtaskListState extends ConsumerState<SubtaskList> {
  final _controller = TextEditingController();

  /// Local display order (ids). Subtasks not listed keep their natural order
  /// after the listed ones.
  List<String> _order = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Task> _ordered() {
    final subs = widget.parent.subtasks;
    final rank = {for (var i = 0; i < _order.length; i++) _order[i]: i};
    final indexed = [for (var i = 0; i < subs.length; i++) (i, subs[i])];
    indexed.sort((a, b) {
      final ra = rank[_idOf(a.$2)] ?? _order.length + a.$1;
      final rb = rank[_idOf(b.$2)] ?? _order.length + b.$1;
      return ra.compareTo(rb);
    });
    return [for (final e in indexed) e.$2];
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(apiErrorMessage(context.l10n, error))),
    );
  }

  Future<void> _add() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    _controller.clear();
    final r = await ref
        .read(taskActionsProvider)
        .createSubtask(widget.parent, name);
    if (!r.ok) _showError(r.error!);
  }

  Future<void> _toggle(Task sub) async {
    final r = await ref.read(taskActionsProvider).toggleComplete(sub);
    if (!mounted) return;
    if (!r.ok) return _showError(r.error!);
    final l = context.l10n;
    ref
        .read(undoControllerProvider)
        .show(
          context,
          sub.isCompleted ? l.undoUpdated(1) : l.undoCompleted(1),
          r.undo,
        );
  }

  Future<void> _delete(Task sub) async {
    final r = await ref.read(taskActionsProvider).delete(sub.uid);
    if (!mounted) return;
    if (!r.ok) return _showError(r.error!);
    ref
        .read(undoControllerProvider)
        .show(context, context.l10n.undoDeleted(1), r.undo);
  }

  void _reorder(int from, int to) {
    final list = _ordered();
    final moved = list.removeAt(from);
    list.insert(to, moved);
    setState(() => _order = [for (final t in list) _idOf(t)]);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final subs = _ordered();
    final done = subs.where((s) => s.isCompleted).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.taskDetailSubtasks,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (subs.isNotEmpty)
              Text(
                l.taskEditSubtaskProgress(done, subs.length),
                key: const Key('subtaskProgress'),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        if (subs.isNotEmpty)
          ReorderableListView(
            key: const Key('subtaskReorderList'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: _reorder,
            children: [
              for (var i = 0; i < subs.length; i++) _row(context, subs[i], i),
            ],
          ),
        SizedBox(height: t.space2),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('subtaskAddField'),
                controller: _controller,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: l.taskEditSubtaskHint,
                  prefixIcon: const Icon(Icons.add),
                ),
                onSubmitted: (_) => _add(),
              ),
            ),
            IconButton(
              key: const Key('subtaskAddButton'),
              tooltip: l.taskEditSubtaskAdd,
              icon: const Icon(Icons.check),
              onPressed: _add,
            ),
          ],
        ),
      ],
    );
  }

  Widget _row(BuildContext context, Task sub, int index) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Row(
      key: ValueKey(_idOf(sub)),
      children: [
        Checkbox(
          key: Key('subtaskCheck-${sub.name}'),
          value: sub.isCompleted,
          onChanged: (_) => _toggle(sub),
        ),
        Expanded(
          child: Text(
            sub.name,
            style: theme.textTheme.bodyLarge?.copyWith(
              decoration: sub.isCompleted ? TextDecoration.lineThrough : null,
              color: sub.isCompleted ? theme.colorScheme.outline : null,
            ),
          ),
        ),
        IconButton(
          key: Key('subtaskDelete-${sub.name}'),
          tooltip: l.taskEditSubtaskDelete,
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _delete(sub),
        ),
        ReorderableDragStartListener(
          index: index,
          child: Tooltip(
            message: l.taskEditSubtaskReorder,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.drag_handle),
            ),
          ),
        ),
      ],
    );
  }
}
