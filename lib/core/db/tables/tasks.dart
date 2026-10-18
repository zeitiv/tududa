import 'package:drift/drift.dart';

import 'sync_columns.dart';

/// Tasks. Foreign keys are local ids and are deliberately not enforced: a
/// pulled task may reference a project that arrives later in the same cycle.
///
/// `due_date` is `YYYY-MM-DD` and `due_time` is `HH:mm` (the user's wall
/// clock, never converted); the other `DateTime` columns are UTC instants.
@DataClassName('TaskRow')
@TableIndex(name: 'idx_tasks_due_date', columns: {#dueDate})
@TableIndex(name: 'idx_tasks_status', columns: {#status})
@TableIndex(name: 'idx_tasks_project', columns: {#projectLocalId})
@TableIndex(name: 'idx_tasks_parent', columns: {#parentLocalId})
@TableIndex(name: 'idx_tasks_completed_at', columns: {#completedAt})
class Tasks extends Table with SyncColumns {
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get originalName => text().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get status => integer().withDefault(const Constant(0))();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  TextColumn get dueDate => text().nullable()();
  TextColumn get dueTime => text().nullable()();
  DateTimeColumn get deferUntil => dateTime().nullable()();
  DateTimeColumn get reminderAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get estimatedMinutes => integer().nullable()();
  TextColumn get projectLocalId => text().nullable()();
  TextColumn get areaLocalId => text().nullable()();
  TextColumn get parentLocalId => text().nullable()();

  /// Server uid of the recurring template this occurrence came from.
  TextColumn get recurringParentUid => text().nullable()();
  IntColumn get sortOrder => integer().nullable()();
  TextColumn get recurrenceType => text().nullable()();
  IntColumn get recurrenceInterval => integer().nullable()();
  TextColumn get recurrenceEndDate => text().nullable()();
  IntColumn get recurrenceWeekday => integer().nullable()();

  /// JSON list of ints, e.g. `[1,3,5]`.
  TextColumn get recurrenceWeekdays => text().nullable()();
  IntColumn get recurrenceMonthDay => integer().nullable()();
  IntColumn get recurrenceWeekOfMonth => integer().nullable()();
  BoolColumn get completionBased =>
      boolean().withDefault(const Constant(false))();
  IntColumn get todayMoveCount => integer().withDefault(const Constant(0))();
  BoolColumn get isBlocked => boolean().withDefault(const Constant(false))();

  /// Status to restore when a completed task is un-completed offline.
  IntColumn get statusBeforeDone => integer().nullable()();
}

/// Task <-> tag join (both sides are local ids).
@DataClassName('TaskTagRow')
@TableIndex(name: 'idx_task_tags_tag', columns: {#tagLocalId})
class TaskTags extends Table {
  TextColumn get taskLocalId => text()();
  TextColumn get tagLocalId => text()();

  @override
  Set<Column> get primaryKey => {taskLocalId, tagLocalId};
}
