import 'package:drift/drift.dart';

import 'sync_columns.dart';

@DataClassName('AreaRow')
class Areas extends Table with SyncColumns {
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get description => text().nullable()();

  /// Server-computed (read-only; refreshed on pull).
  IntColumn get projectCount => integer().nullable()();
}
