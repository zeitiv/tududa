import 'package:drift/drift.dart';

import 'sync_columns.dart';

@DataClassName('InboxRow')
@TableIndex(name: 'idx_inbox_status', columns: {#status})
class InboxItems extends Table with SyncColumns {
  TextColumn get content => text().withDefault(const Constant(''))();
  TextColumn get title => text().nullable()();

  /// Wire name: added, processed, ignored.
  TextColumn get status => text().withDefault(const Constant('added'))();
  TextColumn get source => text().withDefault(const Constant('manual'))();
}
