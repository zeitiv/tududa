import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../../core/api/api_error.dart';
import '../../core/db/app_database.dart';
import '../../core/db/dirty_fields.dart';
import '../../core/db/entity_access.dart';
import '../../core/ids.dart';
import '../../core/sync/merge.dart';
import '../../core/sync/pull_paged.dart';
import '../../core/sync/sync_handler.dart';
import 'inbox_api.dart';
import 'inbox_dao.dart';
import '../domain/inbox_item.dart';
import 'inbox_dto.dart';

const _pageSize = 100;

/// Fields the server owns for an inbox item; the keys of `base_json` and of
/// the dirty set.
Map<String, dynamic> _fields({
  required String content,
  required String status,
  required String source,
}) => {'content': content, 'status': status, 'source': source};

/// Writes server rows into `inbox_items`: unknown uids are inserted, clean
/// rows overwritten, rows with local edits merged field by field. Rows that
/// are pending delete are left alone (the delete is still queued); processed
/// or deleted rows the server still returns are ignored.
///
/// Shared by the sync handler and by the provider's `loadMore` (which pages
/// the server directly). [onNotice] receives automatically resolved
/// conflicts.
Future<void> applyServerInboxItems(
  AppDatabase db,
  List<InboxItemDto> items, {
  required DateTime now,
  Duration skew = Duration.zero,
  void Function(ConflictNotice)? onNotice,
}) async {
  final dao = InboxDao(db);
  // One transaction per page: the list stream emits once, not per row.
  await db.transaction(() async {
    for (final dto in items) {
      await _applyOne(db, dao, dto, now, skew, onNotice);
    }
  });
}

Future<void> _applyOne(
  AppDatabase db,
  InboxDao dao,
  InboxItemDto dto,
  DateTime now,
  Duration skew,
  void Function(ConflictNotice)? onNotice,
) async {
  final uid = dto.uid.value;
  final existing = await dao.byUid(uid);
  final serverStatus = dto.status ?? 'added';
  final content = dto.content.isNotEmpty ? dto.content : (dto.title ?? '');
  final source = dto.source ?? 'manual';
  final snapshot = _fields(
    content: content,
    status: serverStatus,
    source: source,
  );
  if (existing == null) {
    if (serverStatus == 'processed' || serverStatus == 'deleted') return;
    await dao.upsert(
      InboxItemsCompanion.insert(
        localId: LocalId.generate().value,
        uid: Value(uid),
        content: Value(content),
        title: Value(dto.title),
        status: Value(serverStatus),
        source: Value(source),
        serverCreatedAt: Value(dto.createdAt),
        serverUpdatedAt: Value(dto.updatedAt),
        localUpdatedAt: Value(now),
        baseJson: Value(BaseJson.encode(snapshot)),
      ),
    );
    return;
  }
  if (existing.pendingDelete) return;

  final dirty = DirtyFields.decode(existing.dirtyFields);
  var merged = snapshot;
  var newDirty = dirty;
  if (dirty.isNotEmpty) {
    final result = mergeFields(
      BaseJson.decode(existing.baseJson),
      _fields(
        content: existing.content,
        status: existing.status,
        source: existing.source,
      ),
      snapshot,
      dirty.toMap(),
      entity: SyncEntity.inbox,
      localId: existing.localId,
      serverUpdatedAt: dto.updatedAt ?? now,
      skew: skew,
    );
    result.notices.forEach(onNotice ?? (_) {});
    merged = result.value;
    newDirty = DirtyFields(result.dirtyFields);
  }
  await dao.updateRow(
    existing.localId,
    InboxItemsCompanion(
      content: Value('${merged['content']}'),
      title: Value(dto.title),
      status: Value('${merged['status']}'),
      source: Value('${merged['source']}'),
      serverCreatedAt: Value(dto.createdAt ?? existing.serverCreatedAt),
      serverUpdatedAt: Value(dto.updatedAt ?? existing.serverUpdatedAt),
      dirtyFields: Value(newDirty.encode()),
      baseJson: Value(BaseJson.encode(snapshot)),
    ),
  );
}

/// Sync handler of the inbox (`SyncEntity.inbox`).
///
/// - pull: `GET /inbox?limit&offset`, all pages. The server lists newest
///   *created* first (not by `updated_at`), so the `pullPaged` stop rule is
///   unusable and every pull reads the whole list (an inbox is small).
///   Processed and deleted items are hidden server-side.
/// - push: create `POST /inbox`, update (ignore) `PATCH /inbox/:uid`,
///   delete (soft) `DELETE /inbox/:uid`, `inbox_process`
///   `PATCH /inbox/:uid/process` with the target resolved to a uid now.
class InboxSyncHandler extends SyncHandler {
  @override
  String get entity => SyncEntity.inbox;

  @override
  Future<void> pull(SyncContext ctx) => _pullAll(ctx);

  @override
  Future<void> fullReconcile(SyncContext ctx) async {
    final uids = await _pullAll(ctx);
    await ctx.db.removeCleanMissing(SyncEntity.inbox, uids);
  }

  Future<Set<String>> _pullAll(SyncContext ctx) async {
    final api = InboxApi(ctx.dio);
    final uids = <String>{};
    await pullPaged<InboxItemDto>(
      fetch: (offset) => api.list(limit: _pageSize, offset: offset),
      updatedAt: (d) => d.updatedAt,
      onPage: (items) async {
        uids.addAll(items.map((d) => d.uid.value));
        await applyServerInboxItems(
          ctx.db,
          items,
          now: ctx.now,
          skew: ctx.skew,
          onNotice: ctx.notice,
        );
      },
    );
    return uids;
  }

  @override
  Future<PushResult> push(SyncContext ctx, OutboxEntry e) async {
    final dao = InboxDao(ctx.db);
    final api = InboxApi(ctx.dio);
    final row = await dao.byLocalId(e.localId);

    if (e.op == OutboxOp.delete) {
      final uid = row?.uid;
      if (row == null) return PushResult.dropped;
      if (uid != null) {
        try {
          await api.delete(InboxUid(uid));
        } on NotFoundError {
          // Already gone: the goal is reached.
        }
      }
      await ctx.db.deleteEntityRow(SyncEntity.inbox, e.localId);
      return PushResult.ok;
    }
    if (row == null) return PushResult.dropped;

    switch (e.op) {
      case OutboxOp.create:
        return _create(ctx, dao, api, row);
      case OutboxOp.update:
        return _update(ctx, dao, api, row);
      case OutboxOp.inboxProcess:
        return _process(ctx, api, row, e);
      default:
        return PushResult.dropped;
    }
  }

  Future<PushResult> _create(
    SyncContext ctx,
    InboxDao dao,
    InboxApi api,
    InboxRow row,
  ) async {
    final dirty = DirtyFields.decode(row.dirtyFields);
    final sent = {
      for (final f in const ['content', 'source'])
        if (dirty.editedAt(f) != null) f: dirty.editedAt(f)!,
    };
    final dto = await api.create(row.content, source: row.source);
    // Persist the uid before anything else can fail.
    await dao.updateRow(
      row.localId,
      InboxItemsCompanion(
        uid: Value(dto.uid.value),
        serverCreatedAt: Value(dto.createdAt ?? row.serverCreatedAt),
        serverUpdatedAt: Value(dto.updatedAt),
        dirtyFields: Value(dirty.clearSent(sent).encode()),
        baseJson: Value(
          BaseJson.encode(
            _fields(
              content: dto.content.isNotEmpty ? dto.content : row.content,
              status: dto.status ?? 'added',
              source: dto.source ?? row.source,
            ),
          ),
        ),
      ),
    );
    // "Ignore" on a not yet created item was absorbed into the create.
    final fresh = await dao.byLocalId(row.localId);
    if (fresh != null && fresh.status == 'ignored') {
      return _update(ctx, dao, api, fresh);
    }
    return PushResult.ok;
  }

  Future<PushResult> _update(
    SyncContext ctx,
    InboxDao dao,
    InboxApi api,
    InboxRow row,
  ) async {
    final uid = row.uid;
    if (uid == null) return PushResult.waitForDependency;
    // A processed item is sent by its inbox_process entry.
    if (row.status == 'processed') return PushResult.dropped;
    final dirty = DirtyFields.decode(row.dirtyFields);
    final fields = [
      for (final f in const ['content', 'status'])
        if (dirty.isDirty(f)) f,
    ];
    if (fields.isEmpty) return PushResult.dropped;
    final dto = await api.update(
      InboxUid(uid),
      content: fields.contains('content') ? row.content : null,
      status: fields.contains('status') ? InboxStatus.parse(row.status) : null,
    );
    // Re-read: the row may have been edited while the request was in flight.
    final fresh = await dao.byLocalId(row.localId);
    if (fresh == null) return PushResult.ok;
    await dao.updateRow(
      row.localId,
      InboxItemsCompanion(
        serverUpdatedAt: Value(dto.updatedAt ?? fresh.serverUpdatedAt),
        dirtyFields: Value(
          DirtyFields.decode(fresh.dirtyFields)
              .clearSent({for (final f in fields) f: dirty.editedAt(f)!})
              .encode(),
        ),
        baseJson: Value(
          BaseJson.encode(
            _fields(
              content: dto.content.isNotEmpty ? dto.content : row.content,
              status: dto.status ?? row.status,
              source: dto.source ?? row.source,
            ),
          ),
        ),
      ),
    );
    return PushResult.ok;
  }

  Future<PushResult> _process(
    SyncContext ctx,
    InboxApi api,
    InboxRow row,
    OutboxEntry e,
  ) async {
    final uid = row.uid;
    if (uid == null) return PushResult.waitForDependency;
    final target = await _resolveTarget(ctx, e.extraJson);
    await api.process(InboxUid(uid), target: target);
    await ctx.db.deleteEntityRow(SyncEntity.inbox, row.localId);
    return PushResult.ok;
  }

  /// `{task_uid|project_uid|note_uid: ref}` -> a target holding the server
  /// uid. [ref] is a server uid or the local id of a row that may not have
  /// been created yet (throws `DependencyPendingException` then).
  Future<InboxProcessTarget?> _resolveTarget(
    SyncContext ctx,
    String? extraJson,
  ) async {
    if (extraJson == null) return null;
    final raw = jsonDecode(extraJson);
    if (raw is! Map || raw.isEmpty) return null;
    final key = raw.keys.first as String;
    final ref = '${raw[key]}';
    final entity = switch (key) {
      'task_uid' => SyncEntity.task,
      'project_uid' => SyncEntity.project,
      'note_uid' => SyncEntity.note,
      _ => null,
    };
    if (entity == null) return null;
    final String uid;
    if (await ctx.ids.localIdOfUid(entity, ref) != null) {
      uid = ref; // already a known server uid
    } else if (await ctx.db.entityExists(entity, ref)) {
      uid = await ctx.ids.requireUid(entity, ref);
    } else {
      uid = ref; // a server uid we have not pulled (yet)
    }
    return switch (key) {
      'task_uid' => ProcessedAsTask(uid),
      'project_uid' => ProcessedAsProject(uid),
      _ => ProcessedAsNote(uid),
    };
  }

  @override
  Future<void> rollback(SyncContext ctx, OutboxEntry e, ApiError error) async {
    final dao = InboxDao(ctx.db);
    final row = await dao.byLocalId(e.localId);
    if (row == null) return;
    final base = BaseJson.decode(row.baseJson);
    if (row.uid == null || base == null || error is NotFoundError) {
      // Never reached the server, or the server no longer has it.
      await ctx.db.deleteEntityRow(SyncEntity.inbox, e.localId);
    } else {
      await dao.updateRow(
        e.localId,
        InboxItemsCompanion(
          content: Value('${base['content'] ?? row.content}'),
          status: Value('${base['status'] ?? 'added'}'),
          source: Value('${base['source'] ?? row.source}'),
          dirtyFields: const Value('{}'),
          pendingDelete: const Value(false),
        ),
      );
    }
    ctx.notice(
      ConflictNotice.rolledBack(
        entity: SyncEntity.inbox,
        localId: e.localId,
        message: error.message,
      ),
    );
  }
}
