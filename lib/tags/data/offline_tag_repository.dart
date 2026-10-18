import 'package:drift/drift.dart';

import '../../core/api/api_error.dart';
import '../../core/api/patch.dart' as p;
import '../../core/db/app_database.dart';
import '../../core/db/dirty_fields.dart';
import '../../core/db/entity_access.dart';
import '../../core/ids.dart';
import '../domain/tag.dart';
import 'tag_dao.dart';
import 'tag_patch.dart';
import 'tag_repository.dart';

/// Tags backed by the local database. Every write is one transaction with its
/// outbox entry; `TagSyncHandler` sends it later.
///
/// `identifier` arguments accept a uid, a local id or a name (matched
/// case-insensitively), in that order of preference.
class OfflineTagRepository implements TagRepository {
  OfflineTagRepository(this._db, {DateTime Function()? now})
    : _now = now ?? (() => DateTime.now().toUtc()),
      _dao = TagDao(_db);

  final AppDatabase _db;
  final DateTime Function() _now;
  final TagDao _dao;

  /// Live list of the visible tags, sorted by name.
  Stream<List<Tag>> watchList() => _dao.watchAll();

  @override
  Future<List<Tag>> list() async => [
    for (final r in await _dao.allRows()) TagDao.toDomain(r),
  ];

  @override
  Future<Tag> get({TagUid? uid, String? name}) async {
    final row = uid != null
        ? await _dao.byUid(uid.value)
        : (name == null ? null : await _dao.byName(name));
    if (row == null || row.pendingDelete) {
      throw const NotFoundError('Tag not found');
    }
    return TagDao.toDomain(row);
  }

  @override
  Future<Tag> create(String name) => _db.transaction(() async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const ValidationError('Tag name is required');
    final existing = await _dao.byName(trimmed);
    if (existing != null) return TagDao.toDomain(existing);
    final now = _now().toUtc();
    final id = await _dao.insertNew(trimmed, now);
    await _db.outboxDao.enqueue(
      entity: SyncEntity.tag,
      localId: id,
      op: OutboxOp.create,
      now: now,
    );
    return TagDao.toDomain((await _dao.byLocalId(id))!);
  });

  @override
  Future<Tag> update(String identifier, TagPatch patch) => _db.transaction(
    () async {
      final row = await _dao.byIdentifier(identifier);
      if (row == null || row.pendingDelete) {
        throw const NotFoundError('Tag not found');
      }
      final now = _now().toUtc();
      final ms = now.millisecondsSinceEpoch;
      var dirty = DirtyFields.decode(row.dirtyFields);
      var companion = const TagsCompanion();
      var changed = false;

      final nameP = patch.name;
      if (nameP is p.Set<String>) {
        final name = (nameP.value ?? '').trim();
        if (name.isEmpty) throw const ValidationError('Tag name is required');
        if (name != row.name) {
          final other = await _dao.byName(name);
          if (other != null && other.localId != row.localId) {
            throw const ValidationError('Tag already exists', statusCode: 409);
          }
          companion = companion.copyWith(name: Value(name));
          dirty = dirty.mark('name', ms);
          changed = true;
        }
      }
      final colorP = patch.color;
      if (colorP is p.Set<String> && colorP.value != row.color) {
        companion = companion.copyWith(color: Value(colorP.value));
        dirty = dirty.mark('color', ms);
        changed = true;
      }
      final pinnedP = patch.pinned;
      if (pinnedP is p.Set<bool> && (pinnedP.value ?? false) != row.pinned) {
        companion = companion.copyWith(pinned: Value(pinnedP.value ?? false));
        dirty = dirty.mark('pinned', ms);
        changed = true;
      }
      if (!changed) return TagDao.toDomain(row);

      await _dao.write(
        row.localId,
        companion.copyWith(
          dirtyFields: Value(dirty.encode()),
          localUpdatedAt: Value(now),
        ),
      );
      await _enqueueChange(row, now);
      return TagDao.toDomain((await _dao.byLocalId(row.localId))!);
    },
  );

  /// A tag the server knows gets an `update`. One it has never seen (its uid
  /// is null) only needs a `create`, unless one is queued already: the push
  /// reads the row at send time.
  Future<void> _enqueueChange(TagRow row, DateTime now) async {
    if (row.uid != null) {
      await _db.outboxDao.enqueue(
        entity: SyncEntity.tag,
        localId: row.localId,
        op: OutboxOp.update,
        now: now,
      );
      return;
    }
    final queued =
        await (_db.select(_db.outbox)..where(
              (o) =>
                  o.entity.equals(SyncEntity.tag) &
                  o.localId.equals(row.localId),
            ))
            .get();
    if (queued.isEmpty) {
      await _db.outboxDao.enqueue(
        entity: SyncEntity.tag,
        localId: row.localId,
        op: OutboxOp.create,
        now: now,
      );
    }
  }

  @override
  Future<void> delete(String identifier) => _db.transaction(() async {
    final row = await _dao.byIdentifier(identifier);
    if (row == null || row.pendingDelete) {
      throw const NotFoundError('Tag not found');
    }
    final now = _now().toUtc();
    await _dao.removeJoins(row.localId);
    final queued =
        await (_db.select(_db.outbox)..where(
              (o) =>
                  o.entity.equals(SyncEntity.tag) &
                  o.localId.equals(row.localId),
            ))
            .get();
    if (row.uid == null && queued.isEmpty) {
      // Only ever existed here.
      await _db.deleteEntityRow(SyncEntity.tag, row.localId);
      return;
    }
    await _dao.markPendingDelete(row.localId, now);
    await _db.outboxDao.enqueue(
      entity: SyncEntity.tag,
      localId: row.localId,
      op: OutboxOp.delete,
      now: now,
    );
  });
}
