import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';
import '../../core/db/dirty_fields.dart';

/// Typed access to the `inbox_items` table.
///
/// Writes that must reach the server go through `OfflineInboxRepository`,
/// which pairs them with an outbox entry in one transaction; the sync handler
/// uses this DAO for pulled data and push bookkeeping.
class InboxDao {
  InboxDao(this._db);
  final AppDatabase _db;

  $InboxItemsTable get _t => _db.inboxItems;

  /// Insert-or-update by primary key (never INSERT OR REPLACE: the search
  /// index and triggers must see an update).
  Future<void> upsert(InboxItemsCompanion row) =>
      _db.into(_t).insertOnConflictUpdate(row);

  Future<void> updateRow(String localId, InboxItemsCompanion changes) =>
      (_db.update(_t)..where((r) => r.localId.equals(localId))).write(changes);

  Future<InboxRow?> byLocalId(String localId) => (_db.select(
    _t,
  )..where((r) => r.localId.equals(localId))).getSingleOrNull();

  Future<InboxRow?> byUid(String uid) =>
      (_db.select(_t)..where((r) => r.uid.equals(uid))).getSingleOrNull();

  /// A row addressed by server uid or local id.
  Future<InboxRow?> byRef(String ref) async =>
      await byUid(ref) ?? await byLocalId(ref);

  /// Marks [fields] dirty on top of the row's current marks.
  static String markDirty(InboxRow row, Iterable<String> fields, int nowMs) =>
      DirtyFields.decode(row.dirtyFields).markAll(fields, nowMs).encode();

  SimpleSelectStatement<$InboxItemsTable, InboxRow> _visibleQuery() =>
      _db.select(_t)
        ..where((r) => r.pendingDelete.equals(false))
        ..where((r) => r.status.equals('processed').not())
        ..orderBy([
          (r) => OrderingTerm.desc(
            const CustomExpression<DateTime>(
              'coalesce(server_created_at, local_updated_at)',
            ),
          ),
          (r) => OrderingTerm.desc(r.localUpdatedAt),
          (r) => OrderingTerm.desc(r.localId),
        ]);

  /// Live list for the inbox screen: newest first, without items waiting to
  /// be deleted and without processed ones.
  Stream<List<InboxRow>> watchAll() => _visibleQuery().watch();

  Future<List<InboxRow>> visible({int? limit, int offset = 0}) async {
    final q = _visibleQuery();
    if (limit != null) q.limit(limit, offset: offset);
    return q.get();
  }

  Future<int> visibleCount() async {
    final c = _t.localId.count();
    final q = _db.selectOnly(_t)
      ..addColumns([c])
      ..where(_t.pendingDelete.equals(false))
      ..where(_t.status.equals('processed').not());
    return (await q.getSingle()).read(c) ?? 0;
  }
}
