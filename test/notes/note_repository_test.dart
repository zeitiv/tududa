import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/api/api_error.dart';
import 'package:tududa/core/api/patch.dart' show Patch;
import 'package:tududa/core/ids.dart';
import 'package:tududa/notes/data/note_patch.dart';
import 'package:tududa/notes/data/notes_api.dart';
import 'package:tududa/notes/data/remote_note_repository.dart';
import 'package:tududa/notes/domain/note.dart';

import '../support/fake_tududi/routes/notes_routes.dart';
import 'note_test_env.dart';

void main() {
  test('list/get/create/update/delete against the fake', () async {
    final stack = await signedInStack();
    final repo = RemoteNoteRepository(NotesApi(stack.dio));
    seedNote(stack.server, uid: 'n1', title: 'One', projectUid: 'p1');
    seedNote(stack.server, uid: 'n2', title: 'Two');

    expect((await repo.list()).map((n) => n.title), ['One', 'Two']);
    final filtered = await repo.list(projectUid: const ProjectUid('p1'));
    expect(filtered.single.uid, const NoteUid('n1'));
    expect(stack.server.requests.last.query['project_uid'], 'p1');

    final created = await repo.create(
      const NoteDraft(title: 'New', content: 'body', tagNames: ['t']),
    );
    expect(created.title, 'New');
    expect(created.tags.single.name, 't');

    final updated = await repo.update(
      created.uid!,
      const NotePatch(color: Patch.set('#FFF3CC')),
    );
    expect(updated.color, '#FFF3CC');
    expect(updated.title, 'New');

    await repo.delete(created.uid!);
    expect(await errorOf(repo.get(created.uid!)), isA<NotFoundError>());
  });

  test('wrapped list and slug-suffixed uid', () async {
    final stack = await signedInStack();
    final repo = RemoteNoteRepository(NotesApi(stack.dio));
    notesStoreOf(stack.server).wrapNotesList = true;
    seedNote(stack.server, uid: 'abc123', title: 'Slugged');
    expect((await repo.list()).single.title, 'Slugged');
    expect(
      (await repo.get(const NoteUid('my-note-abc123'))).uid,
      const NoteUid('abc123'),
    );
  });

  test('errors: 404 unknown uid, 400 empty note', () async {
    final stack = await signedInStack();
    final repo = RemoteNoteRepository(NotesApi(stack.dio));
    expect(
      await errorOf(repo.get(const NoteUid('nope'))),
      isA<NotFoundError>(),
    );
    expect(
      await errorOf(repo.update(const NoteUid('nope'), const NotePatch())),
      isA<NotFoundError>(),
    );
    expect(
      await errorOf(repo.create(const NoteDraft())),
      isA<ValidationError>(),
    );
  });

  test('offline surfaces as a transient ApiError', () async {
    final stack = await signedInStack();
    final repo = RemoteNoteRepository(NotesApi(stack.dio));
    stack.server.offline = true;
    expect((await errorOf(repo.list())).isTransient, isTrue);
  });

  test('expired session re-authenticates; mutations carry csrf', () async {
    final stack = await signedInStack();
    final repo = RemoteNoteRepository(NotesApi(stack.dio));
    seedNote(stack.server, uid: 'n1');
    stack.server.expireAllSessions();
    await repo.update(
      const NoteUid('n1'),
      const NotePatch(title: Patch.set('after')),
    );
    expect(stack.callbacks.calls, 1);
    expect(stack.server.requests.last.headers['x-csrf-token'], isNotNull);
    expect(stack.server.requests.last.path, '/note/n1');
  });
}
