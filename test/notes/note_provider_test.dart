import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/api/api_error.dart';
import 'package:tududa/core/api/api_providers.dart';
import 'package:tududa/core/api/patch.dart' show Patch;
import 'package:tududa/core/ids.dart';
import 'package:tududa/notes/data/note_patch.dart';
import 'package:tududa/notes/domain/note.dart';
import 'package:tududa/notes/providers/note_provider.dart';

import '../support/fake_tududi/routes/notes_routes.dart';
import 'note_test_env.dart';

void main() {
  test('create, update and delete keep the list in sync', () async {
    final stack = await signedInStack();
    seedNote(stack.server, uid: 'n1', title: 'One');
    final c = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(stack.dio)],
    );
    addTearDown(c.dispose);

    expect((await c.read(noteListProvider.future)).length, 1);
    final n = c.read(noteListProvider.notifier);

    final created = await n.create(const NoteDraft(title: 'Two'));
    expect(c.read(noteListProvider).value!.first.uid, created.uid);

    await n.updateNote(
      const NoteUid('n1'),
      const NotePatch(title: Patch.set('Uno')),
    );
    expect(
      c.read(noteListProvider).value!.firstWhere((x) => x.id == 1).title,
      'Uno',
    );

    await n.deleteNote(const NoteUid('n1'));
    expect(c.read(noteListProvider).value!.map((x) => x.title), ['Two']);
  });

  test('failed mutation throws ApiError and keeps the list', () async {
    final stack = await signedInStack();
    seedNote(stack.server, uid: 'n1');
    final c = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(stack.dio)],
    );
    addTearDown(c.dispose);
    await c.read(noteListProvider.future);
    await expectLater(
      c
          .read(noteListProvider.notifier)
          .updateNote(const NoteUid('ghost'), const NotePatch()),
      throwsA(isA<NotFoundError>()),
    );
    expect(c.read(noteListProvider).value!.length, 1);
  });

  test('noteByUidProvider and projectNotesProvider', () async {
    final stack = await signedInStack();
    seedNote(stack.server, uid: 'n1', title: 'A', projectUid: 'p1');
    seedNote(stack.server, uid: 'n2', title: 'B');
    final c = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(stack.dio)],
    );
    addTearDown(c.dispose);
    expect(
      (await c.read(noteByUidProvider(const NoteUid('n2')).future)).title,
      'B',
    );
    expect(
      (await c.read(projectNotesProvider(const ProjectUid('p1')).future))
          .single
          .title,
      'A',
    );
  });
}
