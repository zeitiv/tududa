import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sync/outbox_dao.dart';
import 'app_database.steps.dart';
import 'dao/kv_dao.dart';
import 'dao/sync_state_dao.dart';
import 'tables/areas.dart';
import 'tables/inbox_items.dart';
import 'tables/notes.dart';
import 'tables/outbox.dart';
import 'tables/projects.dart';
import 'tables/sync_state.dart';
import 'tables/tags.dart';
import 'tables/tasks.dart';

export 'tables/outbox.dart' show OutboxOp, OutboxState, SyncEntity;

part 'app_database.g.dart';

/// The offline store: synced entity tables, the outbox, sync bookkeeping and
/// the full-text index (see `tables/search_fts.drift`).
///
/// Production: `AppDatabase()` (SQLite file `tududa` in the app documents
/// dir). Tests: `AppDatabase.forTesting(NativeDatabase.memory())`.
///
/// Schema changes: bump [schemaVersion], run
/// `dart run drift_dev make-migrations`, then regenerate the helpers with
/// `dart run drift_dev schema steps drift_schemas/app_database lib/core/db/app_database.steps.dart`
/// and `dart run drift_dev schema generate drift_schemas/app_database test/core/db/generated/`
/// (make-migrations only dumps `drift_schemas/app_database/drift_schema_vN.json`),
/// add the step to `onUpgrade` and extend `test/core/db/migration_test.dart`.
@DriftDatabase(
  tables: [
    Tasks,
    TaskTags,
    Tags,
    Projects,
    Areas,
    Notes,
    NoteTags,
    InboxItems,
    Outbox,
    SyncStates,
    KvSettings,
  ],
  include: {'tables/search_fts.drift'},
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'tududa'));

  AppDatabase.forTesting(super.executor);

  /// The outbox queue (coalescing, scheduling, counts).
  late final OutboxDao outboxDao = OutboxDao(this);

  /// Per-entity pull cursors and sync timestamps.
  late final SyncStateDao syncStateDao = SyncStateDao(this);

  /// Cached JSON values (profile, ...).
  late final KvDao kvDao = KvDao(this);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    // v2+: regenerate with `make-migrations` + `schema steps`, then pass
    // `from1To2: (m, schema) async { ... }` here.
    onUpgrade: stepByStep(),
  );

  /// Deletes every row of every table (including outbox, sync state, cached
  /// settings and the search index) in one transaction. Used when the account
  /// or server changes.
  Future<void> wipe() => transaction(() async {
    for (final table in allTables) {
      await delete(table).go();
    }
  });

  /// Recreates the full-text index from the entity tables. Only needed if the
  /// index was bypassed (e.g. `INSERT OR REPLACE`).
  Future<void> rebuildSearchIndex() => transaction(() async {
    await customStatement('DELETE FROM search_fts');
    const sources = [
      ("'task'", 'tasks', 'name', "coalesce(note, '')"),
      ("'note'", 'notes', "coalesce(title, '')", "coalesce(content, '')"),
      ("'project'", 'projects', 'name', "coalesce(description, '')"),
      ("'tag'", 'tags', 'name', "''"),
      ("'area'", 'areas', 'name', "coalesce(description, '')"),
    ];
    for (final (entity, table, title, body) in sources) {
      await customStatement(
        'INSERT INTO search_fts (entity, local_id, title, body) '
        'SELECT $entity, local_id, $title, $body FROM $table '
        'WHERE pending_delete = 0',
      );
    }
  });
}

/// The app's database. Closed when the provider is disposed. Tests override
/// it with `AppDatabase.forTesting(NativeDatabase.memory())`.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
