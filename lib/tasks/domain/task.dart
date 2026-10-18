import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/ids.dart';
import '../../core/time/calendar_date.dart';

part 'task.freezed.dart';

/// Tududi task status. [code] is the number the server stores.
enum TaskStatus {
  notStarted(0),
  inProgress(1),
  done(2),
  archived(3),
  waiting(4),
  cancelled(5),
  planned(6),

  /// A code this client does not know (newer server). Never sent back.
  unknown(-1);

  const TaskStatus(this.code);
  final int code;

  static TaskStatus fromCode(int? code) {
    for (final s in values) {
      if (s.code == code && s != unknown) return s;
    }
    return code == null ? notStarted : unknown;
  }

  /// Done or archived: no longer actionable.
  bool get isFinished => this == done || this == archived;
}

/// Tududi task priority. Out-of-range codes fall back to [low].
enum Priority {
  low(0),
  medium(1),
  high(2);

  const Priority(this.code);
  final int code;

  static Priority fromCode(int? code) {
    for (final p in values) {
      if (p.code == code) return p;
    }
    return low;
  }
}

/// A tag as shown on a task.
@freezed
abstract class TaskTag with _$TaskTag {
  const factory TaskTag({TagUid? uid, required String name, String? color}) =
      _TaskTag;
}

/// A Tududi task as the app sees it. Built from `TaskDto` by `task_mapper`.
// Collections stay plain lists: freezed's unmodifiable wrappers generate
// `final` constructor parameters that Dart 3.13 rejects.
@Freezed(makeCollectionsUnmodifiable: false)
abstract class Task with _$Task {
  const Task._();

  const factory Task({
    required TaskUid uid,

    /// Numeric server id; only needed for `parent_task_id`.
    int? serverId,

    /// What to show: `original_name` when the server sent one, else `name`.
    required String name,
    String? note,
    @Default(TaskStatus.notStarted) TaskStatus status,
    @Default(Priority.low) Priority priority,
    CalendarDate? dueDate,
    LocalTime? dueTime,
    DateTime? deferUntil,
    DateTime? reminderAt,
    DateTime? completedAt,
    int? estimatedMinutes,
    ProjectUid? projectUid,
    String? projectName,
    AreaUid? areaUid,
    int? parentTaskId,
    TaskUid? recurringParentUid,
    int? order,
    @Default('none') String recurrenceType,
    int? recurrenceInterval,
    CalendarDate? recurrenceEndDate,
    int? recurrenceWeekday,
    List<int>? recurrenceWeekdays,
    int? recurrenceMonthDay,
    int? recurrenceWeekOfMonth,
    @Default(false) bool completionBased,
    @Default(0) int todayMoveCount,
    @Default(false) bool isBlocked,
    @Default(<TaskTag>[]) List<TaskTag> tags,
    @Default(<Task>[]) List<Task> subtasks,
    DateTime? createdAt,
    DateTime? updatedAt,

    /// Local database key (offline store). Null for tasks that did not come
    /// from the database.
    String? localId,

    /// [localId] of the parent task when this is a subtask.
    String? parentLocalId,

    /// Local edits not confirmed by the server yet.
    @Default(false) bool hasPendingSync,
  }) = _Task;

  bool get isDone => status == TaskStatus.done;

  /// Done or archived.
  bool get isCompleted => status.isFinished;

  bool get isRecurring => recurrenceType.isNotEmpty && recurrenceType != 'none';

  bool get hasSubtasks => subtasks.isNotEmpty;

  /// Past its due date and still actionable.
  bool isOverdue(CalendarDate today) =>
      dueDate != null &&
      dueDate!.isBefore(today) &&
      !isCompleted &&
      status != TaskStatus.cancelled;
}
