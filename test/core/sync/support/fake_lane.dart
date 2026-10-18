import 'package:drift/drift.dart';
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/db/dirty_fields.dart';

/// What a real lane does for a write: row update + dirty marks + outbox
/// entry in ONE transaction. These operate on `projects` (name) and `notes`
/// (title + project_local_id) for the engine tests.
class FakeLane {
  FakeLane(this.db, this.now);
  final AppDatabase db;
  final DateTime Function() now;

  int get _ms => now().millisecondsSinceEpoch;

  Future<void> createProject(
    String localId,
    String name, {
    Duration undo = Duration.zero,
  }) => db.transaction(() async {
    await db
        .into(db.projects)
        .insert(
          ProjectsCompanion.insert(
            localId: localId,
            name: Value(name),
            localUpdatedAt: Value(now()),
            dirtyFields: Value(const DirtyFields().mark('name', _ms).encode()),
          ),
        );
    await db.outboxDao.enqueue(
      entity: SyncEntity.project,
      localId: localId,
      op: OutboxOp.create,
      notBefore: now().add(undo),
      now: now(),
    );
  });

  Future<void> createNote(
    String localId,
    String title, {
    String? projectLocalId,
  }) => db.transaction(() async {
    await db
        .into(db.notes)
        .insert(
          NotesCompanion.insert(
            localId: localId,
            title: Value(title),
            projectLocalId: Value(projectLocalId),
            localUpdatedAt: Value(now()),
            dirtyFields: Value(const DirtyFields().mark('name', _ms).encode()),
          ),
        );
    await db.outboxDao.enqueue(
      entity: SyncEntity.note,
      localId: localId,
      op: OutboxOp.create,
      now: now(),
    );
  });

  Future<void> renameProject(
    String localId,
    String name, {
    Duration undo = Duration.zero,
  }) => db.transaction(() async {
    final row = await (db.select(
      db.projects,
    )..where((t) => t.localId.equals(localId))).getSingle();
    final dirty = DirtyFields.decode(row.dirtyFields).mark('name', _ms);
    await (db.update(
      db.projects,
    )..where((t) => t.localId.equals(localId))).write(
      ProjectsCompanion(
        name: Value(name),
        dirtyFields: Value(dirty.encode()),
        localUpdatedAt: Value(now()),
      ),
    );
    await db.outboxDao.enqueue(
      entity: SyncEntity.project,
      localId: localId,
      op: OutboxOp.update,
      notBefore: now().add(undo),
      now: now(),
    );
  });

  Future<void> deleteProject(String localId) => db.transaction(() async {
    await (db.update(db.projects)..where((t) => t.localId.equals(localId)))
        .write(const ProjectsCompanion(pendingDelete: Value(true)));
    await db.outboxDao.enqueue(
      entity: SyncEntity.project,
      localId: localId,
      op: OutboxOp.delete,
      now: now(),
    );
  });

  Future<ProjectRow?> project(String localId) => (db.select(
    db.projects,
  )..where((t) => t.localId.equals(localId))).getSingleOrNull();

  Future<NoteRow?> note(String localId) => (db.select(
    db.notes,
  )..where((t) => t.localId.equals(localId))).getSingleOrNull();
}
