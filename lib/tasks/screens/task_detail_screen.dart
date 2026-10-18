import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../areas/providers/area_provider.dart';
import '../../common/undo/undo_controller.dart';
import '../../common/widgets/surface_card.dart';
import '../../core/design/tokens.dart';
import '../../core/ids.dart';
import '../../core/time/calendar_date.dart';
import '../../core/time/date_formatters.dart';
import '../../l10n/l10n_ext.dart';
import '../domain/recurrence/describe.dart';
import '../domain/task.dart';
import '../domain/task_labels.dart';
import '../providers/task_provider.dart';
import '../quick_add/recurrence_text.dart';
import '../widgets/api_error_message.dart';
import '../widgets/postpone_sheet.dart';
import '../widgets/recurrence_editor_sheet.dart';
import '../widgets/subtask_list.dart';
import '../widgets/task_field_chips.dart';

enum _Menu { toggle, postpone, skip, delete }

/// Number of upcoming dates listed for a repeating task.
const int _upcomingCount = 3;

/// Task detail: title with a complete toggle, status, dates, project, area,
/// tags, repeat, Markdown note and subtasks.
class TaskDetailScreen extends ConsumerWidget {
  /// The task's uid (the route's `:id`).
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = TaskUid(taskId);
    final taskAsync = ref.watch(taskDetailProvider(uid));
    final l = context.l10n;

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
              Text(apiErrorMessage(l, e), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(taskDetailProvider(uid)),
                child: Text(l.taskRetry),
              ),
            ],
          ),
        ),
      ),
      data: (task) => _DetailBody(task: task, routeId: taskId),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.task, required this.routeId});

  final Task task;
  final String routeId;

  void _error(BuildContext context, Object error) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(apiErrorMessage(context.l10n, error))));

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final r = await ref.read(taskActionsProvider).toggleComplete(task);
    if (!context.mounted) return;
    if (!r.ok) return _error(context, r.error!);
    final l = context.l10n;
    ref
        .read(undoControllerProvider)
        .show(
          context,
          task.isCompleted ? l.undoUpdated(1) : l.undoCompleted(1),
          r.undo,
        );
  }

  Future<void> _skip(BuildContext context, WidgetRef ref) async {
    final r = await ref.read(taskActionsProvider).skipOccurrence(task.uid);
    if (!context.mounted) return;
    if (!r.ok) return _error(context, r.error!);
    ref
        .read(undoControllerProvider)
        .show(context, context.l10n.taskEditSkipped, r.undo);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.taskDetailDeleteTitle),
        content: Text(l.taskDetailDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.taskCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.taskDelete),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final r = await ref.read(taskActionsProvider).delete(task.uid);
    if (!context.mounted) return;
    if (!r.ok) return _error(context, r.error!);
    ref
        .read(undoControllerProvider)
        .show(context, context.l10n.undoDeleted(1), r.undo);
    popScreen(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final f = DateFormats(Localizations.localeOf(context));
    final today = ref.watch(taskDayProvider).date;
    final areas = ref.watch(areaListProvider).value ?? const [];
    final areaName = task.areaUid == null
        ? null
        : areas.where((a) => a.uid == task.areaUid).firstOrNull?.name;
    final rule = ruleFromTask(task);
    final overdue = task.isOverdue(today);

    final hasNote = task.note != null && task.note!.trim().isNotEmpty;
    final dueLabel = task.dueDate == null
        ? null
        : task.dueTime == null
        ? f.fullDate(task.dueDate!)
        : '${f.fullDate(task.dueDate!)}, ${f.time(task.dueTime!)}';

    final rows = <Widget>[
      if (dueLabel != null)
        TaskFieldRow(
          key: const Key('detailDue'),
          icon: Icons.calendar_today_outlined,
          label: l.taskFormDueDate,
          value: dueLabel,
          color: overdue ? t.overdue : null,
        ),
      if (task.deferUntil != null)
        TaskFieldRow(
          key: const Key('detailDefer'),
          icon: Icons.schedule_outlined,
          label: l.taskFormDeferUntil,
          value: f.fullDate(
            CalendarDate.fromDateTime(task.deferUntil!.toLocal()),
          ),
        ),
      if (task.reminderAt != null)
        TaskFieldRow(
          key: const Key('detailReminder'),
          icon: Icons.notifications_none_rounded,
          label: l.taskEditReminder,
          value: f.dateTime(task.reminderAt!.toLocal()),
        ),
      if (task.estimatedMinutes != null)
        TaskFieldRow(
          key: const Key('detailEstimate'),
          icon: Icons.timer_outlined,
          label: l.taskEditEstimate,
          value: formatEstimate(l, task.estimatedMinutes!),
        ),
      if (task.projectName != null)
        TaskFieldRow(
          key: const Key('detailProject'),
          icon: Icons.folder_outlined,
          label: l.taskDetailProject,
          value: task.projectName!,
        ),
      if (areaName != null)
        TaskFieldRow(
          key: const Key('detailArea'),
          icon: Icons.layers_outlined,
          label: l.taskEditArea,
          value: areaName,
        ),
      if (task.tags.isNotEmpty)
        TaskFieldRow(
          key: const Key('detailTags'),
          icon: Icons.sell_outlined,
          label: l.taskEditTags,
          child: Padding(
            padding: EdgeInsets.only(top: t.space1),
            child: Wrap(
              spacing: t.space2,
              runSpacing: t.space1,
              children: [
                for (final tag in task.tags)
                  Chip(
                    label: Text(tag.name),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ),
        ),
      if (task.completedAt != null)
        TaskFieldRow(
          key: const Key('detailCompleted'),
          icon: Icons.check_circle_outline,
          label: l.taskDetailCompleted,
          value: f.dateTime(task.completedAt!.toLocal()),
        ),
    ];

    final upcoming = rule.isRecurring
        ? previewOccurrences(rule, task.dueDate ?? today, _upcomingCount + 1)
              .where((d) => task.dueDate == null || d.isAfter(task.dueDate!))
              .take(_upcomingCount)
              .toList()
        : const <CalendarDate>[];

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            key: const Key('detailEdit'),
            icon: const Icon(Icons.edit_outlined),
            tooltip: l.taskDetailEditTooltip,
            onPressed: () =>
                GoRouter.maybeOf(context)?.push('/tasks/$routeId/edit'),
          ),
          PopupMenuButton<_Menu>(
            key: const Key('detailMenu'),
            tooltip: l.taskDetailMenuTooltip,
            onSelected: (action) => switch (action) {
              _Menu.toggle => _toggle(context, ref),
              _Menu.postpone => showPostponeSheet(context, ref, [task]),
              _Menu.skip => _skip(context, ref),
              _Menu.delete => _delete(context, ref),
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _Menu.toggle,
                child: Text(
                  task.isCompleted
                      ? l.taskDetailMarkIncomplete
                      : l.taskDetailMarkComplete,
                ),
              ),
              if (!task.isCompleted)
                PopupMenuItem(
                  key: const Key('detailMenuPostpone'),
                  value: _Menu.postpone,
                  child: Text(l.postponeTitle),
                ),
              if (task.isRecurring && !task.isCompleted)
                PopupMenuItem(
                  key: const Key('detailMenuSkip'),
                  value: _Menu.skip,
                  child: Text(l.taskEditSkipOccurrence),
                ),
              PopupMenuItem(
                value: _Menu.delete,
                child: Text(
                  l.taskDelete,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: EdgeInsets.all(t.space4),
            children: [
              SurfaceCard(
                padding: EdgeInsets.all(t.space4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          key: const Key('detailToggle'),
                          value: task.isCompleted,
                          onChanged: (_) => _toggle(context, ref),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(top: t.space2),
                            child: Text(
                              task.name,
                              key: const Key('detailTitle'),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                decoration: task.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: t.space3),
                    Wrap(
                      spacing: t.space2,
                      runSpacing: t.space2,
                      children: [
                        TaskInfoChip(
                          key: const Key('detailStatus'),
                          icon: task.isCompleted
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          label: taskStatusLabel(l, task.status),
                          color: taskStatusColor(t, task.status),
                        ),
                        TaskInfoChip(
                          key: const Key('detailPriority'),
                          icon: Icons.flag_rounded,
                          label: taskPriorityLabel(l, task.priority),
                          color: taskPriorityColor(t, task.priority),
                        ),
                        if (task.hasPendingSync)
                          TaskInfoChip(
                            icon: Icons.sync,
                            label: l.taskEditPendingSync,
                            color: t.info,
                          ),
                      ],
                    ),
                    if (rows.isNotEmpty) ...[
                      SizedBox(height: t.space2),
                      ...rows,
                    ],
                  ],
                ),
              ),
              if (rule.isRecurring) ...[
                SizedBox(height: t.space3),
                SurfaceCard(
                  padding: EdgeInsets.all(t.space4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.repeat_rounded, color: t.info),
                          SizedBox(width: t.space2),
                          Expanded(
                            child: Text(
                              recurrenceSummary(l, f, rule),
                              key: const Key('detailRecurrence'),
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                        ],
                      ),
                      if (upcoming.isNotEmpty) ...[
                        SizedBox(height: t.space2),
                        Text(
                          l.taskEditNextOccurrences,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Column(
                          key: const Key('detailUpcoming'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final d in upcoming) Text(f.fullDate(d)),
                          ],
                        ),
                      ],
                      if (!task.isCompleted) ...[
                        SizedBox(height: t.space2),
                        Wrap(
                          spacing: t.space2,
                          children: [
                            OutlinedButton.icon(
                              key: const Key('detailSkip'),
                              icon: const Icon(Icons.skip_next_outlined),
                              label: Text(l.taskEditSkipOccurrence),
                              onPressed: () => _skip(context, ref),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (hasNote) ...[
                SizedBox(height: t.space3),
                SurfaceCard(
                  padding: EdgeInsets.all(t.space4),
                  child: MarkdownBody(
                    key: const Key('detailNote'),
                    data: task.note!,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet.fromTheme(theme)
                        .copyWith(p: theme.textTheme.bodyMedium),
                  ),
                ),
              ],
              SizedBox(height: t.space3),
              SurfaceCard(
                padding: EdgeInsets.all(t.space4),
                child: SubtaskList(parent: task),
              ),
              SizedBox(height: t.space8),
            ],
          ),
        ),
      ),
    );
  }
}
