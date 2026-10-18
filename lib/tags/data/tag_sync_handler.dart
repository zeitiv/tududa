import 'package:drift/drift.dart';

import '../../core/api/api_error.dart';
import '../../core/api/patch.dart' as p;
import '../../core/db/app_database.dart';
import '../../core/db/dirty_fields.dart';
import '../../core/db/entity_access.dart';
import '../../core/ids.dart';
import '../../core/sync/merge.dart';
import '../../core/sync/sync_handler.dart';
import 'dto/tag_dto.dart';
import 'tag_dao.dart';
import 'tag_patch.dart';
import 'tags_api.dart';

/// Syncs `SyncEntity.tag`. Register it in `syncHandlersProvider`.
///
/// Tags have a small full list, so [pull] and [fullReconcile] both fetch
/// everything; only [fullReconcile] removes clean tags the server dropped.
/// Rows are matched by uid, else (to adopt tags created implicitly with a
/// note or task) by name. Join rows reference local ids, so a rename only
/// changes the `tags` row.
class TagSyncHandler extends SyncHandler {
  @override
  String get entity => SyncEntity.tag;

  static Map<String, dynamic> snapshotOfDto(TagDto d) => {
    'name': d.name,
    'color': d.color,
    'pinned': d.pinned ?? false,
  };

  static Map<String, dynamic> snapshotOfRow(TagRow r) => {
    'name': r.name,
    'color': r.color,
    'pinned': r.pinned,
  };

  @override
  Future<void> pull(SyncContext ctx) => _pull(ctx, full: false);

  @override
  Future<void> fullReconcile(SyncContext ctx) => _pull(ctx, full: true);

  Future<void> _pull(SyncContext ctx, {required bool full}) async {
    final dtos = await TagsApi(ctx.dio).list();
    final dao = TagDao(ctx.db);
    await ctx.db.transaction(() async {
      for (final d in dtos) {
        await _apply(ctx, dao, d);
      }
      if (full) {
        final gone = await ctx.db.removeCleanMissing(entity, {
          for (final d in dtos)
            if (d.uid != null) d.uid!.value,
        });
        for (final id in gone) {
          await dao.removeJoins(id);
        }
      }
      await _pruneUnused(ctx.db, dao);
    });
  }

  /// Tags that only exist locally because a note or task named them, and
  /// that nothing references any more.
  Future<void> _pruneUnused(AppDatabase db, TagDao dao) async {
    final rows =
        await (db.select(db.tags)..where(
              (t) =>
                  t.uid.isNull() &
                  t.pendingDelete.equals(false) &
                  t.dirtyFields.equals('{}'),
            ))
            .get();
    for (final r in rows) {
      final queued =
          await (db.select(db.outbox)..where(
                (o) => o.entity.equals(entity) & o.localId.equals(r.localId),
              ))
              .get();
      if (queued.isEmpty && !await dao.isReferenced(r.localId)) {
        await db.deleteEntityRow(entity, r.localId);
      }
    }
  }

  Future<void> _apply(SyncContext ctx, TagDao dao, TagDto d) async {
    final uid = d.uid?.value;
    if (uid == null) return;
    final snapshot = snapshotOfDto(d);
    final serverUpdated = d.updatedAt ?? ctx.serverNow;

    var row = await dao.byUid(uid);
    if (row == null) {
      final byName = await dao.byName(d.name);
      if (byName != null && byName.uid == null) row = byName;
    }
    if (row == null) {
      await dao.upsert(
        TagsCompanion.insert(
          localId: LocalId.generate().value,
          uid: Value(uid),
          serverId: Value(d.id),
          name: Value(d.name),
          color: Value(d.color),
          pinned: Value(d.pinned ?? false),
          serverCreatedAt: Value(d.createdAt),
          serverUpdatedAt: Value(d.updatedAt),
          localUpdatedAt: Value(d.updatedAt ?? ctx.now),
          baseJson: Value(BaseJson.encode(snapshot)),
        ),
      );
      return;
    }
    if (row.pendingDelete) return; // the queued delete wins

    final dirty = DirtyFields.decode(row.dirtyFields);
    var merged = snapshot;
    var newDirty = dirty;
    if (dirty.isEmpty) {
      final same =
          row.uid == uid &&
          row.name == d.name &&
          row.color == d.color &&
          row.pinned == (d.pinned ?? false) &&
          _sameInstant(row.serverUpdatedAt, d.updatedAt);
      if (same) return;
    } else {
      final result = mergeFields(
        BaseJson.decode(row.baseJson),
        snapshotOfRow(row),
        snapshot,
        dirty.toMap(),
        entity: entity,
        localId: row.localId,
        serverUpdatedAt: serverUpdated,
        skew: ctx.skew,
        setFields: const {},
      );
      result.notices.forEach(ctx.notice);
      merged = result.value;
      newDirty = DirtyFields(result.dirtyFields);
    }
    await dao.write(
      row.localId,
      TagsCompanion(
        uid: Value(uid),
        serverId: Value(d.id),
        name: Value(merged['name'] as String? ?? row.name),
        color: Value(merged['color'] as String?),
        pinned: Value(merged['pinned'] as bool? ?? false),
        serverCreatedAt: Value(d.createdAt),
        serverUpdatedAt: Value(d.updatedAt),
        localUpdatedAt: Value(d.updatedAt ?? ctx.now),
        dirtyFields: Value(newDirty.encode()),
        baseJson: Value(BaseJson.encode(snapshot)),
      ),
    );
  }

  static bool _sameInstant(DateTime? a, DateTime? b) =>
      a == null || b == null ? a == b : a.isAtSameMomentAs(b);

  @override
  Future<PushResult> push(SyncContext ctx, OutboxEntry e) async {
    final dao = TagDao(ctx.db);
    final api = TagsApi(ctx.dio);
    final row = await dao.byLocalId(e.localId);

    if (e.op == OutboxOp.delete) {
      if (row == null) return PushResult.dropped;
      final uid = row.uid;
      if (uid != null) {
        try {
          await api.delete(uid);
        } on NotFoundError {
          // Already gone: the goal is reached.
        }
      }
      await ctx.db.transaction(() async {
        await dao.removeJoins(e.localId);
        await ctx.db.deleteEntityRow(entity, e.localId);
      });
      return PushResult.ok;
    }
    if (row == null) return PushResult.dropped;

    var dirty = DirtyFields.decode(row.dirtyFields);
    final sent = dirty.toMap();
    TagDto dto;
    if (e.op == OutboxOp.create && row.uid == null) {
      try {
        dto = await api.create(row.name);
      } on ValidationError catch (err) {
        if (err.statusCode != 409) rethrow;
        // The server has it already (e.g. created with a note): adopt it.
        dto = await api.get(name: row.name);
      }
      final extra = TagPatch(
        color: row.color != null && row.color != dto.color
            ? p.Patch.set(row.color!)
            : const p.Patch.unset(),
        pinned: row.pinned != (dto.pinned ?? false)
            ? p.Patch.set(row.pinned)
            : const p.Patch.unset(),
      );
      if (extra.toJson().isNotEmpty) {
        dto = await api.update(dto.uid?.value ?? row.name, extra);
      }
    } else {
      final uid = row.uid;
      if (uid == null) return PushResult.waitForDependency;
      final patch = TagPatch(
        name: dirty.isDirty('name')
            ? p.Patch.set(row.name)
            : const p.Patch.unset(),
        color: dirty.isDirty('color')
            ? (row.color == null
                  ? const p.Patch.clear()
                  : p.Patch.set(row.color!))
            : const p.Patch.unset(),
        pinned: dirty.isDirty('pinned')
            ? p.Patch.set(row.pinned)
            : const p.Patch.unset(),
      );
      if (patch.toJson().isEmpty) return PushResult.dropped;
      dto = await api.update(uid, patch);
    }

    await ctx.db.transaction(() async {
      final fresh = await dao.byLocalId(e.localId);
      if (fresh == null) return;
      dirty = DirtyFields.decode(fresh.dirtyFields).clearSent(sent);
      await dao.write(
        e.localId,
        TagsCompanion(
          uid: Value(dto.uid?.value ?? fresh.uid),
          serverId: Value(dto.id ?? fresh.serverId),
          serverCreatedAt: Value(dto.createdAt ?? fresh.serverCreatedAt),
          serverUpdatedAt: Value(dto.updatedAt ?? ctx.serverNow),
          dirtyFields: Value(dirty.encode()),
          baseJson: Value(BaseJson.encode(snapshotOfDto(dto))),
        ),
      );
    });
    return PushResult.ok;
  }

  @override
  Future<void> rollback(SyncContext ctx, OutboxEntry e, ApiError error) async {
    final dao = TagDao(ctx.db);
    final row = await dao.byLocalId(e.localId);
    if (row == null) return;
    final base = BaseJson.decode(row.baseJson);
    await ctx.db.transaction(() async {
      if (row.uid == null || base == null || error is NotFoundError) {
        await dao.removeJoins(row.localId);
        await ctx.db.deleteEntityRow(entity, row.localId);
      } else {
        await dao.write(
          row.localId,
          TagsCompanion(
            name: Value('${base['name'] ?? row.name}'),
            color: Value(base['color'] as String?),
            pinned: Value(base['pinned'] as bool? ?? false),
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
