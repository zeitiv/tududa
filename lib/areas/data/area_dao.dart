import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';
import '../../core/db/dirty_fields.dart';
import '../../core/ids.dart';
import '../models/area_model.dart';

/// Wire names of the area fields that can be edited locally (the keys of
/// `dirty_fields` and of the `base_json` snapshot).
abstract final class AreaFields {
  static const name = 'name';
  static const description = 'description';
  static const all = [name, description];
}

/// Typed access to the `areas` table. Hidden rows (`pending_delete`) are left
/// out of every read except [byLocalId] / [byUid].
///
/// `project_count` is server-derived: only pulls and pushes write it, and it
/// is never marked dirty.
class AreaDao {
  AreaDao(this.db);

  final AppDatabase db;

  $AreasTable get _t => db.areas;

  SimpleSelectStatement<$AreasTable, AreaRow> _visible() => db.select(_t)
    ..where((t) => t.pendingDelete.equals(false))
    ..orderBy([
      (t) => OrderingTerm.asc(t.name.lower()),
      (t) => OrderingTerm.asc(t.localId),
    ]);

  Expression<bool> _isKey(String key) =>
      _t.uid.equals(key) | _t.localId.equals(key);

  /// Visible areas, sorted by name.
  Stream<List<AreaRow>> watchAll() => _visible().watch();
  Future<List<AreaRow>> all() => _visible().get();

  Stream<AreaRow?> watchByLocalId(String localId) =>
      (_visible()..where((t) => t.localId.equals(localId))).watchSingleOrNull();

  Stream<AreaRow?> watchByUid(String uid) =>
      (_visible()..where((t) => t.uid.equals(uid))).watchSingleOrNull();

  /// By server uid or, for areas not pushed yet, by local id.
  Stream<AreaRow?> watchByKey(String key) =>
      (_visible()..where((t) => _isKey(key))).watchSingleOrNull();

  Future<AreaRow?> byLocalId(String localId) => (db.select(
    _t,
  )..where((t) => t.localId.equals(localId))).getSingleOrNull();

  Future<AreaRow?> byUid(String uid) =>
      (db.select(_t)..where((t) => t.uid.equals(uid))).getSingleOrNull();

  /// A visible area by uid or local id.
  Future<AreaRow?> byKey(String key) =>
      (_visible()..where((t) => _isKey(key))).getSingleOrNull();

  /// Insert or update by primary key (never `INSERT OR REPLACE`).
  Future<void> upsert(AreasCompanion row) =>
      db.into(_t).insertOnConflictUpdate(row);

  /// Writes [changes] to the row and marks [dirty] fields as edited at [now].
  /// Call inside the transaction that also enqueues the outbox entry.
  Future<void> editFields(
    String localId,
    AreasCompanion changes, {
    required Iterable<String> dirty,
    required DateTime now,
  }) async {
    final row = await byLocalId(localId);
    if (row == null) return;
    final marks = DirtyFields.decode(row.dirtyFields)
        .markAll(dirty, now.millisecondsSinceEpoch);
    await (db.update(_t)..where((t) => t.localId.equals(localId))).write(
      changes.copyWith(
        dirtyFields: Value(marks.encode()),
        localUpdatedAt: Value(now),
      ),
    );
  }

  Future<void> setPendingDelete(String localId, DateTime now) =>
      (db.update(_t)..where((t) => t.localId.equals(localId))).write(
        AreasCompanion(
          pendingDelete: const Value(true),
          localUpdatedAt: Value(now),
        ),
      );
}

extension AreaRowDomain on AreaRow {
  /// The domain area; [Area.uid] is the local id until the server assigned one.
  Area toDomain() => Area(
    uid: AreaUid(uid ?? localId),
    id: serverId,
    name: name,
    description: description,
    createdAt: serverCreatedAt,
    updatedAt: serverUpdatedAt,
    projectCount: projectCount,
    localId: localId,
  );
}
