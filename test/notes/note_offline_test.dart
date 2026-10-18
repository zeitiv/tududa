import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/api/api_error.dart';
import 'package:tududa/core/api/patch.dart' show Patch;
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/db/dirty_fields.dart';
import 'package:tududa/core/ids.dart';
import 'package:tududa/core/sync/merge.dart';
import 'package:tududa/core/sync/sync_handler.dart';
import 'package:tududa/notes/data/note_patch.dart';
import 'package:tududa/notes/data/note_sync_handler.dart';
import 'package:tududa/notes/domain/note.dart';

import '../support/fake_tududi/routes/notes_routes.dart';
import 'note_test_env.dart';

void main() {
  late OfflineEnv env;
  setUp(() async => env = await OfflineEnv.create());
  tearDown(() => env.dispose());

  Future<List<Note>> notes() => env.notes.list();

  test('create offline, then sync fills uid and clears the queue', () async {
    env.online = false;
    final n = await env.notes.create(
      const NoteDraft(title: 'Offline', content: 'body', tagNames: ['x']),
    );
    expect(n.uid, isNull);
    expect(n.tags.single.name, 'x');
    expect((await notes()).single.title, 'Offline');
    await env.engine.requestSync(SyncReason.write);
    expect(env.server.requests.where((r) => r.path == '/notes'), isEmpty);
    expect(await env.outbox(), hasLength(1));

    env.online = true;
    await env.syncLater();
    final posts = env.server.requests.where(
      (r) => r.method == 'POST' && r.path == '/note',
    );
    expect(posts, hasLength(1));
    expect(posts.single.body, containsPair('title', 'Offline'));
    expect(
      posts.single.body,
      containsPair('tags', [
        {'name': 'x'},
      ]),
    );
    final row = (await env.db.select(env.db.notes).getSingle());
    expect(row.uid, isNotNull);
    expect(row.dirtyFields, '{}');
    expect(await env.outbox(), isEmpty);
    expect(env.remote.notes.values.single['title'], 'Offline');
    // The tag the server created is adopted by the local one.
    final tag = await env.db.select(env.db.tags).getSingle();
    expect(tag.uid, env.remote.tags.keys.single);
    expect((await notes()).single.tags.single.name, 'x');
  });

  test(
    'a note edited by uid sends PATCH /note/<uid> with the dirty fields',
    () async {
      seedNote(env.server, uid: 'abc123', title: 'Old', content: 'body');
      await env.sync();
      final loaded = await env.notes.get(const NoteUid('abc123'));
      expect(loaded.title, 'Old');

      await env.notes.update(
        const NoteUid('abc123'),
        const NotePatch(
          title: Patch.set('Edited'),
          content: Patch.set('body'), // unchanged: not sent
        ),
      );
      await env.syncLater();
      final patch = env.server.requests.lastWhere((r) => r.method == 'PATCH');
      expect(patch.path, '/note/abc123');
      expect(patch.body, {'title': 'Edited'});
      expect(env.remote.notes['abc123']!['title'], 'Edited');
      expect(await env.outbox(), isEmpty);
    },
  );

  test('two quick edits become one PATCH', () async {
    seedNote(env.server, uid: 'n1', title: 'T', content: 'c');
    await env.sync();
    const uid = NoteUid('n1');
    await env.notes.update(uid, const NotePatch(content: Patch.set('c1')));
    env.advance(const Duration(seconds: 1));
    await env.notes.update(uid, const NotePatch(content: Patch.set('c2')));
    await env.notes.update(uid, const NotePatch(title: Patch.set('T2')));
    expect(await env.outbox(), hasLength(1));

    // Still inside the debounce window: nothing is sent.
    await env.sync();
    expect(env.count('PATCH', '/note/n1'), 0);

    await env.syncLater();
    expect(env.count('PATCH', '/note/n1'), 1);
    expect(env.server.requests.last.body, {'title': 'T2', 'content': 'c2'});
  });

  test('delete hides at once and is pushed; create+delete cancels', () async {
    seedNote(env.server, uid: 'n1', title: 'Gone');
    await env.sync();
    await env.notes.delete(const NoteUid('n1'));
    expect(await notes(), isEmpty);
    await env.syncLater();
    expect(env.count('DELETE', '/note/n1'), 1);
    expect(env.remote.notes, isEmpty);
    expect(await env.db.select(env.db.notes).get(), isEmpty);

    env.server.requests.clear();
    final n = await env.notes.create(const NoteDraft(title: 'Brief'));
    await env.notes.deleteByLocalId(n.localId!);
    expect(await env.outbox(), isEmpty);
    expect(await env.db.select(env.db.notes).get(), isEmpty);
    await env.syncLater();
    expect(env.count('POST', '/note'), 0);
    expect(env.count('DELETE', '/note/x'), 0);
  });

  test('a note whose project has no uid yet waits', () async {
    await env.insertProject('proj-local');
    final n = await env.notes.create(
      NoteDraft(
        title: 'In project',
        projectLocalId: const LocalId('proj-local'),
      ),
    );
    expect(n.projectLocalId, const LocalId('proj-local'));
    await env.syncLater();
    expect(env.count('POST', '/note'), 0);
    expect(await env.outbox(), hasLength(1));

    await (env.db.update(env.db.projects)
          ..where((t) => t.localId.equals('proj-local')))
        .write(const ProjectsCompanion(uid: Value('p-1')));
    await env.sync();
    expect(env.count('POST', '/note'), 1);
    expect(env.server.requests.last.body, containsPair('project_uid', 'p-1'));
    expect(await env.outbox(), isEmpty);
  });

  test('pull keeps rows with unsent edits and merges the rest', () async {
    seedNote(env.server, uid: 'n1', title: 'T', content: 'c', color: '#fff');
    await env.sync();
    await env.notes.update(
      const NoteUid('n1'),
      const NotePatch(title: Patch.set('Local title')),
    );
    // The server changes another field meanwhile.
    env.remote.notes['n1']!['color'] = '#000';
    env.remote.notes['n1']!['updated_at'] = env.t.toIso8601String();

    await NoteSyncHandler().pull(env.context());
    final row = await env.db.select(env.db.notes).getSingle();
    expect(row.title, 'Local title');
    expect(row.color, '#000');
    expect(DirtyFields.decode(row.dirtyFields).fields, {'title'});
    expect(await env.outbox(), hasLength(1));
  });

  test('content edited on both sides: server wins, local text is kept as a '
      'conflict copy that syncs', () async {
    seedNote(env.server, uid: 'n1', title: 'Plan', content: 'base');
    await env.sync();
    await env.notes.update(
      const NoteUid('n1'),
      const NotePatch(content: Patch.set('my local text')),
    );
    env.remote.notes['n1']!['content'] = 'server text';
    env.remote.notes['n1']!['updated_at'] = env.t.toIso8601String();

    await env.syncLater();
    final all = await notes();
    expect(all, hasLength(2));
    final original = all.firstWhere((n) => n.uid == const NoteUid('n1'));
    final copy = all.firstWhere((n) => n.uid != const NoteUid('n1'));
    expect(original.content, 'server text');
    expect(copy.title, '(conflict copy) Plan');
    expect(copy.content, 'my local text');
    // The copy went through the normal create path.
    expect(copy.uid, isNotNull);
    expect(
      env.remote.notes.values.map((n) => n['title']),
      contains('(conflict copy) Plan'),
    );
    expect(env.remote.notes['n1']!['content'], 'server text');
    expect(
      env.engine.status.notices.where((n) => n.field == 'content'),
      isNotEmpty,
    );
    expect(await env.outbox(), isEmpty);
  });

  test('fullReconcile removes clean notes the server dropped', () async {
    seedNote(env.server, uid: 'n1', title: 'Keep');
    seedNote(env.server, uid: 'n2', title: 'Drop');
    await env.sync();
    expect(await notes(), hasLength(2));
    env.remote.notes.remove('n2');

    await NoteSyncHandler().pull(env.context());
    expect(await notes(), hasLength(2)); // an ordinary pull never deletes
    await NoteSyncHandler().fullReconcile(env.context());
    expect((await notes()).map((n) => n.title), ['Keep']);
  });

  test('rollback 404: the note vanished on the server', () async {
    seedNote(env.server, uid: 'n1', title: 'Doomed');
    await env.sync();
    await env.notes.update(
      const NoteUid('n1'),
      const NotePatch(title: Patch.set('Edited')),
    );
    env.remote.notes.remove('n1');
    env.advance();
    // Skip the pull (it would not delete a dirty row anyway) and push.
    await env.sync();
    expect(await notes(), isEmpty);
    expect(await env.outbox(), isEmpty);
    expect(
      env.engine.status.notices.single,
      isA<ConflictNotice>().having((n) => n.field, 'field', '*'),
    );
  });

  test('rollback 400: the edit is undone from base_json', () async {
    seedNote(env.server, uid: 'n1', title: 'Title', content: 'Body');
    await env.sync();
    await env.notes.update(
      const NoteUid('n1'),
      const NotePatch(title: Patch.clear(), content: Patch.set('')),
    );
    await env.syncLater();
    expect(env.count('PATCH', '/note/n1'), 1);
    final n = await env.notes.get(const NoteUid('n1'));
    expect(n.title, 'Title');
    expect(n.content, 'Body');
    final row = await env.db.select(env.db.notes).getSingle();
    expect(row.dirtyFields, '{}');
    expect(await env.outbox(), isEmpty);
    expect(env.engine.status.notices, hasLength(1));
  });

  test('rollback of a create the server refuses removes the note', () async {
    env.server.failNext('/note', 400);
    final n = await env.notes.create(const NoteDraft(title: 'Nope'));
    await env.syncLater();
    expect(await notes(), isEmpty);
    expect(await env.outbox(), isEmpty);
    expect(env.engine.status.notices.single.localId, n.localId!.value);
  });

  test('errors: unknown note and blank create', () async {
    expect(
      await errorOf(
        env.notes.update(const NoteUid('ghost'), const NotePatch()),
      ),
      isA<NotFoundError>(),
    );
    expect(
      await errorOf(env.notes.create(const NoteDraft())),
      isA<ValidationError>(),
    );
  });

  test('tags are replaced as a set and sent by name', () async {
    seedNote(env.server, uid: 'n1', title: 'T', tags: ['a']);
    await env.sync();
    expect((await env.notes.get(const NoteUid('n1'))).tags.map((t) => t.name), [
      'a',
    ]);
    await env.notes.update(
      const NoteUid('n1'),
      const NotePatch(tags: Patch.set(['A', 'b'])), // 'A' is the same tag
    );
    await env.syncLater();
    expect(env.server.requests.where((r) => r.method == 'PATCH').single.body, {
      'tags': [
        {'name': 'a'},
        {'name': 'b'},
      ],
    });
    expect((env.remote.notes['n1']!['tags'] as List).length, 2);
    expect(await env.db.select(env.db.tags).get(), hasLength(2));
  });

  test('local id lookup works without a uid; routes accept both', () async {
    final n = await env.notes.create(const NoteDraft(title: 'L'));
    expect((await env.notes.getByLocalId(n.localId!)).title, 'L');
    expect((await env.notes.findByRouteId(n.localId!.value))!.title, 'L');
    await env.syncLater();
    final synced = await env.notes.getByLocalId(n.localId!);
    expect(
      (await env.notes.findByRouteId(synced.uid!.value))!.localId,
      n.localId,
    );
    expect(
      (await env.notes.findByRouteId('slug-${synced.uid!.value}'))!.localId,
      n.localId,
    );
  });
}
