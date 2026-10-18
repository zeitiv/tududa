import 'package:flutter/material.dart';

import '../../core/design/token_lookup.dart';
import '../../core/design/tokens.dart';
import '../../core/time/calendar_date.dart';
import '../../core/time/date_formatters.dart';
import '../../l10n/l10n_ext.dart';
import '../domain/task.dart';

const _maxTags = 2;

/// Due date text of [task]: "N days overdue", "Today", "Oct 14"... Null when
/// the task has no due date.
String? taskDueText(
  BuildContext context,
  Task task,
  CalendarDate today,
  DateFormats formats,
) {
  final due = task.dueDate;
  if (due == null) return null;
  final l = context.l10n;
  if (task.isOverdue(today)) return l.tileOverdueDays(due.daysUntil(today));
  return formats.relativeDay(due, today, l);
}

/// The metadata of a task row: priority, due date and time, recurrence,
/// subtask progress, note, tags, project, estimate, postponed count, blocked.
/// Every indicator pairs an icon with text or a label, never colour alone.
class TaskIndicators extends StatelessWidget {
  const TaskIndicators({
    super.key,
    required this.task,
    required this.today,
    this.showProject = true,
    this.showDueDate = true,
  });

  final Task task;
  final CalendarDate today;
  final bool showProject;
  final bool showDueDate;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tokens = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    final formats = DateFormats(Localizations.localeOf(context));
    final muted = scheme.onSurfaceVariant;

    final due = showDueDate ? taskDueText(context, task, today, formats) : null;
    final overdue = task.isOverdue(today);
    final dueColor = overdue
        ? tokens.overdue
        : task.dueDate == today
        ? tokens.today
        : muted;
    final total = task.subtasks.length;
    final done = task.subtasks.where((s) => s.isCompleted).length;
    final extraTags = task.tags.length - _maxTags;

    final items = <Widget>[
      if (task.priority != Priority.low)
        _Indicator(
          icon: Icons.flag_outlined,
          color: tokens.priorityFor(task.priority.code),
          label: switch (task.priority) {
            Priority.high => l.taskPriorityHigh,
            _ => l.taskPriorityMedium,
          },
        ),
      if (due != null)
        _Indicator(
          icon: overdue ? Icons.event_busy_outlined : Icons.event_outlined,
          color: dueColor,
          label: due,
        ),
      if (showDueDate && task.dueDate != null && task.dueTime != null)
        _Indicator(
          icon: Icons.schedule_outlined,
          color: muted,
          label: formats.time(task.dueTime!),
        ),
      if (task.isRecurring)
        _Indicator(
          icon: Icons.repeat,
          color: muted,
          semanticLabel: l.tileRepeats,
        ),
      if (total > 0)
        _Indicator(
          icon: Icons.checklist_outlined,
          color: muted,
          label: '$done/$total',
          semanticLabel: l.tileSubtasksDone(done, total),
        ),
      if (task.note != null && task.note!.trim().isNotEmpty)
        _Indicator(
          icon: Icons.notes_outlined,
          color: muted,
          semanticLabel: l.tileHasNote,
        ),
      for (final tag in task.tags.take(_maxTags))
        _Indicator(icon: Icons.sell_outlined, color: muted, label: tag.name),
      if (extraTags > 0)
        _Indicator(
          color: muted,
          label: '+$extraTags',
          semanticLabel: l.tileMoreTags(extraTags),
        ),
      if (showProject && (task.projectName ?? '').isNotEmpty)
        _Indicator(
          icon: Icons.folder_outlined,
          color: muted,
          label: task.projectName!,
        ),
      if (task.estimatedMinutes != null && task.estimatedMinutes! > 0)
        _Indicator(
          icon: Icons.timer_outlined,
          color: muted,
          label: l.tileEstimate(task.estimatedMinutes!),
        ),
      if (task.todayMoveCount > 0)
        _Indicator(
          icon: Icons.redo,
          color: tokens.warning,
          label: l.tilePostponedTimes(task.todayMoveCount),
        ),
      if (task.isBlocked)
        _Indicator(
          icon: Icons.block,
          color: tokens.warning,
          label: l.tileBlocked,
        ),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 12, runSpacing: 2, children: items);
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({
    this.icon,
    required this.color,
    this.label,
    this.semanticLabel,
  });

  final IconData? icon;
  final Color color;
  final String? label;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: color);
    final size = (style?.fontSize ?? 12) * 1.15;
    return Semantics(
      label: semanticLabel,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.6,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) Icon(icon, size: size, color: color),
            if (icon != null && label != null) const SizedBox(width: 4),
            if (label != null)
              Flexible(
                child: Text(
                  label!,
                  style: style,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
