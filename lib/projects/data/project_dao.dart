import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';
import '../../core/db/dirty_fields.dart';
import '../../core/ids.dart';
import '../models/project_model.dart';

/// Wire names of the project fields that can be edited locally (the keys of
/// `dirty_fields` and of the `base_json` snapshot). `area_uid` is stored as
/// `area_local_id`.
abstract final class ProjectFields {
  static const name = 'name';
  static const description = 'description';
  static const status = 'status';
  static const priority = 'priority';
  static const dueDateAt = 'due_date_at';
  static const areaUid = 'area_uid';
  static const pinToSidebar = 'pin_to_sidebar';
  static const taskShowCompleted = 'task_show_completed';
  static const taskSortOrder = 'task_sort_order';
  static const all = [
    name,
    description,
    status,
    priority,
    dueDateAt,
    areaUid,
    pinToSidebar,
    taskShowCompleted,
    taskSortOrder,
  ];

  /// What `POST /project` carries.
  static const create = [
    name,
    description,
    status,
    priority,
    dueDateAt,
    areaUid,
    pinToSidebar,
  ];
}

/// A project row with its area (for the area's name and uid).
class ProjectEntry {
  const ProjectEntry(this.project, this.area);
  final ProjectRow project;
  final AreaRow? area;

  Project toDomain() {
    final p = project;
    return Project(
      uid: ProjectUid(p.uid ?? p.localId),
      id: p.serverId,
      name: p.name,
      description: p.description,
      status: p.status,
      priority: p.priority,
      dueDateAt: p.dueDateAt == null ? null : DateTime.tryParse(p.dueDateAt!),
      areaUid: area == null ? null : AreaUid(area!.uid ?? area!.localId),
      areaName: area?.name,
      pinToSidebar: p.pinToSidebar,
      taskShowCompleted: p.taskShowCompleted,
      taskSortOrder: p.taskSortOrder,
      imageUrl: p.imageUrl,
      createdAt: p.serverCreatedAt,
      updatedAt: p.serverUpdatedAt,
      taskCount: p.taskCount,
      completedTaskCount: p.completedTaskCount,
      localId: p.localId,
    );
  }
}

/// Typed access to the `projects` table. Hidden rows (`pending_delete`) are
/// left out of every read except [byLocalId] / [byUid].
///
/// `task_count` / `completed_task_count` are server-derived: only pulls and
/// pushes write them, and they are never marked dirty.
class ProjectDao {
  ProjectDao(this.db);

  final AppDatabase db;

  $ProjectsTable get _t => db.projects;

  JoinedSelectStatement _visible() =>
      (db.select(_t)..where((t) => t.pendingDelete.equals(false))).join([
        leftOuterJoin(db.areas, db.areas.localId.equalsExp(_t.areaLocalId)),
      ])..orderBy([
        OrderingTerm.asc(_t.name.lower()),
        OrderingTerm.asc(_t.localId),
      ]);

  ProjectEntry _entry(TypedResult r) =>
      ProjectEntry(r.readTable(_t), r.readTableOrNull(db.areas));

  Expression<bool> _isKey(String key) =>
      _t.uid.equals(key) | _t.localId.equals(key);

  /// Visible projects, sorted by name.
  Stream<List<ProjectEntry>> watchAll() =>
      _visible().watch().map((rs) => rs.map(_entry).toList());

  Future<List<ProjectEntry>> all() async =>
      (await _visible().get()).map(_entry).toList();

  Stream<ProjectEntry?> watchByLocalId(String localId) =>
      (_visible()..where(_t.localId.equals(localId))).watch().map(
        (rs) => rs.isEmpty ? null : _entry(rs.first),
      );

  Stream<ProjectEntry?> watchByUid(String uid) =>
      (_visible()..where(_t.uid.equals(uid))).watch().map(
        (rs) => rs.isEmpty ? null : _entry(rs.first),
      );

  /// By server uid or, for projects not pushed yet, by local id.
  Stream<ProjectEntry?> watchByKey(String key) =>
      (_visible()..where(_isKey(key))).watch().map(
        (rs) => rs.isEmpty ? null : _entry(rs.first),
      );

  Future<ProjectEntry?> entryByKey(String key) async {
    final rs = await (_visible()..where(_isKey(key))).get();
    return rs.isEmpty ? null : _entry(rs.first);
  }

  Future<ProjectRow?> byLocalId(String localId) => (db.select(
    _t,
  )..where((t) => t.localId.equals(localId))).getSingleOrNull();

  Future<ProjectRow?> byUid(String uid) =>
      (db.select(_t)..where((t) => t.uid.equals(uid))).getSingleOrNull();

  /// Projects (also hidden ones) that point at [areaLocalId].
  Future<List<ProjectRow>> inArea(String areaLocalId) =>
      (db.select(_t)..where((t) => t.areaLocalId.equals(areaLocalId))).get();

  /// Insert or update by primary key (never `INSERT OR REPLACE`).
  Future<void> upsert(ProjectsCompanion row) =>
      db.into(_t).insertOnConflictUpdate(row);

  /// Writes [changes] to the row and marks [dirty] fields as edited at [now].
  /// Call inside the transaction that also enqueues the outbox entry.
  Future<void> editFields(
    String localId,
    ProjectsCompanion changes, {
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
        ProjectsCompanion(
          pendingDelete: const Value(true),
          localUpdatedAt: Value(now),
        ),
      );
}
