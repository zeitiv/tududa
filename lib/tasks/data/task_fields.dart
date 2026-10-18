import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';
import '../../core/time/calendar_date.dart';
import 'dto/task_dto.dart';

/// Names of the task fields that are tracked per field: they are the keys of
/// `dirty_fields`, of `base_json` and of the maps handed to `mergeFields`.
/// They are also the wire names of the `PATCH /task/:uid` body.
abstract final class TaskField {
  static const name = 'name';
  static const note = 'note';
  static const status = 'status';
  static const priority = 'priority';
  static const dueDate = 'due_date';
  static const dueTime = 'due_time';
  static const deferUntil = 'defer_until';
  static const reminderAt = 'reminder_at';

  /// Set by the server when the status becomes done; never sent. Marked dirty
  /// next to `status` so a local completion merges as one edit.
  static const completedAt = 'completed_at';
  static const estimatedMinutes = 'estimated_minutes';
  static const projectUid = 'project_uid';
  static const areaUid = 'area_uid';
  static const tags = 'tags';
  static const recurrenceType = 'recurrence_type';
  static const recurrenceInterval = 'recurrence_interval';
  static const recurrenceEndDate = 'recurrence_end_date';
  static const recurrenceWeekday = 'recurrence_weekday';
  static const recurrenceWeekdays = 'recurrence_weekdays';
  static const recurrenceMonthDay = 'recurrence_month_day';
  static const recurrenceWeekOfMonth = 'recurrence_week_of_month';
  static const completionBased = 'completion_based';

  /// Every tracked field.
  static const all = [
    name,
    note,
    status,
    priority,
    dueDate,
    dueTime,
    deferUntil,
    reminderAt,
    completedAt,
    estimatedMinutes,
    projectUid,
    areaUid,
    tags,
    recurrenceType,
    recurrenceInterval,
    recurrenceEndDate,
    recurrenceWeekday,
    recurrenceWeekdays,
    recurrenceMonthDay,
    recurrenceWeekOfMonth,
    completionBased,
  ];

  /// Fields that are never part of a request body.
  static const readOnly = {completedAt};
}

/// An instant as it is stored and compared: UTC ISO text truncated to whole
/// seconds (drift stores `DateTime` columns with second precision).
String? isoSeconds(DateTime? d) {
  if (d == null) return null;
  final ms = d.toUtc().millisecondsSinceEpoch;
  return DateTime.fromMillisecondsSinceEpoch(
    ms - ms % 1000,
    isUtc: true,
  ).toIso8601String();
}

DateTime? _dt(Object? iso) => iso is String ? DateTime.tryParse(iso) : null;

/// The tracked fields of a row as a JSON-compatible map (what `mergeFields`
/// and `base_json` work with). References are server uids; a project / area
/// that was created offline has no uid yet and shows up as `local:<id>`.
Map<String, dynamic> taskFieldMap(
  TaskRow r, {
  String? projectUid,
  String? areaUid,
  List<String> tags = const [],
}) => {
  TaskField.name: r.name,
  TaskField.note: r.note,
  TaskField.status: r.status,
  TaskField.priority: r.priority,
  TaskField.dueDate: r.dueDate,
  TaskField.dueTime: r.dueTime,
  TaskField.deferUntil: isoSeconds(r.deferUntil),
  TaskField.reminderAt: isoSeconds(r.reminderAt),
  TaskField.completedAt: isoSeconds(r.completedAt),
  TaskField.estimatedMinutes: r.estimatedMinutes,
  TaskField.projectUid: projectUid,
  TaskField.areaUid: areaUid,
  TaskField.tags: ([...tags]..sort()),
  TaskField.recurrenceType: r.recurrenceType ?? 'none',
  TaskField.recurrenceInterval: r.recurrenceInterval,
  TaskField.recurrenceEndDate: r.recurrenceEndDate,
  TaskField.recurrenceWeekday: r.recurrenceWeekday,
  TaskField.recurrenceWeekdays: decodeIntList(r.recurrenceWeekdays),
  TaskField.recurrenceMonthDay: r.recurrenceMonthDay,
  TaskField.recurrenceWeekOfMonth: r.recurrenceWeekOfMonth,
  TaskField.completionBased: r.completionBased,
};

/// The same map for a task as the server sent it.
Map<String, dynamic> taskFieldMapFromDto(TaskDto d) => {
  TaskField.name: d.displayName,
  TaskField.note: d.note,
  TaskField.status: d.status ?? 0,
  TaskField.priority: d.priority ?? 0,
  TaskField.dueDate: d.dueDate?.toIso(),
  TaskField.dueTime: d.dueTime?.format(),
  TaskField.deferUntil: isoSeconds(d.deferUntil),
  TaskField.reminderAt: isoSeconds(d.reminderAt),
  TaskField.completedAt: isoSeconds(d.completedAt),
  TaskField.estimatedMinutes: d.estimatedMinutes,
  TaskField.projectUid: d.projectUid,
  TaskField.areaUid: d.areaUid,
  TaskField.tags: <String>[
    for (final t in d.tags)
      if (t.name.isNotEmpty) t.name,
  ]..sort(),
  TaskField.recurrenceType: d.recurrenceType ?? 'none',
  TaskField.recurrenceInterval: d.recurrenceInterval,
  TaskField.recurrenceEndDate: d.recurrenceEndDate?.toIso(),
  TaskField.recurrenceWeekday: d.recurrenceWeekday,
  TaskField.recurrenceWeekdays: d.recurrenceWeekdays,
  TaskField.recurrenceMonthDay: d.recurrenceMonthDay,
  TaskField.recurrenceWeekOfMonth: d.recurrenceWeekOfMonth,
  TaskField.completionBased: d.completionBased ?? false,
};

/// Column values for a field map (everything except the references, which
/// need local ids: pass [projectLocalId] / [areaLocalId]). Fields missing from
/// [m] are left alone.
TasksCompanion companionFromFieldMap(
  Map<String, dynamic> m, {
  String? projectLocalId,
  String? areaLocalId,
}) {
  Value<T?> v<T>(String key, T? value) =>
      m.containsKey(key) ? Value<T?>(value) : const Value.absent();
  final weekdays = m[TaskField.recurrenceWeekdays];
  return TasksCompanion(
    name: m.containsKey(TaskField.name)
        ? Value(m[TaskField.name] as String? ?? '')
        : const Value.absent(),
    note: v(TaskField.note, m[TaskField.note] as String?),
    status: m.containsKey(TaskField.status)
        ? Value(m[TaskField.status] as int? ?? 0)
        : const Value.absent(),
    priority: m.containsKey(TaskField.priority)
        ? Value(m[TaskField.priority] as int? ?? 0)
        : const Value.absent(),
    dueDate: v(TaskField.dueDate, m[TaskField.dueDate] as String?),
    dueTime: v(TaskField.dueTime, m[TaskField.dueTime] as String?),
    deferUntil: v(TaskField.deferUntil, _dt(m[TaskField.deferUntil])),
    reminderAt: v(TaskField.reminderAt, _dt(m[TaskField.reminderAt])),
    completedAt: v(TaskField.completedAt, _dt(m[TaskField.completedAt])),
    estimatedMinutes: v(
      TaskField.estimatedMinutes,
      m[TaskField.estimatedMinutes] as int?,
    ),
    projectLocalId: m.containsKey(TaskField.projectUid)
        ? Value(projectLocalId)
        : const Value.absent(),
    areaLocalId: m.containsKey(TaskField.areaUid)
        ? Value(areaLocalId)
        : const Value.absent(),
    recurrenceType: v(
      TaskField.recurrenceType,
      m[TaskField.recurrenceType] as String?,
    ),
    recurrenceInterval: v(
      TaskField.recurrenceInterval,
      m[TaskField.recurrenceInterval] as int?,
    ),
    recurrenceEndDate: v(
      TaskField.recurrenceEndDate,
      m[TaskField.recurrenceEndDate] as String?,
    ),
    recurrenceWeekday: v(
      TaskField.recurrenceWeekday,
      m[TaskField.recurrenceWeekday] as int?,
    ),
    recurrenceWeekdays: m.containsKey(TaskField.recurrenceWeekdays)
        ? Value(weekdays is List ? jsonEncode(weekdays) : null)
        : const Value.absent(),
    recurrenceMonthDay: v(
      TaskField.recurrenceMonthDay,
      m[TaskField.recurrenceMonthDay] as int?,
    ),
    recurrenceWeekOfMonth: v(
      TaskField.recurrenceWeekOfMonth,
      m[TaskField.recurrenceWeekOfMonth] as int?,
    ),
    completionBased: m.containsKey(TaskField.completionBased)
        ? Value(m[TaskField.completionBased] == true)
        : const Value.absent(),
  );
}

/// Copies the columns behind [fields] from [src] (references and tags are
/// handled by the caller).
TasksCompanion companionForFields(TaskRow src, Iterable<String> fields) {
  final f = fields.toSet();
  bool has(String k) => f.contains(k);
  return TasksCompanion(
    name: has(TaskField.name) ? Value(src.name) : const Value.absent(),
    note: has(TaskField.note) ? Value(src.note) : const Value.absent(),
    status: has(TaskField.status) ? Value(src.status) : const Value.absent(),
    priority: has(TaskField.priority)
        ? Value(src.priority)
        : const Value.absent(),
    dueDate: has(TaskField.dueDate) ? Value(src.dueDate) : const Value.absent(),
    dueTime: has(TaskField.dueTime) ? Value(src.dueTime) : const Value.absent(),
    deferUntil: has(TaskField.deferUntil)
        ? Value(src.deferUntil)
        : const Value.absent(),
    reminderAt: has(TaskField.reminderAt)
        ? Value(src.reminderAt)
        : const Value.absent(),
    completedAt: has(TaskField.completedAt)
        ? Value(src.completedAt)
        : const Value.absent(),
    estimatedMinutes: has(TaskField.estimatedMinutes)
        ? Value(src.estimatedMinutes)
        : const Value.absent(),
    projectLocalId: has(TaskField.projectUid)
        ? Value(src.projectLocalId)
        : const Value.absent(),
    areaLocalId: has(TaskField.areaUid)
        ? Value(src.areaLocalId)
        : const Value.absent(),
    recurrenceType: has(TaskField.recurrenceType)
        ? Value(src.recurrenceType)
        : const Value.absent(),
    recurrenceInterval: has(TaskField.recurrenceInterval)
        ? Value(src.recurrenceInterval)
        : const Value.absent(),
    recurrenceEndDate: has(TaskField.recurrenceEndDate)
        ? Value(src.recurrenceEndDate)
        : const Value.absent(),
    recurrenceWeekday: has(TaskField.recurrenceWeekday)
        ? Value(src.recurrenceWeekday)
        : const Value.absent(),
    recurrenceWeekdays: has(TaskField.recurrenceWeekdays)
        ? Value(src.recurrenceWeekdays)
        : const Value.absent(),
    recurrenceMonthDay: has(TaskField.recurrenceMonthDay)
        ? Value(src.recurrenceMonthDay)
        : const Value.absent(),
    recurrenceWeekOfMonth: has(TaskField.recurrenceWeekOfMonth)
        ? Value(src.recurrenceWeekOfMonth)
        : const Value.absent(),
    completionBased: has(TaskField.completionBased)
        ? Value(src.completionBased)
        : const Value.absent(),
  );
}

/// `[1,3,5]` column text to a list; null when absent or malformed.
List<int>? decodeIntList(String? text) {
  if (text == null || text.isEmpty) return null;
  try {
    final raw = jsonDecode(text);
    if (raw is! List) return null;
    return [
      for (final e in raw)
        if (e is num) e.toInt(),
    ];
  } on FormatException {
    return null;
  }
}

/// A due date column value to a [CalendarDate].
CalendarDate? parseDate(String? iso) => CalendarDate.tryParse(iso);
