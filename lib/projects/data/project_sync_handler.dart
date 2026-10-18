import 'package:drift/drift.dart';

import '../../core/api/api_error.dart';
import '../../core/api/patch.dart' as pt;
import '../../core/db/app_database.dart';
import '../../core/db/dirty_fields.dart';
import '../../core/db/entity_access.dart';
import '../../core/ids.dart';
import '../../core/sync/merge.dart';
import '../../core/sync/sync_handler.dart';
import 'project_api.dart';
import 'project_dao.dart';
import 'project_dto.dart';

/// Prefix of the stand-in for the uid of an area that has none yet, in the
/// local field map used for merging.
const _localAreaPrefix = 'local:';

/// Syncs projects (`/projects`, `/project/:uid`). The engine pulls areas
/// first, so `area_uid` resolves to a local area on pull.
class ProjectSyncHandler extends SyncHandler {
  @override
  String get entity => SyncEntity.project;

  static Map<String, dynamic> _snapshot(ProjectDto d) => {
    ProjectFields.name: d.name,
    ProjectFields.description: d.description,
    ProjectFields.status: d.status,
    ProjectFields.priority: d.priority,
    ProjectFields.dueDateAt: d.dueDateAt,
    ProjectFields.areaUid: d.areaUid,
    ProjectFields.pinToSidebar: d.pinToSidebar,
    ProjectFields.taskShowCompleted: d.taskShowCompleted,
    ProjectFields.taskSortOrder: d.taskSortOrder,
  };

  /// The local row as a field map; an area without uid is `local:<id>`.
  static Map<String, dynamic> _local(
    ProjectRow r,
    Map<String, String?> areaUidByLocal,
  ) => {
    ProjectFields.name: r.name,
    ProjectFields.description: r.description,
    ProjectFields.status: r.status,
    ProjectFields.priority: r.priority,
    ProjectFields.dueDateAt: r.dueDateAt,
    ProjectFields.areaUid: r.areaLocalId == null
        ? null
        : (areaUidByLocal[r.areaLocalId] ??
              '$_localAreaPrefix${r.areaLocalId}'),
    ProjectFields.pinToSidebar: r.pinToSidebar,
    ProjectFields.taskShowCompleted: r.taskShowCompleted,
    ProjectFields.taskSortOrder: r.taskSortOrder,
  };

  static int? _int(Object? v) => v is num ? v.toInt() : null;

  /// Columns for a field map. [areaLocalId] is resolved by the caller.
  static ProjectsCompanion _columns(
    Map<String, dynamic> m,
    String? areaLocalId,
  ) => ProjectsCompanion(
    name: Value(m[ProjectFields.name] as String? ?? ''),
    description: Value(m[ProjectFields.description] as String?),
    status: Value(m[ProjectFields.status] as String? ?? 'not_started'),
    priority: Value(_int(m[ProjectFields.priority])),
    dueDateAt: Value(m[ProjectFields.dueDateAt] as String?),
    areaLocalId: Value(areaLocalId),
    pinToSidebar: Value(m[ProjectFields.pinToSidebar] == true),
    taskShowCompleted: Value(m[ProjectFields.taskShowCompleted] == true),
    taskSortOrder: Value(
      m[ProjectFields.taskSortOrder] as String? ?? 'created_at:desc',
    ),
  );

  /// Local area id for a server area uid (or the `local:` stand-in).
  static String? _areaLocalId(
    Object? areaUid,
    String? currentLocal,
    Map<String, String> localByUid,
  ) {
    if (areaUid is! String) return null;
    if (areaUid.startsWith(_localAreaPrefix)) return currentLocal;
    return localByUid[areaUid];
  }

  Future<Map<String, String?>> _areaUids(AppDatabase db) async => {
    for (final a in await db.select(db.areas).get()) a.localId: a.uid,
  };

  @override
  Future<void> pull(SyncContext ctx) async {
    await _apply(ctx, await ProjectApi(ctx.dio).list());
  }

  @override
  Future<void> fullReconcile(SyncContext ctx) async {
    final dtos = await ProjectApi(ctx.dio).list();
    await _apply(ctx, dtos);
    final serverUids = {for (final d in dtos) d.uid};
    await ctx.db.removeCleanMissing(entity, serverUids);

    // Deleted locally and already gone on the server: nothing left to push.
    final hidden = await (ctx.db.select(
      ctx.db.projects,
    )..where((t) => t.pendingDelete.equals(true) & t.uid.isNotNull())).get();
    for (final r in hidden) {
      final res = resolveRow(
        pendingDelete: true,
        serverDeleted: !serverUids.contains(r.uid),
        hasDirtyFields: DirtyFields.decode(r.dirtyFields).isNotEmpty,
      );
      if (res == RowResolution.removeLocal) {
        await ctx.db.deleteEntityRow(entity, r.localId);
      }
    }
  }

  Future<void> _apply(SyncContext ctx, List<ProjectDto> dtos) =>
      ctx.db.transaction(() async {
        final dao = ProjectDao(ctx.db);
        final areaUidByLocal = await _areaUids(ctx.db);
        final localByUid = await ctx.ids.localIdsByUid(SyncEntity.area);
        for (final d in dtos) {
          final snapshot = _snapshot(d);
          final serverUpdated = d.updatedAt == null
              ? ctx.serverNow
              : (DateTime.tryParse(d.updatedAt!) ?? ctx.serverNow);
          final row = await dao.byUid(d.uid);
          if (row == null) {
            await dao.upsert(
              _columns(
                snapshot,
                _areaLocalId(d.areaUid, null, localByUid),
              ).copyWith(
                localId: Value(LocalId.generate().value),
                uid: Value(d.uid),
                serverId: Value(d.id),
                serverCreatedAt: Value(_date(d.createdAt)),
                serverUpdatedAt: Value(serverUpdated),
                localUpdatedAt: Value(ctx.now),
                imageUrl: Value(d.imageUrl),
                taskCount: Value(d.taskCount),
                completedTaskCount: Value(d.completedTaskCount),
                baseJson: Value(BaseJson.encode(snapshot)),
              ),
            );
            continue;
          }
          final dirty = DirtyFields.decode(row.dirtyFields);
          final res = resolveRow(
            pendingDelete: row.pendingDelete,
            serverDeleted: false,
            hasDirtyFields: dirty.isNotEmpty,
          );
          if (res == RowResolution.keepPendingDelete) continue;

          var values = snapshot;
          var remaining = const DirtyFields();
          if (dirty.isNotEmpty) {
            final merged = mergeFields(
              BaseJson.decode(row.baseJson),
              _local(row, areaUidByLocal),
              snapshot,
              dirty.toMap(),
              entity: entity,
              localId: row.localId,
              serverUpdatedAt: serverUpdated,
              skew: ctx.skew,
            );
            merged.notices.forEach(ctx.notice);
            values = merged.value;
            remaining = DirtyFields(merged.dirtyFields);
          }
          await dao.upsert(
            _columns(
              values,
              _areaLocalId(
                values[ProjectFields.areaUid],
                row.areaLocalId,
                localByUid,
              ),
            ).copyWith(
              localId: Value(row.localId),
              serverId: Value(d.id),
              serverCreatedAt: Value.absentIfNull(_date(d.createdAt)),
              serverUpdatedAt: Value(serverUpdated),
              imageUrl: Value(d.imageUrl),
              taskCount: Value(d.taskCount),
              completedTaskCount: Value(d.completedTaskCount),
              baseJson: Value(BaseJson.encode(snapshot)),
              dirtyFields: Value(remaining.encode()),
            ),
          );
        }
      });

  static DateTime? _date(String? s) => s == null ? null : DateTime.tryParse(s);

  /// Uid of the area [localId], null when it is not (or no longer) a row.
  /// Throws `DependencyPendingException` while the area has no uid yet.
  Future<String?> _areaUid(SyncContext ctx, String? localId) async {
    if (localId == null) return null;
    if (!await ctx.db.entityExists(SyncEntity.area, localId)) return null;
    return ctx.ids.requireUid(SyncEntity.area, localId);
  }

  @override
  Future<PushResult> push(SyncContext ctx, OutboxEntry e) async {
    final dao = ProjectDao(ctx.db);
    final api = ProjectApi(ctx.dio);
    final row = await dao.byLocalId(e.localId);

    if (e.op == OutboxOp.delete) {
      if (row == null) return PushResult.dropped;
      final uid = row.uid;
      if (uid != null) {
        try {
          await api.delete(ProjectUid(uid));
        } on NotFoundError {
          // Already gone: the goal is reached.
        }
      }
      await ctx.db.deleteEntityRow(entity, e.localId);
      return uid == null ? PushResult.dropped : PushResult.ok;
    }
    if (row == null || row.pendingDelete) return PushResult.dropped;

    final dirty = DirtyFields.decode(row.dirtyFields);
    final ProjectDto dto;
    final Set<String> sentFields;
    if (e.op == OutboxOp.create && row.uid == null) {
      final areaUid = await _areaUid(ctx, row.areaLocalId);
      sentFields = {...ProjectFields.create};
      dto = await api.create(
        NewProject(
          name: row.name,
          description: row.description,
          status: row.status,
          priority: row.priority,
          areaUid: areaUid == null ? null : AreaUid(areaUid),
          pinToSidebar: row.pinToSidebar,
          dueDateAt: row.dueDateAt == null
              ? null
              : DateTime.tryParse(row.dueDateAt!),
        ),
      );
    } else {
      if (row.uid == null) return PushResult.waitForDependency;
      sentFields = dirty.fields.intersection({...ProjectFields.all});
      if (sentFields.isEmpty) return PushResult.dropped;
      final areaUid = sentFields.contains(ProjectFields.areaUid)
          ? await _areaUid(ctx, row.areaLocalId)
          : null;
      bool has(String f) => sentFields.contains(f);
      pt.Patch<T> val<T>(String f, T? v) => !has(f)
          ? pt.Patch<T>.unset()
          : (v == null ? pt.Patch<T>.clear() : pt.Patch<T>.set(v));
      dto = await api.update(
        ProjectUid(row.uid!),
        ProjectPatch(
          name: val(ProjectFields.name, row.name),
          description: val(ProjectFields.description, row.description),
          status: val(ProjectFields.status, row.status),
          priority: val(ProjectFields.priority, row.priority),
          areaUid: val(
            ProjectFields.areaUid,
            areaUid == null ? null : AreaUid(areaUid),
          ),
          pinToSidebar: val(ProjectFields.pinToSidebar, row.pinToSidebar),
          taskShowCompleted: val(
            ProjectFields.taskShowCompleted,
            row.taskShowCompleted,
          ),
          taskSortOrder: val(ProjectFields.taskSortOrder, row.taskSortOrder),
          dueDateAt: val(
            ProjectFields.dueDateAt,
            row.dueDateAt == null ? null : DateTime.tryParse(row.dueDateAt!),
          ),
        ),
      );
    }
    final sent = {for (final f in sentFields) f: ?dirty.editedAt(f)};
    await _applyPushed(ctx, e.localId, dto, sent);
    return PushResult.ok;
  }

  /// Stores the server's answer: uid, ids, counts, timestamps, a fresh
  /// `base_json`; clears the dirty fields that were sent (not those edited
  /// meanwhile, nor ones the create request cannot carry).
  Future<void> _applyPushed(
    SyncContext ctx,
    String localId,
    ProjectDto dto,
    Map<String, int> sent,
  ) => ctx.db.transaction(() async {
    final dao = ProjectDao(ctx.db);
    final row = await dao.byLocalId(localId);
    if (row == null) return;
    final remaining = DirtyFields.decode(row.dirtyFields).clearSent(sent);
    final snapshot = _snapshot(dto);
    final localByUid = await ctx.ids.localIdsByUid(SyncEntity.area);
    // Take the server's value for every field that is not dirty any more.
    final local = _local(row, await _areaUids(ctx.db));
    final values = {
      for (final f in ProjectFields.all)
        f: remaining.isDirty(f) ? local[f] : snapshot[f],
    };
    // A response without area info must not unlink a project we just linked.
    if (snapshot[ProjectFields.areaUid] == null &&
        sent.containsKey(ProjectFields.areaUid) &&
        row.areaLocalId != null &&
        row.areaLocalId != '') {
      values[ProjectFields.areaUid] = local[ProjectFields.areaUid];
    }
    await dao.upsert(
      _columns(
        values,
        _areaLocalId(
          values[ProjectFields.areaUid],
          row.areaLocalId,
          localByUid,
        ),
      ).copyWith(
        localId: Value(localId),
        uid: Value(dto.uid),
        serverId: Value(dto.id),
        serverCreatedAt: Value.absentIfNull(_date(dto.createdAt)),
        serverUpdatedAt: Value(_date(dto.updatedAt) ?? ctx.serverNow),
        imageUrl: Value(dto.imageUrl),
        taskCount: Value(dto.taskCount),
        completedTaskCount: Value(dto.completedTaskCount),
        baseJson: Value(BaseJson.encode(snapshot)),
        dirtyFields: Value(remaining.encode()),
      ),
    );
    if (remaining.isNotEmpty) {
      await ctx.db.outboxDao.enqueue(
        entity: entity,
        localId: localId,
        op: OutboxOp.update,
        now: ctx.now,
      );
    }
  });

  @override
  Future<void> rollback(SyncContext ctx, OutboxEntry e, ApiError error) async {
    final dao = ProjectDao(ctx.db);
    final row = await dao.byLocalId(e.localId);
    if (row == null) return;
    final base = BaseJson.decode(row.baseJson);
    if (row.uid == null || base == null || error is NotFoundError) {
      await ctx.db.deleteEntityRow(entity, e.localId);
    } else {
      final localByUid = await ctx.ids.localIdsByUid(SyncEntity.area);
      await dao.upsert(
        _columns(
          base,
          _areaLocalId(base[ProjectFields.areaUid], null, localByUid),
        ).copyWith(
          localId: Value(row.localId),
          dirtyFields: const Value('{}'),
          pendingDelete: const Value(false),
        ),
      );
    }
    ctx.notice(
      ConflictNotice.rolledBack(
        entity: entity,
        localId: e.localId,
        message: error.message,
      ),
    );
  }
}
