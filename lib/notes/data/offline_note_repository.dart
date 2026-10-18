import 'package:drift/drift.dart';

import '../../core/api/api_error.dart';
import '../../core/api/patch.dart' as p;
import '../../core/db/app_database.dart';
import '../../core/db/dirty_fields.dart';
import '../../core/ids.dart';
import '../../core/sync/id_resolver.dart';
import '../domain/note.dart';
import 'note_dao.dart';
import 'note_patch.dart';
import 'note_repository.dart';

/// Notes backed by the local database. Every write is one transaction with
/// its outbox entry; `NoteSyncHandler` sends it later.
///
/// Notes can be addressed by uid (as before) or, for notes that have not
/// reached the server yet, by [LocalId]. The `*ByLocalId` methods and
/// [findByRouteId] are additive extensions of [NoteRepository].
class OfflineNoteRepository implements NoteRepository {
  OfflineNoteRepository(
    this._db, {
    DateTime Function()? now,
    this.editDelay = const Duration(seconds: 2),
  }) : _now = now ?? (() => DateTime.now().toUtc()),
       _dao = NoteDao(_db);

  final AppDatabase _db;
  final DateTime Function() _now;
  final NoteDao _dao;

  /// How long an edit waits in the outbox. Further edits of the same note
  /// within it are merged into one PATCH (the outbox moves `not_before`).
  final Duration editDelay;

  // ---- reads ----

  @override
  Future<List<Note>> list({ProjectUid? projectUid}) =>
      projectUid == null ? _dao.list() : _dao.listForProject(projectUid.value);

  /// Live list; a project filter matches the project's uid.
  Stream<List<Note>> watchList({ProjectUid? projectUid}) => projectUid == null
      ? _dao.watchAll()
      : _dao.watchForProject(projectUid.value);

  Stream<List<Note>> watchForProjectLocal(LocalId project) =>
      _dao.watchForProjectLocal(project.value);

  Stream<Note?> watchByUid(NoteUid uid) => _dao.watchByUid(uid.value);
  Stream<Note?> watchByLocalId(LocalId id) => _dao.watchByLocalId(id.value);

  @override
  Future<Note> get(NoteUid uid) async => _found(await findByRouteId(uid.value));

  Future<Note> getByLocalId(LocalId id) async =>
      _found(await _dao.noteByLocalId(id.value));

  /// A note by a route parameter: its uid, its local id or a slug-suffixed
  /// uid. Null if unknown.
  Future<Note?> findByRouteId(String id) async {
    final row = await _dao.byRouteId(id);
    return row == null ? null : _dao.noteByLocalId(row.localId);
  }

  Note _found(Note? n) => n ?? (throw const NotFoundError('Note not found'));

  // ---- writes ----

  @override
  Future<Note> create(NoteDraft draft) => _db.transaction(() async {
    final title = _blankToNull(draft.title);
    final content = draft.content;
    if (title == null && (content ?? '').trim().isEmpty) {
      throw const ValidationError('Title is required');
    }
    final now = _now().toUtc();
    final project =
        draft.projectLocalId?.value ?? await _projectLocal(draft.projectUid);
    final id = await _dao.insertNew(
      title: title,
      content: content,
      color: draft.color,
      projectLocalId: project,
      tagNames: draft.tagNames,
      now: now,
    );
    await _db.outboxDao.enqueue(
      entity: SyncEntity.note,
      localId: id,
      op: OutboxOp.create,
      now: now,
    );
    return _found(await _dao.noteByLocalId(id));
  });

  @override
  Future<Note> update(NoteUid uid, NotePatch patch) async {
    final row = await _dao.byRouteId(uid.value);
    return _update(row, patch);
  }

  Future<Note> updateByLocalId(LocalId id, NotePatch patch) async =>
      _update(await _dao.byLocalId(id.value), patch);

  Future<Note> _update(NoteRow? found, NotePatch patch) =>
      _db.transaction(() async {
        // Re-read inside the transaction so concurrent edits compose.
        final row = found == null ? null : await _dao.byLocalId(found.localId);
        if (row == null || row.pendingDelete) {
          throw const NotFoundError('Note not found');
        }
        final now = _now().toUtc();
        final ms = now.millisecondsSinceEpoch;
        var dirty = DirtyFields.decode(row.dirtyFields);
        var companion = const NotesCompanion();
        var changed = false;

        void text(
          p.Patch<String> value,
          String? current,
          String field,
          NotesCompanion Function(NotesCompanion, String?) apply,
        ) {
          if (value is! p.Set<String>) return;
          final next = value.value;
          if (next == current) return;
          companion = apply(companion, next);
          dirty = dirty.mark(field, ms);
          changed = true;
        }

        text(
          patch.title,
          row.title,
          NoteField.title,
          (c, v) => c.copyWith(title: Value(v)),
        );
        text(
          patch.content,
          row.content,
          NoteField.content,
          (c, v) => c.copyWith(content: Value(v)),
        );
        text(
          patch.color,
          row.color,
          NoteField.color,
          (c, v) => c.copyWith(color: Value(v)),
        );

        final projectP = patch.projectLocalId;
        String? nextProject = row.projectLocalId;
        var projectSet = false;
        if (projectP is p.Set<LocalId>) {
          nextProject = projectP.value?.value;
          projectSet = true;
        } else if (patch.projectUid is p.Set<ProjectUid>) {
          nextProject = await _projectLocal(
            (patch.projectUid as p.Set<ProjectUid>).value,
          );
          projectSet = true;
        }
        if (projectSet && nextProject != row.projectLocalId) {
          companion = companion.copyWith(projectLocalId: Value(nextProject));
          dirty = dirty.mark(NoteField.projectUid, ms);
          changed = true;
        }

        final tagsP = patch.tags;
        if (tagsP is p.Set<List<String>>) {
          final next = tagsP.value ?? const <String>[];
          final current = await _dao.tagNamesOf(row.localId);
          if (!_sameNames(current, next)) {
            await _dao.setTags(row.localId, next, now);
            dirty = dirty.mark(NoteField.tags, ms);
            changed = true;
          }
        }

        if (changed) {
          await _dao.write(
            row.localId,
            companion.copyWith(
              dirtyFields: Value(dirty.encode()),
              localUpdatedAt: Value(now),
            ),
          );
          await _db.outboxDao.enqueue(
            entity: SyncEntity.note,
            localId: row.localId,
            op: OutboxOp.update,
            notBefore: now.add(editDelay),
            now: now,
          );
        }
        return _found(await _dao.noteByLocalId(row.localId));
      });

  @override
  Future<void> delete(NoteUid uid) async =>
      _delete(await _dao.byRouteId(uid.value));

  Future<void> deleteByLocalId(LocalId id) async =>
      _delete(await _dao.byLocalId(id.value));

  Future<void> _delete(NoteRow? found) => _db.transaction(() async {
    final row = found == null ? null : await _dao.byLocalId(found.localId);
    if (row == null || row.pendingDelete) {
      throw const NotFoundError('Note not found');
    }
    final now = _now().toUtc();
    await _dao.write(
      row.localId,
      NotesCompanion(
        pendingDelete: const Value(true),
        localUpdatedAt: Value(now),
      ),
    );
    // create + delete cancels out and removes the row.
    await _db.outboxDao.enqueue(
      entity: SyncEntity.note,
      localId: row.localId,
      op: OutboxOp.delete,
      now: now,
    );
  });

  // ---- helpers ----

  Future<String?> _projectLocal(ProjectUid? uid) async {
    if (uid == null) return null;
    final id = await IdResolver(_db)
        .localIdOfUid(SyncEntity.project, uid.value);
    return id ?? (throw const ValidationError('Unknown project'));
  }

  static String? _blankToNull(String? s) =>
      s == null || s.trim().isEmpty ? null : s;

  static bool _sameNames(Iterable<String> a, Iterable<String> b) {
    Set<String> norm(Iterable<String> x) => {
      for (final n in x)
        if (n.trim().isNotEmpty) n.trim().toLowerCase(),
    };
    final x = norm(a), y = norm(b);
    return x.length == y.length && x.containsAll(y);
  }
}
