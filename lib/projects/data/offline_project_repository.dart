import 'package:drift/drift.dart';

import '../../areas/data/area_dao.dart';
import '../../core/api/api_error.dart';
import '../../core/api/patch.dart' as pt;
import '../../core/db/app_database.dart';
import '../../core/db/dirty_fields.dart';
import '../../core/ids.dart';
import '../models/project_model.dart';
import 'project_api.dart';
import 'project_dao.dart';
import 'project_repository.dart';

/// Project writes go to the local table and the outbox in one transaction;
/// the sync engine sends them later. Reads come from the table. Projects (and
/// areas) are addressed by uid, or by local id while they have no uid yet.
class OfflineProjectRepository implements ProjectRepository {
  OfflineProjectRepository(this._db, {DateTime Function()? now})
    : _now = now ?? (() => DateTime.now().toUtc()),
      _dao = ProjectDao(_db),
      _areas = AreaDao(_db);

  final AppDatabase _db;
  final DateTime Function() _now;
  final ProjectDao _dao;
  final AreaDao _areas;

  Stream<List<Project>> watchAll() =>
      _dao.watchAll().map((es) => [for (final e in es) e.toDomain()]);

  /// Emits null while no visible project has [key] (uid or local id).
  Stream<Project?> watchByKey(String key) =>
      _dao.watchByKey(key).map((e) => e?.toDomain());

  @override
  Future<List<Project>> list() async => [
    for (final e in await _dao.all()) e.toDomain(),
  ];

  @override
  Future<Project> get(ProjectUid uid) async =>
      (await _requireEntry(uid.value)).toDomain();

  @override
  Future<Project> create(NewProject project) {
    final id = LocalId.generate().value;
    final now = _now();
    return _db.transaction(() async {
      final areaLocalId = await _areaLocalId(project.areaUid);
      await _dao.upsert(
        ProjectsCompanion.insert(
          localId: id,
          name: Value(project.name),
          description: Value(project.description),
          status: Value(project.status),
          priority: Value(project.priority),
          dueDateAt: Value(project.dueDateAt?.toUtc().toIso8601String()),
          areaLocalId: Value(areaLocalId),
          pinToSidebar: Value(project.pinToSidebar),
          localUpdatedAt: Value(now),
          dirtyFields: Value(
            const DirtyFields()
                .markAll(ProjectFields.create, now.millisecondsSinceEpoch)
                .encode(),
          ),
        ),
      );
      await _db.outboxDao.enqueue(
        entity: SyncEntity.project,
        localId: id,
        op: OutboxOp.create,
        now: now,
      );
      return (await _dao.entryByKey(id))!.toDomain();
    });
  }

  @override
  Future<Project> update(ProjectUid uid, ProjectPatch patch) {
    final now = _now();
    return _db.transaction(() async {
      final entry = await _requireEntry(uid.value);
      final row = entry.project;
      final dirty = <String>[];
      var c = const ProjectsCompanion();

      void stage<T>(
        String field,
        pt.Patch<T> p,
        T? current,
        ProjectsCompanion Function(T?) apply, {
        bool nullable = true,
      }) {
        if (p is! pt.Set<T>) return;
        final v = p.value;
        if (v == null && !nullable) return;
        if (v == current) return;
        c = apply(v);
        dirty.add(field);
      }

      stage(
        ProjectFields.name,
        patch.name,
        row.name,
        (v) => c.copyWith(name: Value(v!)),
        nullable: false,
      );
      stage(
        ProjectFields.description,
        patch.description,
        row.description,
        (v) => c.copyWith(description: Value(v)),
      );
      stage(
        ProjectFields.status,
        patch.status,
        row.status,
        (v) => c.copyWith(status: Value(v!)),
        nullable: false,
      );
      stage(
        ProjectFields.priority,
        patch.priority,
        row.priority,
        (v) => c.copyWith(priority: Value(v)),
      );
      stage(
        ProjectFields.pinToSidebar,
        patch.pinToSidebar,
        row.pinToSidebar,
        (v) => c.copyWith(pinToSidebar: Value(v!)),
        nullable: false,
      );
      stage(
        ProjectFields.taskShowCompleted,
        patch.taskShowCompleted,
        row.taskShowCompleted,
        (v) => c.copyWith(taskShowCompleted: Value(v!)),
        nullable: false,
      );
      stage(
        ProjectFields.taskSortOrder,
        patch.taskSortOrder,
        row.taskSortOrder,
        (v) => c.copyWith(taskSortOrder: Value(v!)),
        nullable: false,
      );
      if (patch.dueDateAt case pt.Set<DateTime>(:final value)) {
        final raw = value?.toUtc().toIso8601String();
        if (raw != row.dueDateAt) {
          c = c.copyWith(dueDateAt: Value(raw));
          dirty.add(ProjectFields.dueDateAt);
        }
      }
      if (patch.areaUid case pt.Set<AreaUid>(:final value)) {
        final areaLocalId = await _areaLocalId(value);
        if (areaLocalId != row.areaLocalId) {
          c = c.copyWith(areaLocalId: Value(areaLocalId));
          dirty.add(ProjectFields.areaUid);
        }
      }

      if (dirty.isEmpty) return entry.toDomain();
      await _dao.editFields(row.localId, c, dirty: dirty, now: now);
      await _db.outboxDao.enqueue(
        entity: SyncEntity.project,
        localId: row.localId,
        op: OutboxOp.update,
        now: now,
      );
      return (await _dao.entryByKey(row.localId))!.toDomain();
    });
  }

  @override
  Future<void> delete(ProjectUid uid) {
    final now = _now();
    return _db.transaction(() async {
      final entry = await _requireEntry(uid.value);
      await _dao.setPendingDelete(entry.project.localId, now);
      await _db.outboxDao.enqueue(
        entity: SyncEntity.project,
        localId: entry.project.localId,
        op: OutboxOp.delete,
        now: now,
      );
    });
  }

  Future<ProjectEntry> _requireEntry(String key) async =>
      await _dao.entryByKey(key) ??
      (throw const NotFoundError('Project not found'));

  /// Local id of the area with uid/local id [area]; null for no area.
  Future<String?> _areaLocalId(AreaUid? area) async {
    if (area == null) return null;
    final row = await _areas.byKey(area.value);
    return row?.localId ?? (throw const NotFoundError('Area not found'));
  }
}
