import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/db/dirty_fields.dart';
import 'package:tududa/core/db/entity_access.dart';
import 'package:tududa/core/db/fts.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> addTask(String id, String name, {String? note, String? uid}) =>
      db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              localId: id,
              name: Value(name),
              note: Value(note),
              uid: Value(uid),
            ),
          );

  Future<List<String>> search(String text) async => [
    for (final r in await db.searchIndex(ftsQuery(text), 20).get())
      '${r.entity}:${r.localId}',
  ];

  test('FTS5 index follows insert, update, soft delete and delete', () async {
    await addTask('t1', 'Buy milk', note: 'two litres');
    await addTask('t2', 'Call mom');
    expect(await search('mil'), ['task:t1']);
    expect(await search('litres'), ['task:t1']);

    await (db.update(db.tasks)..where((t) => t.localId.equals('t1'))).write(
      const TasksCompanion(name: Value('Buy oat drink')),
    );
    expect(await search('milk'), isEmpty);
    expect(await search('oat'), ['task:t1']);

    await (db.update(db.tasks)..where((t) => t.localId.equals('t1'))).write(
      const TasksCompanion(pendingDelete: Value(true)),
    );
    expect(await search('oat'), isEmpty);

    await (db.delete(db.tasks)..where((t) => t.localId.equals('t2'))).go();
    expect(await search('mom'), isEmpty);
  });

  test('FTS5 covers notes, projects, tags and areas', () async {
    await db
        .into(db.notes)
        .insert(
          NotesCompanion.insert(
            localId: 'n1',
            title: const Value('Trip plan'),
            content: const Value('pack the tent'),
          ),
        );
    await db
        .into(db.projects)
        .insert(
          ProjectsCompanion.insert(localId: 'p1', name: const Value('Garden')),
        );
    await db
        .into(db.tags)
        .insert(
          TagsCompanion.insert(localId: 'g1', name: const Value('urgent')),
        );
    await db
        .into(db.areas)
        .insert(
          AreasCompanion.insert(localId: 'a1', name: const Value('Health')),
        );
    expect(await search('tent'), ['note:n1']);
    expect(await search('garden'), ['project:p1']);
    expect(await search('urgent'), ['tag:g1']);
    expect(await search('health'), ['area:a1']);
  });

  test('ftsQuery quotes operators and makes prefix terms', () {
    expect(ftsQuery('buy mi'), '"buy"* "mi"*');
    expect(ftsQuery('a-b "c"'), '"a-b"* """c"""*');
    expect(ftsQuery('  '), '');
  });

  test('rebuildSearchIndex restores a bypassed index', () async {
    await addTask('t1', 'Buy milk');
    await db.customStatement('DELETE FROM search_fts');
    expect(await search('milk'), isEmpty);
    await db.rebuildSearchIndex();
    expect(await search('milk'), ['task:t1']);
  });

  test('wipe empties every table in one go', () async {
    await addTask('t1', 'x', uid: 'u1');
    await db.kvDao.set('profile', {'a': 1});
    await db.outboxDao.enqueue(
      entity: SyncEntity.task,
      localId: 't1',
      op: OutboxOp.create,
    );
    await db.syncStateDao.update(
      SyncEntity.task,
      lastSyncAt: Value(DateTime.utc(2025)),
    );
    await db.wipe();
    expect(await db.select(db.tasks).get(), isEmpty);
    expect(await db.select(db.outbox).get(), isEmpty);
    expect(await db.select(db.syncStates).get(), isEmpty);
    expect(await db.kvDao.get('profile'), isNull);
    expect(await search('x'), isEmpty);
  });

  test('uid is unique but may be null on many rows', () async {
    await addTask('t1', 'a');
    await addTask('t2', 'b');
    await addTask('t3', 'c', uid: 'u');
    expect(() => addTask('t4', 'd', uid: 'u'), throwsA(isA<Exception>()));
  });

  test('removeCleanMissing keeps dirty, unpushed and queued rows', () async {
    await addTask('keep', 'on server', uid: 'u-keep');
    await addTask('gone', 'deleted remotely', uid: 'u-gone');
    await addTask('dirty', 'edited', uid: 'u-dirty');
    await addTask('local', 'never pushed');
    await addTask('queued', 'queued', uid: 'u-queued');
    await (db.update(db.tasks)..where((t) => t.localId.equals('dirty'))).write(
      TasksCompanion(
        dirtyFields: Value(const DirtyFields().mark('name', 1).encode()),
      ),
    );
    await db.outboxDao.enqueue(
      entity: SyncEntity.task,
      localId: 'queued',
      op: OutboxOp.update,
    );
    final removed = await db.removeCleanMissing(SyncEntity.task, {'u-keep'});
    expect(removed, ['gone']);
    final left = (await db.select(db.tasks).get()).map((t) => t.localId);
    expect(left, unorderedEquals(['keep', 'dirty', 'local', 'queued']));
  });

  test('DirtyFields round-trips and clears only what was sent', () {
    final d = const DirtyFields().mark('name', 5).mark('note', 7);
    expect(DirtyFields.decode(d.encode()), d);
    expect(d.isDirty('name'), isTrue);
    expect(d.fields, {'name', 'note'});
    expect(d.clear(['name']).fields, {'note'});
    expect(d.clearSent({'name': 5, 'note': 6}).fields, {'note'});
    expect(DirtyFields.decode('not json').isEmpty, isTrue);
    expect(DirtyFields.decode(null).isEmpty, isTrue);
    expect(BaseJson.decode(BaseJson.encode({'a': 1})), {'a': 1});
    expect(BaseJson.decode('oops'), isNull);
  });
}
