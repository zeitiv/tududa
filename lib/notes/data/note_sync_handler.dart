import 'package:drift/drift.dart';

import '../../core/api/api_error.dart';
import '../../core/api/patch.dart' as p;
import '../../core/db/app_database.dart';
import '../../core/db/dirty_fields.dart';
import '../../core/db/entity_access.dart';
import '../../core/ids.dart';
import '../../core/sync/merge.dart';
import '../../core/sync/sync_handler.dart';
import '../../tags/data/dto/tag_dto.dart';
import '../../tags/data/tag_dao.dart';
import '../../tags/data/tag_sync_handler.dart';
import 'dto/note_dto.dart';
import 'note_dao.dart';
import 'note_patch.dart';
import 'notes_api.dart';

/// Syncs `SyncEntity.note`. Register it in `syncHandlersProvider`, after (or
/// anywhere next to) `TagSyncHandler`; the engine orders the pulls itself.
///
/// - Pull is always the complete list. Clean rows are overwritten, rows with
///   unsent edits are merged field by field; when both sides changed `content`
///   the server text wins and the local text is kept as a new note called
///   `(conflict copy) <title>`, created through the normal create path.
/// - Push builds its body from the dirty fields at send time. The project's
///   uid is resolved then too (a project without uid makes the entry wait),
///   tags travel as names.
class NoteSyncHandler extends SyncHandler {
  @override
  String get entity => SyncEntity.note;

  /// Prefix of the title of a conflict copy.
  static const conflictCopyPrefix = '(conflict copy)';

  static Map<String, dynamic> snapshotOfDto(NoteDto d) => {
    NoteField.title: d.title,
    NoteField.content: d.content,
    NoteField.color: d.color,
    NoteField.projectUid: d.projectUid?.value ?? d.project?.uid?.value,
    NoteField.tags: [for (final t in d.tags ?? const <TagDto>[]) t.name],
  };

  @override
  Future<void> pull(SyncContext ctx) => _pull(ctx, full: false);

  @override
  Future<void> fullReconcile(SyncContext ctx) => _pull(ctx, full: true);

  Future<void> _pull(SyncContext ctx, {required bool full}) async {
    final dtos = await NotesApi(ctx.dio).list();
    final dao = NoteDao(ctx.db);
    await ctx.db.transaction(() async {
      final tags = await _TagIndex.load(ctx.db);
      for (final d in dtos) {
        await _apply(ctx, dao, tags, d);
      }
      if (full) {
        await ctx.db.removeCleanMissing(entity, {
          for (final d in dtos) d.uid.value,
        });
      }
    });
  }

  Future<void> _apply(
    SyncContext ctx,
    NoteDao dao,
    _TagIndex tags,
    NoteDto d,
  ) async {
    final uid = d.uid.value;
    final snapshot = snapshotOfDto(d);
    final serverProjectUid = snapshot[NoteField.projectUid] as String?;
    final serverProject = serverProjectUid == null
        ? null
        : await ctx.ids.localIdOfUid(SyncEntity.project, serverProjectUid);
    final serverTagIds = [
      for (final t in d.tags ?? const <TagDto>[])
        ?await tags.resolve(dao.tagDao, t, ctx.now),
    ];
    final serverUpdated = d.updatedAt ?? ctx.serverNow;

    final localId = await ctx.ids.localIdOfUid(entity, uid);
    if (localId == null) {
      final id = LocalId.generate().value;
      await dao.upsert(
        NotesCompanion.insert(
          localId: id,
          uid: Value(uid),
          serverId: Value(d.id),
          title: Value(d.title),
          content: Value(d.content),
          color: Value(d.color),
          projectLocalId: Value(serverProject),
          serverCreatedAt: Value(d.createdAt),
          serverUpdatedAt: Value(d.updatedAt),
          localUpdatedAt: Value(d.updatedAt ?? ctx.now),
          baseJson: Value(BaseJson.encode(snapshot)),
        ),
      );
      await dao.setTagIds(id, serverTagIds);
      return;
    }
    final row = (await dao.byLocalId(localId))!;
    if (row.pendingDelete) return; // the queued delete wins

    final dirty = DirtyFields.decode(row.dirtyFields);
    final currentTags = await dao.tagRowsOf(localId);

    if (dirty.isEmpty) {
      final same =
          row.title == d.title &&
          row.content == d.content &&
          row.color == d.color &&
          row.projectLocalId == serverProject &&
          _sameIds(currentTags.map((t) => t.localId), serverTagIds) &&
          _sameInstant(row.serverUpdatedAt, d.updatedAt);
      if (same) return;
      await dao.write(
        localId,
        NotesCompanion(
          serverId: Value(d.id),
          title: Value(d.title),
          content: Value(d.content),
          color: Value(d.color),
          projectLocalId: Value(serverProject),
          serverCreatedAt: Value(d.createdAt),
          serverUpdatedAt: Value(d.updatedAt),
          localUpdatedAt: Value(d.updatedAt ?? ctx.now),
          baseJson: Value(BaseJson.encode(snapshot)),
        ),
      );
      await dao.setTagIds(localId, serverTagIds);
      return;
    }

    // ---- three-way merge of a row with unsent edits ----
    final localProjectUid = row.projectLocalId == null
        ? null
        : await ctx.ids.uidOf(SyncEntity.project, row.projectLocalId!);
    final local = <String, dynamic>{
      NoteField.title: row.title,
      NoteField.content: row.content,
      NoteField.color: row.color,
      NoteField.projectUid: localProjectUid,
      NoteField.tags: [for (final t in currentTags) t.name],
    };
    final base = BaseJson.decode(row.baseJson);
    final server = Map<String, dynamic>.of(snapshot);
    final baseCopy = base == null ? null : Map<String, dynamic>.of(base);
    final dirtyMap = dirty.toMap();

    // Content is merged on its own (conflict copy); a project that has no uid
    // yet cannot be compared with the server and simply stays as it is.
    final contentDirty = dirty.isDirty(NoteField.content);
    final projectUnsynced =
        dirty.isDirty(NoteField.projectUid) &&
        row.projectLocalId != null &&
        localProjectUid == null;
    for (final field in [
      if (contentDirty) NoteField.content,
      if (projectUnsynced) NoteField.projectUid,
    ]) {
      local.remove(field);
      server.remove(field);
      baseCopy?.remove(field);
      dirtyMap.remove(field);
    }
    final merged = mergeFields(
      baseCopy,
      local,
      server,
      dirtyMap,
      entity: entity,
      localId: localId,
      serverUpdatedAt: serverUpdated,
      skew: ctx.skew,
    );
    merged.notices.forEach(ctx.notice);
    final newDirty = Map<String, int>.of(merged.dirtyFields);

    var content = row.content;
    String? conflictCopy;
    if (contentDirty) {
      final c = mergeNoteContent(
        base: base?[NoteField.content] as String?,
        local: row.content,
        server: d.content,
        dirtyFields: {NoteField.content: dirty.editedAt(NoteField.content)!},
        localId: localId,
      );
      c.notices.forEach(ctx.notice);
      content = c.value;
      conflictCopy = c.conflictCopy;
      if (c.dirtyFields.containsKey(NoteField.content)) {
        newDirty[NoteField.content] = c.dirtyFields[NoteField.content]!;
      }
    } else {
      content = merged.value[NoteField.content] as String?;
    }

    String? project;
    if (projectUnsynced) {
      project = row.projectLocalId;
      newDirty[NoteField.projectUid] = dirty.editedAt(NoteField.projectUid)!;
    } else {
      final uidValue = merged.value[NoteField.projectUid] as String?;
      project = uidValue == null
          ? null
          : await ctx.ids.localIdOfUid(SyncEntity.project, uidValue);
    }
    final tagIds = [
      for (final n in (merged.value[NoteField.tags] as List? ?? const []))
        ?await tags.byName('$n'),
    ];

    final remaining = DirtyFields(newDirty);
    await dao.write(
      localId,
      NotesCompanion(
        serverId: Value(d.id),
        title: Value(merged.value[NoteField.title] as String?),
        content: Value(content),
        color: Value(merged.value[NoteField.color] as String?),
        projectLocalId: Value(project),
        serverCreatedAt: Value(d.createdAt),
        serverUpdatedAt: Value(d.updatedAt),
        localUpdatedAt: remaining.isEmpty
            ? Value(d.updatedAt ?? ctx.now)
            : const Value.absent(),
        dirtyFields: Value(remaining.encode()),
        baseJson: Value(BaseJson.encode(snapshot)),
      ),
    );
    await dao.setTagIds(localId, tagIds);

    if (conflictCopy != null) {
      final id = await dao.insertNew(
        title: '$conflictCopyPrefix ${row.title ?? ''}'.trim(),
        content: conflictCopy,
        color: row.color,
        projectLocalId: row.projectLocalId,
        tagNames: [for (final t in currentTags) t.name],
        now: ctx.now,
      );
      await ctx.db.outboxDao.enqueue(
        entity: entity,
        localId: id,
        op: OutboxOp.create,
        now: ctx.now,
      );
    }
  }

  static bool _sameIds(Iterable<String> a, Iterable<String> b) {
    final x = a.toSet(), y = b.toSet();
    return x.length == y.length && x.containsAll(y);
  }

  static bool _sameInstant(DateTime? a, DateTime? b) =>
      a == null || b == null ? a == b : a.isAtSameMomentAs(b);

  @override
  Future<PushResult> push(SyncContext ctx, OutboxEntry e) async {
    final dao = NoteDao(ctx.db);
    final api = NotesApi(ctx.dio);
    final row = await dao.byLocalId(e.localId);

    if (e.op == OutboxOp.delete) {
      if (row == null) return PushResult.dropped;
      final uid = row.uid;
      if (uid != null) {
        try {
          await api.delete(NoteUid(uid));
        } on NotFoundError {
          // Already gone: the goal is reached.
        }
      }
      await ctx.db.deleteEntityRow(entity, e.localId);
      return uid == null ? PushResult.dropped : PushResult.ok;
    }
    if (row == null) return PushResult.dropped;

    final dirty = DirtyFields.decode(row.dirtyFields);
    final sent = dirty.toMap();
    // Resolved before anything is sent: throws DependencyPendingException
    // while the project is not on the server yet.
    final projectUid = row.projectLocalId == null
        ? null
        : await ctx.ids.requireUid(SyncEntity.project, row.projectLocalId!);

    final NoteDto dto;
    if (row.uid == null && e.op != OutboxOp.update) {
      final names = await dao.tagNamesOf(e.localId);
      dto = await api.create({
        'title': row.title,
        'content': row.content,
        'color': ?row.color,
        'project_uid': ?projectUid,
        if (names.isNotEmpty)
          'tags': [
            for (final n in names) {'name': n},
          ],
      });
    } else {
      final uid = row.uid;
      if (uid == null) return PushResult.waitForDependency;
      if (dirty.isEmpty) return PushResult.dropped;
      dto = await api.update(
        NoteUid(uid),
        NotePatch(
          title: _text(dirty, NoteField.title, row.title),
          content: _text(dirty, NoteField.content, row.content),
          color: _text(dirty, NoteField.color, row.color),
          projectUid: !dirty.isDirty(NoteField.projectUid)
              ? const p.Patch.unset()
              : projectUid == null
              ? const p.Patch.clear()
              : p.Patch.set(ProjectUid(projectUid)),
          tags: dirty.isDirty(NoteField.tags)
              ? p.Patch.set(await dao.tagNamesOf(e.localId))
              : const p.Patch.unset(),
        ),
      );
    }

    await ctx.db.transaction(() async {
      final fresh = await dao.byLocalId(e.localId);
      if (fresh == null) return;
      await dao.write(
        e.localId,
        NotesCompanion(
          uid: Value(dto.uid.value),
          serverId: Value(dto.id ?? fresh.serverId),
          serverCreatedAt: Value(dto.createdAt ?? fresh.serverCreatedAt),
          serverUpdatedAt: Value(dto.updatedAt ?? ctx.serverNow),
          dirtyFields: Value(
            DirtyFields.decode(fresh.dirtyFields).clearSent(sent).encode(),
          ),
          baseJson: Value(BaseJson.encode(snapshotOfDto(dto))),
        ),
      );
      await _adoptTags(dao.tagDao, dto.tags ?? const []);
    });
    return PushResult.ok;
  }

  static p.Patch<String> _text(
    DirtyFields dirty,
    String field,
    String? value,
  ) => !dirty.isDirty(field)
      ? const p.Patch.unset()
      : value == null
      ? const p.Patch.clear()
      : p.Patch.set(value);

  /// Tags the server created for a note get their uid on the local rows.
  Future<void> _adoptTags(TagDao dao, List<TagDto> served) async {
    for (final t in served) {
      final uid = t.uid?.value;
      if (uid == null || await dao.byUid(uid) != null) continue;
      final row = await dao.byName(t.name);
      if (row == null || row.uid != null) continue;
      final clean = DirtyFields.decode(row.dirtyFields).isEmpty;
      await dao.write(
        row.localId,
        TagsCompanion(
          uid: Value(uid),
          serverId: Value(t.id),
          serverCreatedAt: Value(t.createdAt),
          serverUpdatedAt: Value(t.updatedAt),
          baseJson: clean
              ? Value(BaseJson.encode(TagSyncHandler.snapshotOfDto(t)))
              : const Value.absent(),
        ),
      );
    }
  }

  @override
  Future<void> rollback(SyncContext ctx, OutboxEntry e, ApiError error) async {
    final dao = NoteDao(ctx.db);
    final row = await dao.byLocalId(e.localId);
    if (row == null) return;
    final base = BaseJson.decode(row.baseJson);
    await ctx.db.transaction(() async {
      if (row.uid == null || base == null || error is NotFoundError) {
        await ctx.db.deleteEntityRow(entity, row.localId);
        return;
      }
      final projectUid = base[NoteField.projectUid] as String?;
      await dao.write(
        row.localId,
        NotesCompanion(
          title: Value(base[NoteField.title] as String?),
          content: Value(base[NoteField.content] as String?),
          color: Value(base[NoteField.color] as String?),
          projectLocalId: Value(
            projectUid == null
                ? null
                : await ctx.ids.localIdOfUid(SyncEntity.project, projectUid),
          ),
          dirtyFields: const Value('{}'),
          pendingDelete: const Value(false),
        ),
      );
      await dao.setTags(row.localId, [
        for (final n in (base[NoteField.tags] as List? ?? const [])) '$n',
      ], ctx.now);
    });
    ctx.notice(
      ConflictNotice.rolledBack(
        entity: entity,
        localId: row.localId,
        message: error.message,
      ),
    );
  }
}

/// Name/uid lookup of the local tags for one pull, so server tags land on the
/// right local row even while a rename of it is still unsent (its old name
/// still matches).
class _TagIndex {
  _TagIndex._(this._byName, this._byUid, this._deleted);

  final Map<String, String> _byName;
  final Map<String, String> _byUid;

  /// Uids and lower-case names of tags the user deleted and whose delete is
  /// still queued: notes must not bring them back.
  final Set<String> _deleted;

  static Future<_TagIndex> load(AppDatabase db) async {
    final all = await db.select(db.tags).get();
    final rows = [
      for (final r in all)
        if (!r.pendingDelete) r,
    ];
    final deleted = {
      for (final r in all)
        if (r.pendingDelete) ...[r.name.toLowerCase(), ?r.uid],
    };
    final byName = <String, String>{};
    final byUid = <String, String>{};
    for (final r in rows) {
      byName[r.name.toLowerCase()] = r.localId;
      if (r.uid != null) byUid[r.uid!] = r.localId;
    }
    for (final r in rows) {
      if (!DirtyFields.decode(r.dirtyFields).isDirty('name')) continue;
      final old = BaseJson.decode(r.baseJson)?['name'];
      if (old is String) byName.putIfAbsent(old.toLowerCase(), () => r.localId);
    }
    return _TagIndex._(byName, byUid, deleted);
  }

  /// Local id for a name (case-insensitive), or null.
  Future<String?> byName(String name) async => _byName[name.toLowerCase()];

  /// Local id of the tag embedded in a server note, created if unknown; null
  /// for a tag with a pending delete.
  Future<String?> resolve(TagDao dao, TagDto t, DateTime now) async {
    final known =
        (t.uid == null ? null : _byUid[t.uid!.value]) ??
        _byName[t.name.toLowerCase()];
    if (known != null) return known;
    if (_deleted.contains(t.uid?.value) ||
        _deleted.contains(t.name.toLowerCase())) {
      return null;
    }
    final id = LocalId.generate().value;
    await dao.upsert(
      TagsCompanion.insert(
        localId: id,
        uid: Value(t.uid?.value),
        serverId: Value(t.id),
        name: Value(t.name),
        color: Value(t.color),
        pinned: Value(t.pinned ?? false),
        serverCreatedAt: Value(t.createdAt),
        serverUpdatedAt: Value(t.updatedAt),
        localUpdatedAt: Value(t.updatedAt ?? now),
        baseJson: t.uid == null
            ? const Value.absent()
            : Value(BaseJson.encode(TagSyncHandler.snapshotOfDto(t))),
      ),
    );
    _byName[t.name.toLowerCase()] = id;
    if (t.uid != null) _byUid[t.uid!.value] = id;
    return id;
  }
}
