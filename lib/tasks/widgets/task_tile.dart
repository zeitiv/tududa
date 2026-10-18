import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/patch.dart' show Patch;
import '../../core/time/date_formatters.dart';
import '../../l10n/l10n_ext.dart';
import '../data/task_patch.dart';
import '../domain/task.dart';
import '../domain/task_labels.dart';
import '../providers/task_provider.dart';
import 'api_error_message.dart';
import 'postpone_sheet.dart';
import 'selection_controller.dart';
import 'swipe_task_tile.dart';
import 'task_indicators.dart';

const _previewSubtasks = 3;

enum _MenuAction {
  complete,
  edit,
  editTitle,
  postpone,
  priority,
  select,
  delete,
}

/// The one task row used by every list (Today, Upcoming, project, search...).
///
/// Self-contained: callers pass only the task. It shows the completion
/// checkbox, title (double-tap to rename in place), indicators and a subtask
/// preview; supports swipe actions, an overflow menu, multi-select (long
/// press; see `taskSelectionProvider` and `BulkActionBar`) and accessibility
/// actions. Changes show an undo snackbar.
class TaskTile extends ConsumerStatefulWidget {
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
  ConsumerState<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends ConsumerState<TaskTile> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _editing = false;

  Task get task => widget.task;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _editing) _saveTitle();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startEdit() {
    if (_editing) return;
    _controller.text = task.name;
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: task.name.length,
    );
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editing) _focus.requestFocus();
    });
  }

  void _cancelEdit() {
    if (!_editing) return;
    setState(() => _editing = false);
  }

  Future<void> _saveTitle() async {
    if (!_editing) return;
    final name = _controller.text.trim();
    setState(() => _editing = false);
    if (name.isEmpty || name == task.name) return;
    final r = await ref
        .read(taskActionsProvider)
        .update(task.uid, TaskPatch(name: Patch.set(name)));
    if (!mounted || r.ok) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(apiErrorMessage(context.l10n, r.error!))),
    );
  }

  void _open() {
    if (widget.onTap != null) {
      widget.onTap!();
    } else if (task.uid.value.isNotEmpty) {
      context.push('/tasks/${task.uid.value}');
    }
  }

  void _edit() => context.push('/tasks/${task.uid.value}/edit');

  void _onMenu(_MenuAction a) {
    switch (a) {
      case _MenuAction.complete:
        TaskQuickActions.toggleComplete(context, ref, task);
      case _MenuAction.edit:
        _edit();
      case _MenuAction.editTitle:
        _startEdit();
      case _MenuAction.postpone:
        showPostponeSheet(context, ref, [task]);
      case _MenuAction.priority:
        TaskQuickActions.pickPriority(context, ref, task);
      case _MenuAction.select:
        ref.read(taskSelectionProvider.notifier).start(task);
      case _MenuAction.delete:
        TaskQuickActions.delete(context, ref, task);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final key = TaskSelectionNotifier.keyOf(task);
    final selecting = ref.watch(
      taskSelectionProvider.select((s) => s.isNotEmpty),
    );
    final selected = ref.watch(
      taskSelectionProvider.select((s) => s.contains(key)),
    );
    final selection = ref.read(taskSelectionProvider.notifier);
    final today = ref.watch(taskDayProvider).date;
    final formats = DateFormats(Localizations.localeOf(context));
    final done = task.isCompleted;

    final dueText = taskDueText(context, task, today, formats);
    final label = [
      task.name,
      taskStatusLabel(l, task.status),
      ?(dueText == null ? null : l.tileDueOn(dueText)),
      l.tilePriorityLabel(taskPriorityLabel(l, task.priority)),
    ].join(', ');

    final titleStyle = theme.textTheme.bodyLarge?.copyWith(
      decoration: done ? TextDecoration.lineThrough : null,
      color: done ? scheme.onSurfaceVariant : scheme.onSurface,
    );

    final title = _editing
        ? Focus(
            onKeyEvent: (_, e) {
              if (e is KeyDownEvent &&
                  e.logicalKey == LogicalKeyboardKey.escape) {
                _cancelEdit();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              style: titleStyle,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saveTitle(),
              decoration: InputDecoration(
                isDense: true,
                hintText: l.tileTitleHint,
              ),
            ),
          )
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: selecting ? null : _startEdit,
            child: Text(
              task.name,
              style: titleStyle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          );

    final subtasks = task.subtasks.take(_previewSubtasks).toList();

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Checkbox(
              value: selecting ? selected : done,
              shape: selecting ? const CircleBorder() : null,
              materialTapTargetSize: MaterialTapTargetSize.padded,
              onChanged: (_) => selecting
                  ? selection.toggle(task)
                  : TaskQuickActions.toggleComplete(context, ref, task),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  TaskIndicators(
                    task: task,
                    today: today,
                    showProject: widget.showProject,
                    showDueDate: widget.showDueDate,
                  ),
                  for (final s in subtasks)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Icon(
                            s.isCompleted
                                ? Icons.check_box_outlined
                                : Icons.check_box_outline_blank,
                            size: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              s.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                decoration: s.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (!selecting)
            SizedBox(
              width: 48,
              height: 48,
              child: PopupMenuButton<_MenuAction>(
                tooltip: l.tileMenu,
                icon: const Icon(Icons.more_vert),
                onSelected: _onMenu,
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: _MenuAction.complete,
                    child: Text(done ? l.tileReopen : l.tileComplete),
                  ),
                  PopupMenuItem(
                    value: _MenuAction.edit,
                    child: Text(l.tileEdit),
                  ),
                  PopupMenuItem(
                    value: _MenuAction.editTitle,
                    child: Text(l.tileEditTitle),
                  ),
                  PopupMenuItem(
                    value: _MenuAction.postpone,
                    child: Text(l.postponeTitle),
                  ),
                  PopupMenuItem(
                    value: _MenuAction.priority,
                    child: Text(l.bulkPriority),
                  ),
                  PopupMenuItem(
                    value: _MenuAction.select,
                    child: Text(l.tileSelect),
                  ),
                  PopupMenuItem(
                    value: _MenuAction.delete,
                    child: Text(l.taskDelete),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    final body = Material(
      color: selected ? scheme.secondaryContainer : Colors.transparent,
      child: InkWell(
        onTap: _editing
            ? null
            : (selecting ? () => selection.toggle(task) : _open),
        onLongPress: _editing || selecting
            ? null
            : () {
                HapticFeedback.selectionClick();
                selection.start(task);
              },
        child: row,
      ),
    );

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: label,
      selected: selected,
      checked: done,
      onTap: selecting ? () => selection.toggle(task) : _open,
      onLongPress: () => selection.start(task),
      customSemanticsActions: {
        CustomSemanticsAction(
          label: done ? l.tileReopen : l.tileComplete,
        ): () =>
            TaskQuickActions.toggleComplete(context, ref, task),
        CustomSemanticsAction(label: l.postponeTitle): () =>
            showPostponeSheet(context, ref, [task]),
        CustomSemanticsAction(label: l.bulkPriority): () =>
            TaskQuickActions.pickPriority(context, ref, task),
        CustomSemanticsAction(label: l.taskDelete): () =>
            TaskQuickActions.delete(context, ref, task),
        CustomSemanticsAction(label: l.tileEdit): _edit,
      },
      child: SwipeTaskTile(
        task: task,
        enabled: !selecting && !_editing,
        child: body,
      ),
    );
  }
}
