import '../domain/new_task.dart';

/// Body of `POST /task`. Only fields that have a value are sent.
class TaskCreate {
  const TaskCreate(this.task);

  final NewTask task;

  Map<String, Object?> toJson() {
    final t = task;
    return {
      'name': t.name.trim(),
      if (t.note != null) 'note': t.note,
      if (t.status != null) 'status': t.status!.code,
      if (t.priority != null) 'priority': t.priority!.code,
      if (t.dueDate != null) 'due_date': t.dueDate!.toIso(),
      if (t.dueTime != null) 'due_time': t.dueTime!.format(),
      if (t.deferUntil != null)
        'defer_until': t.deferUntil!.toUtc().toIso8601String(),
      if (t.reminderAt != null)
        'reminder_at': t.reminderAt!.toUtc().toIso8601String(),
      if (t.estimatedMinutes != null) 'estimated_minutes': t.estimatedMinutes,
      if (t.projectUid != null) 'project_uid': t.projectUid!.value,
      if (t.areaUid != null) 'area_uid': t.areaUid!.value,
      if (t.tags.isNotEmpty)
        'tags': [
          for (final n in t.tags) {'name': n},
        ],
      if (t.parentTaskId != null) 'parent_task_id': t.parentTaskId,
      if (t.recurrenceType != null) 'recurrence_type': t.recurrenceType,
      if (t.recurrenceInterval != null)
        'recurrence_interval': t.recurrenceInterval,
      if (t.recurrenceEndDate != null)
        'recurrence_end_date': t.recurrenceEndDate!.toIso(),
      if (t.recurrenceWeekday != null)
        'recurrence_weekday': t.recurrenceWeekday,
      if (t.recurrenceWeekdays != null)
        'recurrence_weekdays': t.recurrenceWeekdays,
      if (t.recurrenceMonthDay != null)
        'recurrence_month_day': t.recurrenceMonthDay,
      if (t.recurrenceWeekOfMonth != null)
        'recurrence_week_of_month': t.recurrenceWeekOfMonth,
      if (t.completionBased != null) 'completion_based': t.completionBased,
    };
  }
}
