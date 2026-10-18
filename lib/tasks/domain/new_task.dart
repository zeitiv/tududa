import '../../core/ids.dart';
import '../../core/time/calendar_date.dart';
import 'task.dart';

/// Everything needed to create a task. Unset optional fields are not sent.
class NewTask {
  const NewTask({
    required this.name,
    this.note,
    this.status,
    this.priority,
    this.dueDate,
    this.dueTime,
    this.deferUntil,
    this.reminderAt,
    this.estimatedMinutes,
    this.projectUid,
    this.areaUid,
    this.tags = const [],
    this.parentTaskId,
    this.recurrenceType,
    this.recurrenceInterval,
    this.recurrenceEndDate,
    this.recurrenceWeekday,
    this.recurrenceWeekdays,
    this.recurrenceMonthDay,
    this.recurrenceWeekOfMonth,
    this.completionBased,
  });

  final String name;
  final String? note;
  final TaskStatus? status;
  final Priority? priority;
  final CalendarDate? dueDate;
  final LocalTime? dueTime;
  final DateTime? deferUntil;
  final DateTime? reminderAt;
  final int? estimatedMinutes;
  final ProjectUid? projectUid;
  final AreaUid? areaUid;

  /// Tag names; the server creates missing tags.
  final List<String> tags;

  /// Numeric id of the parent task (subtasks).
  final int? parentTaskId;
  final String? recurrenceType;
  final int? recurrenceInterval;
  final CalendarDate? recurrenceEndDate;
  final int? recurrenceWeekday;
  final List<int>? recurrenceWeekdays;
  final int? recurrenceMonthDay;
  final int? recurrenceWeekOfMonth;
  final bool? completionBased;
}
