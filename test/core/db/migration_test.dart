import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/db/app_database.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as schema1;

/// Schema migration tests.
///
/// Adding schema v2:
/// 1. change tables, bump `AppDatabase.schemaVersion` to 2;
/// 2. `dart run drift_dev make-migrations` (dumps drift_schemas/app_database/
///    drift_schema_v2.json), then
///    `dart run drift_dev schema steps drift_schemas/app_database lib/core/db/app_database.steps.dart` and
///    `dart run drift_dev schema generate drift_schemas/app_database test/core/db/generated/`;
/// 3. implement `from1To2` in `AppDatabase.migration`;
/// 4. add a test below: `startAt(1)`, insert rows with `schema1.<table>`,
///    `migrateAndValidate(db, 2, validateDropped: true)`, check the rows.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('schema v1 matches the Dart tables and search triggers', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase.forTesting(connection);
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 1);
  });

  test('schema v2 matches the Dart tables and search triggers', () async {
    final connection = await verifier.startAt(2);
    final db = AppDatabase.forTesting(connection);
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 2);
  });

  const v2Indexes = [
    'idx_tasks_server_id',
    'idx_tasks_area',
    'idx_tasks_recurring_parent',
    'idx_tasks_list',
  ];

  Future<Set<String>> indexNames(AppDatabase db) async => {
    for (final r
        in await db
            .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
            .get())
      r.read<String>('name'),
  };

  test('v1 -> v2 adds the query-plan indexes and keeps rows', () async {
    final schema = await verifier.schemaAt(1);
    final old = schema1.DatabaseAtV1(schema.newConnection());
    await old.customStatement(
      "INSERT INTO tasks (local_id, name, local_updated_at, dirty_fields, "
      "pending_delete, status, priority, today_move_count, is_blocked, "
      "completion_based) VALUES ('t1', 'kept', '2026-01-01T00:00:00.000Z', '{}', 0, 0, 0, 0, 0, 0)",
    );
    await old.close();

    final db = AppDatabase.forTesting(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(
      db,
      2,
      options: const ValidationOptions(validateDropped: true),
    );
    expect(await indexNames(db), containsAll(v2Indexes));
    final rows = await db.select(db.tasks).get();
    expect(rows.map((r) => r.name), ['kept']);
  });

  test('a fresh database has the v2 indexes', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await indexNames(db), containsAll(v2Indexes));
  });

  test('schemaVersion has a dumped schema', () {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    expect(GeneratedHelper.versions, contains(db.schemaVersion));
  });
}
