import 'package:drift/drift.dart';

import '../app_database.dart';

/// Reads and writes the per-entity `sync_state` rows.
class SyncStateDao {
  SyncStateDao(this._db);
  final AppDatabase _db;

  Future<SyncStateRow?> get(String entity) => (_db.select(
    _db.syncStates,
  )..where((t) => t.entity.equals(entity))).getSingleOrNull();

  Future<List<SyncStateRow>> all() => _db.select(_db.syncStates).get();

  /// Upserts only the given columns for [entity].
  Future<void> update(
    String entity, {
    Value<DateTime?> lastPullCursor = const Value.absent(),
    Value<DateTime?> lastFullReconcileAt = const Value.absent(),
    Value<DateTime?> lastSyncAt = const Value.absent(),
  }) async {
    final existing = await get(entity);
    if (existing == null) {
      await _db
          .into(_db.syncStates)
          .insert(
            SyncStatesCompanion.insert(
              entity: entity,
              lastPullCursor: lastPullCursor,
              lastFullReconcileAt: lastFullReconcileAt,
              lastSyncAt: lastSyncAt,
            ),
          );
    } else {
      await (_db.update(
        _db.syncStates,
      )..where((t) => t.entity.equals(entity))).write(
        SyncStatesCompanion(
          lastPullCursor: lastPullCursor,
          lastFullReconcileAt: lastFullReconcileAt,
          lastSyncAt: lastSyncAt,
        ),
      );
    }
  }

  /// The most recent `last_sync_at` over all entities.
  Future<DateTime?> lastSyncAt() async {
    DateTime? best;
    for (final r in await all()) {
      final t = r.lastSyncAt;
      if (t != null && (best == null || t.isAfter(best))) best = t;
    }
    return best;
  }
}
