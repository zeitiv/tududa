import 'package:drift/drift.dart';

import '../../core/api/api_error.dart';
import '../../core/api/patch.dart' as pt;
import '../../core/db/app_database.dart';
import '../../core/db/dirty_fields.dart';
import '../../core/ids.dart';
import '../../projects/data/project_dao.dart';
import '../models/area_model.dart';
import 'area_api.dart';
import 'area_dao.dart';
import 'area_repository.dart';

/// Area writes go to the local table and the outbox in one transaction; the
/// sync engine sends them later. Reads come from the table. Areas are
/// addressed by uid, or by local id while they have no uid yet.
class OfflineAreaRepository implements AreaRepository {
  OfflineAreaRepository(this._db, {DateTime Function()? now})
    : _now = now ?? (() => DateTime.now().toUtc()),
      _dao = AreaDao(_db),
      _projects = ProjectDao(_db);

  final AppDatabase _db;
  final DateTime Function() _now;
  final AreaDao _dao;
  final ProjectDao _projects;

  Stream<List<Area>> watchAll() =>
      _dao.watchAll().map((rows) => [for (final r in rows) r.toDomain()]);

  Stream<Area?> watchByKey(String key) =>
      _dao.watchByKey(key).map((r) => r?.toDomain());

  @override
  Future<List<Area>> list() async => [
    for (final r in await _dao.all()) r.toDomain(),
  ];

  @override
  Future<Area> create(NewArea area) {
    final id = LocalId.generate().value;
    final now = _now();
    return _db.transaction(() async {
      await _dao.upsert(
        AreasCompanion.insert(
          localId: id,
          name: Value(area.name),
          description: Value(area.description),
          localUpdatedAt: Value(now),
          dirtyFields: Value(
            const DirtyFields()
                .markAll(AreaFields.all, now.millisecondsSinceEpoch)
                .encode(),
          ),
        ),
      );
      await _db.outboxDao.enqueue(
        entity: SyncEntity.area,
        localId: id,
        op: OutboxOp.create,
        now: now,
      );
      return (await _dao.byLocalId(id))!.toDomain();
    });
  }

  @override
  Future<Area> update(AreaUid uid, AreaPatch patch) {
    final now = _now();
    return _db.transaction(() async {
      final row = await _require(uid.value);
      final dirty = <String>[];
      var changes = const AreasCompanion();
      if (patch.name case pt.Set<String>(:final value)) {
        if (value != null && value != row.name) {
          changes = changes.copyWith(name: Value(value));
          dirty.add(AreaFields.name);
        }
      }
      if (patch.description case pt.Set<String>(:final value)) {
        if (value != row.description) {
          changes = changes.copyWith(description: Value(value));
          dirty.add(AreaFields.description);
        }
      }
      if (dirty.isEmpty) return row.toDomain();
      await _dao.editFields(row.localId, changes, dirty: dirty, now: now);
      await _db.outboxDao.enqueue(
        entity: SyncEntity.area,
        localId: row.localId,
        op: OutboxOp.update,
        now: now,
      );
      return (await _dao.byLocalId(row.localId))!.toDomain();
    });
  }

  /// Hides the area and queues the delete. Its projects are unlinked locally
  /// (as the server does) and pushed before the delete.
  @override
  Future<void> delete(AreaUid uid) {
    final now = _now();
    return _db.transaction(() async {
      final row = await _require(uid.value);
      for (final p in await _projects.inArea(row.localId)) {
        await _projects.editFields(
          p.localId,
          const ProjectsCompanion(areaLocalId: Value(null)),
          dirty: const [ProjectFields.areaUid],
          now: now,
        );
        if (!p.pendingDelete) {
          await _db.outboxDao.enqueue(
            entity: SyncEntity.project,
            localId: p.localId,
            op: OutboxOp.update,
            now: now,
          );
        }
      }
      await _dao.setPendingDelete(row.localId, now);
      await _db.outboxDao.enqueue(
        entity: SyncEntity.area,
        localId: row.localId,
        op: OutboxOp.delete,
        now: now,
      );
    });
  }

  Future<AreaRow> _require(String key) async =>
      await _dao.byKey(key) ?? (throw const NotFoundError('Area not found'));
}
