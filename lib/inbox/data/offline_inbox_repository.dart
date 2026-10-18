import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_providers.dart';
import '../../core/api/page.dart';
import '../../core/db/app_database.dart';
import '../../core/db/dirty_fields.dart';
import '../../core/ids.dart';
import '../domain/inbox_item.dart';
import 'inbox_api.dart';
import 'inbox_dao.dart';
import 'inbox_repository.dart';
import 'inbox_sync_handler.dart';

/// Inbox repository over the local database: every write is one transaction
/// of row change + outbox entry, so it works fully offline and the item shows
/// up at once. The sync engine (see `InboxSyncHandler`) does the rest.
///
/// Items are addressed by [InboxUid]; until the server assigned a uid the
/// value holds the item's local id (`InboxItem.uid` does the same), so every
/// method accepts either.
class OfflineInboxRepository implements InboxRepository {
  OfflineInboxRepository(this._db, this._api, {DateTime Function()? now})
    : _dao = InboxDao(_db),
      _now = now ?? (() => DateTime.now().toUtc());

  final AppDatabase _db;
  final InboxDao _dao;
  final InboxApi _api;
  final DateTime Function() _now;

  static InboxItem toItem(InboxRow r) => InboxItem(
    uid: InboxUid(r.uid ?? r.localId),
    content: r.content.isNotEmpty ? r.content : (r.title ?? ''),
    status: InboxStatus.parse(r.status),
    source: r.source,
    createdAt: r.serverCreatedAt ?? r.localUpdatedAt,
    updatedAt: r.serverUpdatedAt ?? r.localUpdatedAt,
  );

  /// Live visible items, newest first (no processed, no pending delete).
  Stream<List<InboxItem>> watch() =>
      _dao.watchAll().map((rows) => [for (final r in rows) toItem(r)]);

  /// Pages over the local rows.
  @override
  Future<Page<InboxItem>> list({int limit = 20, int offset = 0}) async {
    final rows = await _dao.visible(limit: limit, offset: offset);
    final total = await _dao.visibleCount();
    return Page(
      items: [for (final r in rows) toItem(r)],
      total: total,
      limit: limit,
      offset: offset,
      hasMore: offset + rows.length < total,
    );
  }

  /// Fetches one page from the server and merges it into the local rows
  /// (rows with local edits are merged, not overwritten). Throws `ApiError`
  /// while offline.
  Future<Page<InboxItem>> loadServerPage({
    int limit = 20,
    int offset = 0,
  }) async {
    final p = await _api.list(limit: limit, offset: offset);
    await applyServerInboxItems(_db, p.items, now: _now());
    return Page(
      items: [for (final d in p.items) d.toDomain()],
      total: p.total,
      limit: p.limit,
      offset: p.offset,
      hasMore: p.hasMore,
    );
  }

  @override
  Future<InboxItem> capture(String text, {String source = 'mobile'}) async {
    final id = LocalId.generate().value;
    final now = _now();
    await _db.transaction(() async {
      final dirty = const DirtyFields().markAll(const [
        'content',
        'source',
      ], now.millisecondsSinceEpoch);
      await _dao.upsert(
        InboxItemsCompanion.insert(
          localId: id,
          content: Value(text),
          source: Value(source),
          // Optimistic creation time (orders the list); the push replaces it
          // with the server's.
          serverCreatedAt: Value(now),
          localUpdatedAt: Value(now),
          dirtyFields: Value(dirty.encode()),
        ),
      );
      await _db.outboxDao.enqueue(
        entity: SyncEntity.inbox,
        localId: id,
        op: OutboxOp.create,
        now: now,
      );
    });
    return toItem((await _dao.byLocalId(id))!);
  }

  @override
  Future<InboxItem> setStatus(InboxUid uid, InboxStatus status) async {
    final now = _now();
    final id = await _db.transaction(() async {
      final row = await _require(uid);
      if (row.status != status.wire) {
        await _dao.updateRow(
          row.localId,
          InboxItemsCompanion(
            status: Value(status.wire),
            dirtyFields: Value(
              InboxDao.markDirty(row, const [
                'status',
              ], now.millisecondsSinceEpoch),
            ),
            localUpdatedAt: Value(now),
          ),
        );
        await _db.outboxDao.enqueue(
          entity: SyncEntity.inbox,
          localId: row.localId,
          op: OutboxOp.update,
          now: now,
        );
      }
      return row.localId;
    });
    return toItem((await _dao.byLocalId(id))!);
  }

  /// Ignore: status `ignored`, kept in the list.
  Future<InboxItem> ignore(InboxUid uid) => setStatus(uid, InboxStatus.ignored);

  /// Hides the item at once and queues the soft delete (or cancels a create
  /// that never left the device).
  @override
  Future<void> delete(InboxUid uid) async {
    final now = _now();
    await _db.transaction(() async {
      final row = await _dao.byRef(uid.value);
      if (row == null) return;
      await _dao.updateRow(
        row.localId,
        const InboxItemsCompanion(pendingDelete: Value(true)),
      );
      await _db.outboxDao.enqueue(
        entity: SyncEntity.inbox,
        localId: row.localId,
        op: OutboxOp.delete,
        now: now,
      );
    });
  }

  /// Marks the item processed (hidden) and queues `inbox_process`. The
  /// target's uid is resolved when the entry is pushed: it may be a task /
  /// project / note local id whose create has not been sent yet.
  @override
  Future<void> process(InboxUid uid, {InboxProcessTarget? target}) async {
    final now = _now();
    await _db.transaction(() async {
      final row = await _require(uid);
      await _dao.updateRow(
        row.localId,
        InboxItemsCompanion(
          status: const Value('processed'),
          dirtyFields: Value(
            InboxDao.markDirty(row, const [
              'status',
            ], now.millisecondsSinceEpoch),
          ),
          localUpdatedAt: Value(now),
        ),
      );
      await _db.outboxDao.enqueue(
        entity: SyncEntity.inbox,
        localId: row.localId,
        op: OutboxOp.inboxProcess,
        extraJson: target == null ? null : jsonEncode({target.key: target.uid}),
        now: now,
      );
    });
  }

  @override
  Future<InboxAnalysis> analyzeText(String text, {CancelToken? cancelToken}) =>
      _api.analyzeText(text, cancelToken: cancelToken);

  Future<InboxRow> _require(InboxUid uid) async =>
      await _dao.byRef(uid.value) ??
      (throw StateError('Unknown inbox item ${uid.value}'));
}

final inboxRepositoryProvider = Provider<OfflineInboxRepository>(
  (ref) => OfflineInboxRepository(
    ref.watch(appDatabaseProvider),
    InboxApi(ref.watch(dioProvider)),
  ),
);
