import 'package:drift/drift.dart';

/// Columns shared by every synced entity table (tasks, projects, areas,
/// notes, tags, inbox_items).
///
/// - `local_id`: client-generated uuid, the only key other rows reference.
/// - `uid` / `server_id`: filled in from the server after the create is
///   pushed (null until then). `uid` is unique among non-null values.
/// - `server_*_at`: server clock, copied from the last pulled DTO.
/// - `local_updated_at`: device clock, bumped by every local write.
/// - `dirty_fields`: JSON `{field: editedAtEpochMs}`, see `DirtyFields`.
/// - `base_json`: JSON of the last known server snapshot (the merge base and
///   the state a rollback restores).
/// - `pending_delete`: the user deleted the row; it is hidden from lists and
///   removed for real once the delete is pushed.
mixin SyncColumns on Table {
  TextColumn get localId => text()();
  TextColumn get uid => text().nullable().unique()();
  IntColumn get serverId => integer().nullable()();
  DateTimeColumn get serverCreatedAt => dateTime().nullable()();
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();
  DateTimeColumn get localUpdatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  TextColumn get dirtyFields => text().withDefault(const Constant('{}'))();
  TextColumn get baseJson => text().nullable()();
  BoolColumn get pendingDelete =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {localId};
}
