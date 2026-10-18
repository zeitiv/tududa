import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/time/calendar_date.dart';
import 'json_converters.dart';

part 'task_dto.freezed.dart';
part 'task_dto.g.dart';

/// A tag embedded in a task: `{id?, uid?, name, color?}`.
@freezed
abstract class TagDto with _$TagDto {
  const factory TagDto({
    int? id,
    String? uid,
    @Default('') String name,
    String? color,
  }) = _TagDto;

  factory TagDto.fromJson(Map<String, dynamic> json) => _$TagDtoFromJson(json);
}

/// The task as Tududi v1.9.x sends it. Lenient on purpose: unknown keys are
/// ignored, nulls are tolerated, `status` / `priority` may be numbers or
/// names, and a few legacy keys are read in camelCase or PascalCase too
/// (`dueDate`, `completedAt`, `Subtasks`, `Tags`, `Project`).
// Collections stay plain lists: freezed's unmodifiable wrappers generate
// `final` constructor parameters that Dart 3.13 rejects.
@Freezed(makeCollectionsUnmodifiable: false)
abstract class TaskDto with _$TaskDto {
  const TaskDto._();

  const factory TaskDto({
    int? id,
    String? uid,
    @Default('') String name,

    /// The name to show. For recurring templates the server rewrites `name`.
    String? originalName,
    String? note,
    @StatusCodeConverter() int? status,
    @PriorityCodeConverter() int? priority,
    @NullableCalendarDateConverter() CalendarDate? dueDate,
    @NullableLocalTimeConverter() LocalTime? dueTime,
    @LenientDateTimeConverter() DateTime? deferUntil,
    @LenientDateTimeConverter() DateTime? reminderAt,
    @LenientDateTimeConverter() DateTime? completedAt,
    int? estimatedMinutes,
    String? projectUid,
    String? projectName,
    String? areaUid,
    int? parentTaskId,
    String? recurringParentUid,
    int? order,
    String? recurrenceType,
    int? recurrenceInterval,
    @NullableCalendarDateConverter() CalendarDate? recurrenceEndDate,
    int? recurrenceWeekday,
    @IntListConverter() List<int>? recurrenceWeekdays,
    int? recurrenceMonthDay,
    int? recurrenceWeekOfMonth,
    bool? completionBased,
    int? todayMoveCount,
    bool? isBlocked,
    @Default(<TagDto>[]) List<TagDto> tags,
    @Default(<TaskDto>[]) List<TaskDto> subtasks,
    @LenientDateTimeConverter() DateTime? createdAt,
    @LenientDateTimeConverter() DateTime? updatedAt,
  }) = _TaskDto;

  /// Plain generated decoding; prefer [TaskDto.parse], which also accepts
  /// the legacy key spellings.
  factory TaskDto.fromJson(Map<String, dynamic> json) =>
      _$TaskDtoFromJson(json);

  /// Parses one task from a server response, tolerating the legacy key
  /// spellings (see the class docs). Throws [FormatException] when the shape
  /// is unusable (so `guard()` reports a `DecodingError`).
  static TaskDto parse(Map<String, dynamic> json) {
    try {
      return _$TaskDtoFromJson(_normalize(json));
    } on CheckedFromJsonException catch (e) {
      throw FormatException(e.message ?? 'Invalid task', json);
    }
  }

  /// `original_name` when present, else `name`.
  String get displayName =>
      (originalName != null && originalName!.isNotEmpty) ? originalName! : name;

  static Map<String, dynamic> _normalize(Map<String, dynamic> raw) {
    final j = Map<String, dynamic>.of(raw);

    void alias(String camel, String snake) {
      if (j[snake] == null && j.containsKey(camel)) j[snake] = j[camel];
    }

    alias('dueDate', 'due_date');
    alias('dueTime', 'due_time');
    alias('completedAt', 'completed_at');
    alias('deferUntil', 'defer_until');
    alias('reminderAt', 'reminder_at');
    alias('createdAt', 'created_at');
    alias('updatedAt', 'updated_at');
    alias('originalName', 'original_name');
    alias('projectUid', 'project_uid');
    alias('Subtasks', 'subtasks');
    alias('Tags', 'tags');

    // Tags may come as bare names.
    final tags = j['tags'];
    if (tags is List) {
      j['tags'] = [
        for (final t in tags)
          if (t is String) {'name': t} else if (t is Map) t,
      ];
    } else {
      j.remove('tags');
    }
    final subs = j['subtasks'];
    if (subs is List) {
      j['subtasks'] = [
        for (final t in subs)
          if (t is Map) _normalize(Map<String, dynamic>.from(t)),
      ];
    } else {
      j.remove('subtasks');
    }

    // `Project: {name, uid}` (or lowercase `project`) when no flat fields.
    final project = j['Project'] ?? j['project'];
    if (project is Map) {
      j['project_uid'] ??= project['uid'];
      j['project_name'] ??= project['name'];
    }
    return j;
  }
}
