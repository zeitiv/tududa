import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';
import '../../core/db/dirty_fields.dart';
import '../../core/ids.dart';
import '../../tags/data/tag_dao.dart';
import '../../tags/domain/tag.dart';
import '../domain/note.dart';

/// Dirty-field names of a note; also the keys of its `base_json` snapshot.
abstract final class NoteField {
  static const title = 'title';
  static const content = 'content';
  static const color = 'color';
  static const projectUid = 'project_uid';
  static const tags = 'tags';

  static const all = [title, content, color, projectUid, tags];
}

/// Plain DAO over `notes` and `note_tags`. It does not touch the outbox; the
/// repository (or the sync handler, for conflict copies) does that in the
/// same transaction.
class NoteDao {
  NoteDao(this._db) : tagDao = TagDao(_db);
  final AppDatabase _db;
  final TagDao tagDao;

  $NotesTable get _t => _db.notes;

  Future<NoteRow?> byLocalId(String localId) => (_db.select(
    _t,
  )..where((t) => t.localId.equals(localId))).getSingleOrNull();

  Future<NoteRow?> byUid(String uid) =>
      (_db.select(_t)..where((t) => t.uid.equals(uid))).getSingleOrNull();

  /// A note by whatever a route carries: local id, uid, or a slug-suffixed
  /// uid (`my-note-<uid>`).
  Future<NoteRow?> byRouteId(String id) async {
    final row = await byLocalId(id) ?? await byUid(id);
    if (row != null) return row;
    final dash = id.lastIndexOf('-');
    return dash < 0 ? null : byUid(id.substring(dash + 1));
  }

  /// Local ids of the (visible) tags of a note, ordered by name.
  Future<List<TagRow>> tagRowsOf(String noteLocalId) async {
    final q =
        _db.select(_db.tags).join([
            innerJoin(
              _db.noteTags,
              _db.noteTags.tagLocalId.equalsExp(_db.tags.localId),
            ),
          ])
          ..where(
            _db.noteTags.noteLocalId.equals(noteLocalId) &
                _db.tags.pendingDelete.equals(false),
          )
          ..orderBy([OrderingTerm.asc(_db.tags.name.lower())]);
    return [for (final r in await q.get()) r.readTable(_db.tags)];
  }

  Future<List<String>> tagNamesOf(String noteLocalId) async => [
    for (final t in await tagRowsOf(noteLocalId)) t.name,
  ];

  /// Replaces the tags of a note with [names] (created locally when new).
  Future<void> setTags(
    String noteLocalId,
    Iterable<String> names,
    DateTime now,
  ) async {
    await setTagIds(noteLocalId, await tagDao.resolveOrCreate(names, now));
  }

  /// Replaces the join rows of a note with the tags [ids].
  Future<void> setTagIds(String noteLocalId, Iterable<String> ids) async {
    await (_db.delete(
      _db.noteTags,
    )..where((j) => j.noteLocalId.equals(noteLocalId))).go();
    for (final id in ids) {
      await _db
          .into(_db.noteTags)
          .insertOnConflictUpdate(
            NoteTagsCompanion.insert(noteLocalId: noteLocalId, tagLocalId: id),
          );
    }
  }

  /// Inserts a note with every field dirty (the state a `create` entry is
  /// built from). Returns its local id.
  Future<String> insertNew({
    String? title,
    String? content,
    String? color,
    String? projectLocalId,
    Iterable<String> tagNames = const [],
    required DateTime now,
  }) async {
    final id = LocalId.generate().value;
    final dirty = const DirtyFields().markAll(
      NoteField.all,
      now.millisecondsSinceEpoch,
    );
    await _db
        .into(_t)
        .insert(
          NotesCompanion.insert(
            localId: id,
            title: Value(title),
            content: Value(content),
            color: Value(color),
            projectLocalId: Value(projectLocalId),
            localUpdatedAt: Value(now),
            dirtyFields: Value(dirty.encode()),
          ),
        );
    await setTags(id, tagNames, now);
    return id;
  }

  Future<void> write(String localId, NotesCompanion companion) => (_db.update(
    _t,
  )..where((t) => t.localId.equals(localId))).write(companion);

  /// Upsert helper for pulled rows (never `INSERT OR REPLACE`).
  Future<void> upsert(NotesCompanion row) =>
      _db.into(_t).insertOnConflictUpdate(row);

  // ---- reads ----

  static const _listSql =
      'SELECT n.*, p.uid AS project_uid_, p.name AS project_name_ '
      'FROM notes n LEFT JOIN projects p ON p.local_id = n.project_local_id '
      'WHERE n.pending_delete = 0 ';
  static const _order = 'ORDER BY n.local_updated_at DESC, n.local_id';

  Selectable<QueryRow> _select(String where, List<Variable> vars) =>
      _db.customSelect(
        '$_listSql$where $_order',
        variables: vars,
        readsFrom: {_t, _db.noteTags, _db.tags, _db.projects},
      );

  Note _toNote(QueryRow r, Map<String, List<Tag>> tags) {
    final row = _t.map(r.data);
    final projectUid = r.readNullable<String>('project_uid_');
    return Note(
      id: row.serverId,
      uid: row.uid == null ? null : NoteUid(row.uid!),
      localId: LocalId(row.localId),
      title: row.title,
      content: row.content,
      color: row.color,
      projectUid: projectUid == null ? null : ProjectUid(projectUid),
      projectLocalId: row.projectLocalId == null
          ? null
          : LocalId(row.projectLocalId!),
      projectName: r.readNullable<String>('project_name_'),
      tags: tags[row.localId] ?? const [],
      createdAt: row.serverCreatedAt,
      updatedAt: row.localUpdatedAt,
    );
  }

  Future<Map<String, List<Tag>>> _allTags() async {
    final q =
        _db.select(_db.noteTags).join([
            innerJoin(
              _db.tags,
              _db.tags.localId.equalsExp(_db.noteTags.tagLocalId),
            ),
          ])
          ..where(_db.tags.pendingDelete.equals(false))
          ..orderBy([OrderingTerm.asc(_db.tags.name.lower())]);
    final out = <String, List<Tag>>{};
    for (final r in await q.get()) {
      final j = r.readTable(_db.noteTags);
      out
          .putIfAbsent(j.noteLocalId, () => [])
          .add(TagDao.toDomain(r.readTable(_db.tags)));
    }
    return out;
  }

  Future<List<Note>> _load(Selectable<QueryRow> s) async {
    final rows = await s.get();
    final tags = await _allTags();
    return [for (final r in rows) _toNote(r, tags)];
  }

  Stream<List<Note>> _watch(Selectable<QueryRow> s) =>
      s.watch().asyncMap((rows) async {
        final tags = await _allTags();
        return [for (final r in rows) _toNote(r, tags)];
      });

  Selectable<QueryRow> _all() => _select('', const []);
  Selectable<QueryRow> _byProjectUid(String uid) =>
      _select('AND p.uid = ?', [Variable<String>(uid)]);
  Selectable<QueryRow> _byProjectLocal(String id) =>
      _select('AND n.project_local_id = ?', [Variable<String>(id)]);
  Selectable<QueryRow> _one(String column, String value) =>
      _select('AND n.$column = ?', [Variable<String>(value)]);

  Future<List<Note>> list() => _load(_all());
  Stream<List<Note>> watchAll() => _watch(_all());
  Future<List<Note>> listForProject(String projectUid) =>
      _load(_byProjectUid(projectUid));
  Stream<List<Note>> watchForProject(String projectUid) =>
      _watch(_byProjectUid(projectUid));
  Stream<List<Note>> watchForProjectLocal(String projectLocalId) =>
      _watch(_byProjectLocal(projectLocalId));

  Future<Note?> noteByLocalId(String id) async =>
      (await _load(_one('local_id', id))).firstOrNull;
  Future<Note?> noteByUid(String uid) async =>
      (await _load(_one('uid', uid))).firstOrNull;
  Stream<Note?> watchByLocalId(String id) =>
      _watch(_one('local_id', id)).map((l) => l.firstOrNull);
  Stream<Note?> watchByUid(String uid) =>
      _watch(_one('uid', uid)).map((l) => l.firstOrNull);
}
