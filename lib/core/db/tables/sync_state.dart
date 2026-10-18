import 'package:drift/drift.dart';

/// Per-entity pull bookkeeping (`entity` is a `SyncEntity` value).
@DataClassName('SyncStateRow')
class SyncStates extends Table {
  @override
  String get tableName => 'sync_state';

  TextColumn get entity => text()();

  /// Server-time instant the last successful pull started at.
  DateTimeColumn get lastPullCursor => dateTime().nullable()();
  DateTimeColumn get lastFullReconcileAt => dateTime().nullable()();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {entity};
}

/// Small key/value store for cached JSON (profile, ...).
@DataClassName('KvSetting')
class KvSettings extends Table {
  @override
  String get tableName => 'kv_settings';

  TextColumn get key => text()();

  /// JSON-encoded value.
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
