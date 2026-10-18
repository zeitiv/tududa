import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';
import '../../core/db/dirty_fields.dart';
import '../../core/ids.dart';
import '../domain/tag.dart';

/// Plain DAO over the `tags` table and the join tables that reference it.
///
/// Tags are identified by name locally (matched case-insensitively) and by
/// uid or name on the server. Writes here never touch the outbox; the
/// repository does that in the same transaction.
class TagDao {
  TagDao(this._db);
  final AppDatabase _db;

  $TagsTable get _t => _db.tags;

  static Tag toDomain(TagRow r) => Tag(
    id: r.serverId,
    uid: r.uid == null ? null : TagUid(r.uid!),
    localId: LocalId(r.localId),
    name: r.name,
    color: r.color,
    pinned: r.pinned,
    createdAt: r.serverCreatedAt,
    updatedAt: r.serverUpdatedAt ?? r.localUpdatedAt,
  );

  SimpleSelectStatement<$TagsTable, TagRow> _visible() => _db.select(_t)
    ..where((t) => t.pendingDelete.equals(false))
    ..orderBy([(t) => OrderingTerm.asc(t.name.lower())]);

  Stream<List<Tag>> watchAll() =>
      _visible().watch().map((rows) => rows.map(toDomain).toList());

  Future<List<TagRow>> allRows() => _visible().get();

  Future<TagRow?> byLocalId(String localId) => (_db.select(
    _t,
  )..where((t) => t.localId.equals(localId))).getSingleOrNull();

  Future<TagRow?> byUid(String uid) =>
      (_db.select(_t)..where((t) => t.uid.equals(uid))).getSingleOrNull();

  /// The visible tag called [name] (case-insensitive), if any.
  Future<TagRow?> byName(String name) async {
    final key = name.trim().toLowerCase();
    final rows =
        await (_db.select(_t)..where(
              (t) => t.pendingDelete.equals(false) & t.name.lower().equals(key),
            ))
            .get();
    return rows.isEmpty ? null : rows.first;
  }

  /// Finds a tag by what the tag endpoints accept (uid or name) or by local
  /// id; the first match of those wins.
  Future<TagRow?> byIdentifier(String identifier) async =>
      await byLocalId(identifier) ??
      await byUid(identifier) ??
      await byName(identifier);

  /// Local ids for [names] (trimmed, deduplicated case-insensitively, blanks
  /// dropped). Unknown names become new local tags that have no outbox entry:
  /// the server creates them when the note/task carrying them is pushed and a
  /// later pull adopts them by name.
  Future<List<String>> resolveOrCreate(
    Iterable<String> names,
    DateTime now,
  ) async {
    final ids = <String>[];
    final seen = <String>{};
    for (final raw in names) {
      final name = raw.trim();
      if (name.isEmpty || !seen.add(name.toLowerCase())) continue;
      final existing = await byName(name);
      if (existing != null) {
        ids.add(existing.localId);
        continue;
      }
      final id = LocalId.generate().value;
      await _db
          .into(_t)
          .insert(
            TagsCompanion.insert(
              localId: id,
              name: Value(name),
              localUpdatedAt: Value(now),
            ),
          );
      ids.add(id);
    }
    return ids;
  }

  /// Inserts a tag created by the user; all fields dirty.
  Future<String> insertNew(String name, DateTime now) async {
    final id = LocalId.generate().value;
    final dirty = const DirtyFields().markAll([
      'name',
      'color',
      'pinned',
    ], now.millisecondsSinceEpoch);
    await _db
        .into(_t)
        .insert(
          TagsCompanion.insert(
            localId: id,
            name: Value(name),
            localUpdatedAt: Value(now),
            dirtyFields: Value(dirty.encode()),
          ),
        );
    return id;
  }

  /// Writes [companion] for one row (never replaces the row).
  Future<void> write(String localId, TagsCompanion companion) => (_db.update(
    _t,
  )..where((t) => t.localId.equals(localId))).write(companion);

  /// Upsert helper for pulled rows.
  Future<void> upsert(TagsCompanion row) =>
      _db.into(_t).insertOnConflictUpdate(row);

  Future<void> markPendingDelete(String localId, DateTime now) => write(
    localId,
    TagsCompanion(pendingDelete: const Value(true), localUpdatedAt: Value(now)),
  );

  /// Removes the join rows of a tag (note_tags and task_tags).
  Future<void> removeJoins(String tagLocalId) async {
    await (_db.delete(
      _db.noteTags,
    )..where((j) => j.tagLocalId.equals(tagLocalId))).go();
    await (_db.delete(
      _db.taskTags,
    )..where((j) => j.tagLocalId.equals(tagLocalId))).go();
  }

  /// Whether any note or task still references the tag.
  Future<bool> isReferenced(String tagLocalId) async {
    final n = await (_db.select(
      _db.noteTags,
    )..where((j) => j.tagLocalId.equals(tagLocalId))).get();
    if (n.isNotEmpty) return true;
    final k = await (_db.select(
      _db.taskTags,
    )..where((j) => j.tagLocalId.equals(tagLocalId))).get();
    return k.isNotEmpty;
  }
}
