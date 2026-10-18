import '../../core/api/patch.dart' show Patch, putPatch;
import '../../core/ids.dart';
import '../../core/time/calendar_date.dart';
import '../domain/task.dart';

/// Partial update for `PATCH /task/:uid`.
///
/// Every field is a [Patch]: left [Patch.unset] it is not sent (the server
/// keeps it), [Patch.clear] sends `null` (the server clears it) and
/// [Patch.set] sends the value.
///
/// Tududi quirks to keep in mind:
/// * Sending `due_date` WITHOUT `due_time` drops any existing due time. To
///   move a task to another day and keep its time, patch [dueTime] too (see
///   [TaskPatch.moveTo]).
/// * `tags` replaces the whole tag set (by name); it never adds or removes
///   single tags.
/// * `name` cannot be cleared (the server answers 400).
class TaskPatch {
  const TaskPatch({
    this.name = const Patch.unset(),
    this.note = const Patch.unset(),
    this.status = const Patch.unset(),
    this.priority = const Patch.unset(),
    this.dueDate = const Patch.unset(),
    this.dueTime = const Patch.unset(),
    this.deferUntil = const Patch.unset(),
    this.reminderAt = const Patch.unset(),
    this.estimatedMinutes = const Patch.unset(),
    this.projectUid = const Patch.unset(),
    this.areaUid = const Patch.unset(),
    this.tags = const Patch.unset(),
    this.recurrenceType = const Patch.unset(),
    this.recurrenceInterval = const Patch.unset(),
    this.recurrenceEndDate = const Patch.unset(),
    this.recurrenceWeekday = const Patch.unset(),
    this.recurrenceWeekdays = const Patch.unset(),
    this.recurrenceMonthDay = const Patch.unset(),
    this.recurrenceWeekOfMonth = const Patch.unset(),
    this.completionBased = const Patch.unset(),
  });

  /// Sets the due date and, explicitly, the due time (or clears it when
  /// [time] is null), so the time is never dropped by accident.
  TaskPatch.moveTo(CalendarDate date, {LocalTime? time})
    : this(
        dueDate: Patch.set(date),
        dueTime: time == null ? const Patch.clear() : Patch.set(time),
      );

  final Patch<String> name;
  final Patch<String> note;
  final Patch<TaskStatus> status;
  final Patch<Priority> priority;
  final Patch<CalendarDate> dueDate;
  final Patch<LocalTime> dueTime;
  final Patch<DateTime> deferUntil;
  final Patch<DateTime> reminderAt;
  final Patch<int> estimatedMinutes;
  final Patch<ProjectUid> projectUid;
  final Patch<AreaUid> areaUid;

  /// Full replacement list of tag names.
  final Patch<List<String>> tags;
  final Patch<String> recurrenceType;
  final Patch<int> recurrenceInterval;
  final Patch<CalendarDate> recurrenceEndDate;
  final Patch<int> recurrenceWeekday;
  final Patch<List<int>> recurrenceWeekdays;
  final Patch<int> recurrenceMonthDay;
  final Patch<int> recurrenceWeekOfMonth;
  final Patch<bool> completionBased;

  /// True when nothing would be sent.
  bool get isEmpty => toJson().isEmpty;

  /// The request body: unset fields are omitted, cleared fields are `null`.
  Map<String, Object?> toJson() {
    final j = <String, Object?>{};
    putPatch(j, 'name', name);
    putPatch(j, 'note', note);
    putPatch(j, 'status', status, (s) => s.code);
    putPatch(j, 'priority', priority, (v) => v.code);
    putPatch(j, 'due_date', dueDate, (d) => d.toIso());
    putPatch(j, 'due_time', dueTime, (t) => t.format());
    putPatch(j, 'defer_until', deferUntil, (d) => d.toUtc().toIso8601String());
    putPatch(j, 'reminder_at', reminderAt, (d) => d.toUtc().toIso8601String());
    putPatch(j, 'estimated_minutes', estimatedMinutes);
    putPatch(j, 'project_uid', projectUid, (v) => v.value);
    putPatch(j, 'area_uid', areaUid, (v) => v.value);
    putPatch(
      j,
      'tags',
      tags,
      (names) => [
        for (final n in names) {'name': n},
      ],
    );
    putPatch(j, 'recurrence_type', recurrenceType);
    putPatch(j, 'recurrence_interval', recurrenceInterval);
    putPatch(j, 'recurrence_end_date', recurrenceEndDate, (d) => d.toIso());
    putPatch(j, 'recurrence_weekday', recurrenceWeekday);
    putPatch(j, 'recurrence_weekdays', recurrenceWeekdays);
    putPatch(j, 'recurrence_month_day', recurrenceMonthDay);
    putPatch(j, 'recurrence_week_of_month', recurrenceWeekOfMonth);
    putPatch(j, 'completion_based', completionBased);
    return j;
  }

  /// Status change only.
  factory TaskPatch.withStatus(TaskStatus s) => TaskPatch(status: Patch.set(s));
}
