import 'package:drift/drift.dart';

import 'sync_columns.dart';

@DataClassName('TagRow')
class Tags extends Table with SyncColumns {
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get color => text().nullable()();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
}
