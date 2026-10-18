import '../../core/ids.dart';
import '../data/dto/task_dto.dart';
import 'task.dart';

/// DTO to domain.
Task taskFromDto(TaskDto d) => Task(
  uid: TaskUid(d.uid ?? d.id?.toString() ?? ''),
  serverId: d.id,
  name: d.displayName,
  note: d.note,
  status: TaskStatus.fromCode(d.status),
  priority: Priority.fromCode(d.priority),
  dueDate: d.dueDate,
  dueTime: d.dueTime,
  deferUntil: d.deferUntil,
  reminderAt: d.reminderAt,
  completedAt: d.completedAt,
  estimatedMinutes: d.estimatedMinutes,
  projectUid: d.projectUid == null ? null : ProjectUid(d.projectUid!),
  projectName: d.projectName,
  areaUid: d.areaUid == null ? null : AreaUid(d.areaUid!),
  parentTaskId: d.parentTaskId,
  recurringParentUid: d.recurringParentUid == null
      ? null
      : TaskUid(d.recurringParentUid!),
  order: d.order,
  recurrenceType: d.recurrenceType ?? 'none',
  recurrenceInterval: d.recurrenceInterval,
  recurrenceEndDate: d.recurrenceEndDate,
  recurrenceWeekday: d.recurrenceWeekday,
  recurrenceWeekdays: d.recurrenceWeekdays,
  recurrenceMonthDay: d.recurrenceMonthDay,
  recurrenceWeekOfMonth: d.recurrenceWeekOfMonth,
  completionBased: d.completionBased ?? false,
  todayMoveCount: d.todayMoveCount ?? 0,
  isBlocked: d.isBlocked ?? false,
  tags: [
    for (final t in d.tags)
      if (t.name.isNotEmpty)
        TaskTag(
          uid: t.uid == null ? null : TagUid(t.uid!),
          name: t.name,
          color: t.color,
        ),
  ],
  subtasks: [for (final s in d.subtasks) taskFromDto(s)],
  createdAt: d.createdAt,
  updatedAt: d.updatedAt,
);

/// Domain to DTO (e.g. for caches and tests). `name` and `original_name` both
/// carry the display name.
TaskDto taskToDto(Task t) => TaskDto(
  id: t.serverId,
  uid: t.uid.value,
  name: t.name,
  originalName: t.name,
  note: t.note,
  status: t.status == TaskStatus.unknown ? null : t.status.code,
  priority: t.priority.code,
  dueDate: t.dueDate,
  dueTime: t.dueTime,
  deferUntil: t.deferUntil,
  reminderAt: t.reminderAt,
  completedAt: t.completedAt,
  estimatedMinutes: t.estimatedMinutes,
  projectUid: t.projectUid?.value,
  projectName: t.projectName,
  areaUid: t.areaUid?.value,
  parentTaskId: t.parentTaskId,
  recurringParentUid: t.recurringParentUid?.value,
  order: t.order,
  recurrenceType: t.recurrenceType,
  recurrenceInterval: t.recurrenceInterval,
  recurrenceEndDate: t.recurrenceEndDate,
  recurrenceWeekday: t.recurrenceWeekday,
  recurrenceWeekdays: t.recurrenceWeekdays,
  recurrenceMonthDay: t.recurrenceMonthDay,
  recurrenceWeekOfMonth: t.recurrenceWeekOfMonth,
  completionBased: t.completionBased,
  todayMoveCount: t.todayMoveCount,
  isBlocked: t.isBlocked,
  tags: [
    for (final g in t.tags)
      TagDto(uid: g.uid?.value, name: g.name, color: g.color),
  ],
  subtasks: [for (final s in t.subtasks) taskToDto(s)],
  createdAt: t.createdAt,
  updatedAt: t.updatedAt,
);
