import 'package:drift/drift.dart';

import 'sync_columns.dart';

@DataClassName('ProjectRow')
@TableIndex(name: 'idx_projects_area', columns: {#areaLocalId})
class Projects extends Table with SyncColumns {
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get description => text().nullable()();

  /// Wire name: not_started, in_progress, done, waiting, cancelled, planned.
  TextColumn get status => text().withDefault(const Constant('not_started'))();
  IntColumn get priority => integer().nullable()();

  /// Raw `due_date_at` string as the server sends it.
  TextColumn get dueDateAt => text().nullable()();
  TextColumn get areaLocalId => text().nullable()();
  BoolColumn get pinToSidebar => boolean().withDefault(const Constant(false))();
  BoolColumn get taskShowCompleted =>
      boolean().withDefault(const Constant(false))();
  TextColumn get taskSortOrder =>
      text().withDefault(const Constant('created_at:desc'))();
  TextColumn get imageUrl => text().nullable()();

  /// Server-computed counts (read-only; refreshed on pull).
  IntColumn get taskCount => integer().nullable()();
  IntColumn get completedTaskCount => integer().nullable()();
}
