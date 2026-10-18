import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/db/app_database.dart';

import 'generated/schema.dart';

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

  test('schemaVersion has a dumped schema', () {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    expect(GeneratedHelper.versions, contains(db.schemaVersion));
  });
}
