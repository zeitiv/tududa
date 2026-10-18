import 'package:drift/drift.dart';

import '../../core/api/api_error.dart';
import '../../core/api/patch.dart' as pt;
import '../../core/db/app_database.dart';
import '../../core/db/dirty_fields.dart';
import '../../core/db/entity_access.dart';
import '../../core/ids.dart';
import '../../core/sync/merge.dart';
import '../../core/sync/sync_handler.dart';
import '../../projects/data/project_dao.dart';
import 'area_api.dart';
import 'area_dao.dart';
import 'area_dto.dart';

/// Syncs areas (`/areas`, `/areas/:uid`). Register before the project
/// handler (the engine orders by `SyncEntity.pullOrder`).
class AreaSyncHandler extends SyncHandler {
  @override
  String get entity => SyncEntity.area;

  static Map<String, dynamic> _snapshot(AreaDto d) => {
    AreaFields.name: d.name,
    AreaFields.description: d.description,
  };

  static Map<String, dynamic> _local(AreaRow r) => {
    AreaFields.name: r.name,
    AreaFields.description: r.description,
  };

  @override
  Future<void> pull(SyncContext ctx) async {
    await _apply(ctx, await AreaApi(ctx.dio).list());
  }

  @override
  Future<void> fullReconcile(SyncContext ctx) async {
    final dtos = await AreaApi(ctx.dio).list();
    await _apply(ctx, dtos);
    final serverUids = {for (final d in dtos) d.uid};
    await ctx.db.removeCleanMissing(entity, serverUids);

    // Deleted locally and already gone on the server: nothing left to push.
    final hidden = await (ctx.db.select(
      ctx.db.areas,
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

  Future<void> _apply(SyncContext ctx, List<AreaDto> dtos) =>
      ctx.db.transaction(() async {
        final dao = AreaDao(ctx.db);
        for (final d in dtos) {
          final snapshot = _snapshot(d);
          final serverUpdated = d.updatedAtDate ?? ctx.serverNow;
          final row = await dao.byUid(d.uid);
          if (row == null) {
            await dao.upsert(
              AreasCompanion.insert(
                localId: LocalId.generate().value,
                uid: Value(d.uid),
                serverId: Value(d.id),
                serverCreatedAt: Value(d.createdAtDate),
                serverUpdatedAt: Value(serverUpdated),
                localUpdatedAt: Value(ctx.now),
                name: Value(d.name),
                description: Value(d.description),
                projectCount: Value(d.projectCount),
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
              _local(row),
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
            AreasCompanion(
              localId: Value(row.localId),
              serverId: Value(d.id),
              serverCreatedAt: Value.absentIfNull(d.createdAtDate),
              serverUpdatedAt: Value(serverUpdated),
              name: Value(values[AreaFields.name] as String? ?? ''),
              description: Value(values[AreaFields.description] as String?),
              projectCount: Value(d.projectCount),
              baseJson: Value(BaseJson.encode(snapshot)),
              dirtyFields: Value(remaining.encode()),
            ),
          );
        }
      });

  @override
  Future<PushResult> push(SyncContext ctx, OutboxEntry e) async {
    final dao = AreaDao(ctx.db);
    final api = AreaApi(ctx.dio);
    final row = await dao.byLocalId(e.localId);

    if (e.op == OutboxOp.delete) {
      if (row == null) return PushResult.dropped;
      final uid = row.uid;
      if (uid != null) {
        try {
          await api.delete(AreaUid(uid));
        } on NotFoundError {
          // Already gone: the goal is reached.
        }
      }
      await ctx.db.deleteEntityRow(entity, e.localId);
      return uid == null ? PushResult.dropped : PushResult.ok;
    }
    if (row == null || row.pendingDelete) return PushResult.dropped;

    final dirty = DirtyFields.decode(row.dirtyFields);
    final AreaDto dto;
    final Set<String> sentFields;
    if (e.op == OutboxOp.create && row.uid == null) {
      sentFields = {...AreaFields.all};
      dto = await api.create(
        NewArea(name: row.name, description: row.description),
      );
    } else {
      if (row.uid == null) return PushResult.waitForDependency;
      sentFields = dirty.fields.intersection({...AreaFields.all});
      if (sentFields.isEmpty) return PushResult.dropped;
      dto = await api.update(
        AreaUid(row.uid!),
        AreaPatch(
          name: sentFields.contains(AreaFields.name)
              ? pt.Patch.set(row.name)
              : const pt.Patch.unset(),
          description: sentFields.contains(AreaFields.description)
              ? (row.description == null
                    ? const pt.Patch.clear()
                    : pt.Patch.set(row.description!))
              : const pt.Patch.unset(),
        ),
      );
    }
    final sent = {for (final f in sentFields) f: ?dirty.editedAt(f)};
    await _applyPushed(ctx, e.localId, dto, sent);
    return PushResult.ok;
  }

  /// Stores the server's answer: uid, ids, timestamps, a fresh `base_json`;
  /// clears the dirty fields that were sent (not those edited meanwhile).
  Future<void> _applyPushed(
    SyncContext ctx,
    String localId,
    AreaDto dto,
    Map<String, int> sent,
  ) => ctx.db.transaction(() async {
    final dao = AreaDao(ctx.db);
    final row = await dao.byLocalId(localId);
    if (row == null) return;
    final remaining = DirtyFields.decode(row.dirtyFields).clearSent(sent);
    await dao.upsert(
      AreasCompanion(
        localId: Value(localId),
        uid: Value(dto.uid),
        serverId: Value(dto.id),
        serverCreatedAt: Value.absentIfNull(dto.createdAtDate),
        serverUpdatedAt: Value(dto.updatedAtDate ?? ctx.serverNow),
        name: remaining.isDirty(AreaFields.name)
            ? const Value.absent()
            : Value(dto.name),
        description: remaining.isDirty(AreaFields.description)
            ? const Value.absent()
            : Value(dto.description),
        projectCount: Value(dto.projectCount),
        baseJson: Value(BaseJson.encode(_snapshot(dto))),
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
    final dao = AreaDao(ctx.db);
    final row = await dao.byLocalId(e.localId);
    if (row == null) return;
    final base = BaseJson.decode(row.baseJson);
    await ctx.db.transaction(() async {
      if (row.uid == null || base == null || error is NotFoundError) {
        // Never reached the server (or is gone): projects must not keep
        // waiting for this area.
        final now = ctx.now;
        for (final p in await ProjectDao(ctx.db).inArea(row.localId)) {
          await ProjectDao(ctx.db).editFields(
            p.localId,
            const ProjectsCompanion(areaLocalId: Value(null)),
            dirty: const [ProjectFields.areaUid],
            now: now,
          );
        }
        await ctx.db.deleteEntityRow(entity, e.localId);
      } else {
        await dao.upsert(
          AreasCompanion(
            localId: Value(row.localId),
            name: Value(base[AreaFields.name] as String? ?? ''),
            description: Value(base[AreaFields.description] as String?),
            dirtyFields: const Value('{}'),
            pendingDelete: const Value(false),
          ),
        );
      }
    });
    ctx.notice(
      ConflictNotice.rolledBack(
        entity: entity,
        localId: e.localId,
        message: error.message,
      ),
    );
  }
}
