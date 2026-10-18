import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/api/api_error.dart';
import 'package:tududa/core/api/patch.dart' show Patch;
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/db/dirty_fields.dart';
import 'package:tududa/core/sync/merge.dart';
import 'package:tududa/core/sync/sync_handler.dart';
import 'package:tududa/notes/domain/note.dart';
import 'package:tududa/notes/data/note_sync_handler.dart';
import 'package:tududa/tags/data/tag_patch.dart';
import 'package:tududa/tags/data/tag_sync_handler.dart';

import '../notes/note_test_env.dart';
import '../support/fake_tududi/routes/notes_routes.dart';

void main() {
  late OfflineEnv env;
  setUp(() async => env = await OfflineEnv.create());
  tearDown(() => env.dispose());

  Future<TagRow> tagRow(String name) => (env.db.select(
    env.db.tags,
  )..where((t) => t.name.equals(name))).getSingle();

  test('create offline syncs and fills the uid', () async {
    env.online = false;
    final t = await env.tags.create('  work ');
    expect(t.name, 'work');
    expect(t.uid, isNull);
    // Case-insensitive: the same tag again.
    expect((await env.tags.create('WORK')).localId, t.localId);
    expect(await env.tags.list(), hasLength(1));
    await env.engine.requestSync(SyncReason.write);
    expect(env.server.requests.where((r) => r.path == '/tag'), isEmpty);

    env.online = true;
    await env.sync();
    expect(env.count('POST', '/tag'), 1);
    expect((await tagRow('work')).uid, env.remote.tags.keys.single);
    expect(await env.outbox(), isEmpty);
  });

  test('rename, recolor and pin send one PATCH /tag/<uid>', () async {
    final seeded = seedTag(env.server, 'old');
    await env.sync();
    final tag = (await env.tags.list()).single;
    await env.tags.update(
      tag.identifier,
      const TagPatch(name: Patch.set('new')),
    );
    await env.tags.update(
      tag.identifier,
      const TagPatch(color: Patch.set('#123456'), pinned: Patch.set(true)),
    );
    await env.sync();

    final patches = env.server.requests.where((r) => r.method == 'PATCH');
    expect(patches, hasLength(1));
    expect(patches.single.path, '/tag/${seeded['uid']}');
    expect(patches.single.body, {
      'name': 'new',
      'color': '#123456',
      'pinned': true,
    });
    final row = await tagRow('new');
    expect(row.dirtyFields, '{}');
    expect(env.remote.tags[seeded['uid']]!['name'], 'new');
  });

  test('a rename keeps the notes that carry the tag consistent', () async {
    seedNote(env.server, uid: 'n1', title: 'T', tags: ['old']);
    await env.sync();
    final tag = (await env.tags.list()).single;
    await env.tags.update(
      tag.localId!.value,
      const TagPatch(name: Patch.set('new')),
    );
    // Immediately visible on the note (join rows reference the local id).
    expect((await env.notes.list()).single.tags.map((t) => t.name), ['new']);
    await env.sync();
    expect(await env.tags.list(), hasLength(1));
    expect((await env.notes.list()).single.tags.map((t) => t.name), ['new']);
    expect(await env.db.select(env.db.noteTags).get(), hasLength(1));
  });

  test(
    'a pull while the rename is unsent does not duplicate the tag',
    () async {
      seedNote(env.server, uid: 'n1', title: 'T', tags: ['old']);
      await env.sync();
      final tag = (await env.tags.list()).single;
      await env.tags.update(
        tag.identifier,
        const TagPatch(name: Patch.set('new')),
      );
      // Pull only (no push): the note still lists the old name server-side.
      await TagSyncHandler().pull(env.context());
      env.remote.notes['n1']!['updated_at'] = env.t
          .add(const Duration(minutes: 1))
          .toIso8601String();
      await NoteSyncHandler().pull(env.context());
      expect(await env.tags.list(), hasLength(1));
      expect((await env.tags.list()).single.name, 'new');
      expect((await env.notes.list()).single.tags.map((t) => t.name), ['new']);
    },
  );

  test('pull keeps dirty tag fields and merges the others', () async {
    final seeded = seedTag(env.server, 'a');
    await env.sync();
    final tag = (await env.tags.list()).single;
    await env.tags.update(
      tag.identifier,
      const TagPatch(name: Patch.set('zz')),
    );
    env.remote.tags[seeded['uid']]!['color'] = '#abc';
    env.remote.tags[seeded['uid']]!['updated_at'] = env.t.toIso8601String();
    await TagSyncHandler().pull(env.context());
    final row = await tagRow('zz');
    expect(row.color, '#abc');
    expect(DirtyFields.decode(row.dirtyFields).fields, {'name'});
  });

  test('fullReconcile drops clean tags the server no longer has', () async {
    seedTag(env.server, 'keep');
    final gone = seedTag(env.server, 'gone');
    await env.sync();
    env.remote.tags.remove(gone['uid']);
    await TagSyncHandler().fullReconcile(env.context());
    expect((await env.tags.list()).map((t) => t.name), ['keep']);
  });

  test('delete is pushed and removes the join rows', () async {
    final seeded = seedTag(env.server, 'bye');
    seedNote(env.server, uid: 'n1', title: 'T', tags: ['bye']);
    await env.sync();
    expect(await env.db.select(env.db.noteTags).get(), hasLength(1));
    await env.tags.delete('bye');
    expect(await env.tags.list(), isEmpty);
    expect((await env.notes.list()).single.tags, isEmpty);
    await env.sync();
    expect(env.count('DELETE', '/tag/${seeded['uid']}'), 1);
    expect(await env.db.select(env.db.tags).get(), isEmpty);
  });

  test('tags created with a note are adopted, not duplicated', () async {
    await env.notes.create(const NoteDraft(title: 'N', tagNames: ['fresh']));
    await env.syncLater();
    await env.sync();
    final tags = await env.db.select(env.db.tags).get();
    expect(tags, hasLength(1));
    expect(tags.single.uid, env.remote.tags.keys.single);
    // Renaming such a tag before it had a uid still works.
    final implicit = await env.notes.create(
      const NoteDraft(title: 'M', tagNames: ['soon']),
    );
    final soon = implicit.tags.single;
    await env.tags.update(
      soon.localId!.value,
      const TagPatch(name: Patch.set('later')),
    );
    await env.syncLater();
    expect(
      env.remote.tags.values.map((t) => t['name']),
      containsAll(['fresh', 'later']),
    );
  });

  test('a create for a name the server already has adopts it', () async {
    final seeded = seedTag(env.server, 'dup');
    env.online = false;
    await env.tags.create('Dup');
    env.online = true;
    await env.sync();
    expect(env.remote.tags, hasLength(1));
    expect(await env.db.select(env.db.tags).get(), hasLength(1));
    expect((await env.db.select(env.db.tags).getSingle()).uid, seeded['uid']);
    expect(await env.outbox(), isEmpty);
  });

  test('rollback 404: renaming a tag the server lost removes it', () async {
    final seeded = seedTag(env.server, 'a');
    await env.sync();
    final tag = (await env.tags.list()).single;
    await env.tags.update(tag.identifier, const TagPatch(name: Patch.set('b')));
    env.remote.tags.remove(seeded['uid']);
    await env.sync();
    expect(await env.tags.list(), isEmpty);
    expect(env.engine.status.notices.single, isA<ConflictNotice>());
    expect(await env.outbox(), isEmpty);
  });

  test('rollback 422: the rename is undone from base_json', () async {
    seedTag(env.server, 'a', color: '#111');
    await env.sync();
    final tag = (await env.tags.list()).single;
    env.server.failNext(
      '/tag/${tag.uid!.value}',
      422,
      body: {'error': 'bad name'},
    );
    await env.tags.update(
      tag.identifier,
      const TagPatch(name: Patch.set('b'), color: Patch.clear()),
    );
    await env.sync();
    final row = await tagRow('a');
    expect(row.color, '#111');
    expect(row.dirtyFields, '{}');
    expect(env.engine.status.notices, hasLength(1));
  });

  test('rollback of a create the server refuses deletes the tag', () async {
    env.server.failNext('/tag', 400);
    await env.tags.create('x');
    await env.sync();
    expect(await env.tags.list(), isEmpty);
    expect(env.engine.status.notices, hasLength(1));
  });

  test('validation and lookup errors', () async {
    seedTag(env.server, 'a');
    seedTag(env.server, 'b');
    await env.sync();
    expect(await errorOf(env.tags.create('  ')), isA<ValidationError>());
    expect(
      await errorOf(env.tags.update('a', const TagPatch(name: Patch.set('B')))),
      isA<ValidationError>(),
    );
    expect(
      await errorOf(env.tags.update('a', const TagPatch(name: Patch.set('')))),
      isA<ValidationError>(),
    );
    expect(await errorOf(env.tags.delete('ghost')), isA<NotFoundError>());
    expect(await errorOf(env.tags.get(name: 'ghost')), isA<NotFoundError>());
    expect((await env.tags.get(name: 'A')).name, 'a');
  });

  test('unused local-only tags are pruned on pull', () async {
    await env.db
        .into(env.db.tags)
        .insert(
          TagsCompanion.insert(localId: 'orphan', name: const Value('orphan')),
        );
    await TagSyncHandler().pull(env.context());
    expect(await env.tags.list(), isEmpty);
  });
}
