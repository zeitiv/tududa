import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/api/api_error.dart';
import 'package:tududa/core/api/patch.dart' show Patch;
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/ids.dart';
import 'package:tududa/core/sync/sync_engine.dart';
import 'package:tududa/notes/data/note_patch.dart';
import 'package:tududa/notes/domain/note.dart';
import 'package:tududa/notes/providers/note_provider.dart';

import '../support/fake_tududi/routes/notes_routes.dart';
import 'note_test_env.dart';

void main() {
  late OfflineEnv env;
  late ProviderContainer c;

  // Stream providers only run while somebody listens.
  Future<T> live<T>(ProviderListenable<AsyncValue<T>> p) {
    final done = Completer<T>();
    c.listen(p, (_, next) {
      if (done.isCompleted) return;
      if (next.hasError) {
        done.completeError(next.error!, next.stackTrace);
      } else if (next.hasValue) {
        done.complete(next.value as T);
      }
    }, fireImmediately: true);
    return done.future;
  }

  setUp(() async {
    env = await OfflineEnv.create();
    c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(env.db),
        syncEngineProvider.overrideWithValue(env.engine),
        noteRepositoryProvider.overrideWithValue(env.notes),
      ],
    );
  });
  tearDown(() async {
    c.dispose();
    await env.dispose();
  });

  test(
    'the list is reactive: create, update and delete show at once',
    () async {
      seedNote(env.server, uid: 'n1', title: 'One');
      await env.sync();
      final seen = <List<String?>>[];
      c.listen(
        noteListProvider,
        (_, next) =>
            seen.add([for (final n in next.value ?? <Note>[]) n.title]),
        fireImmediately: true,
      );
      expect((await live(noteListProvider)).length, 1);
      final n = c.read(noteListProvider.notifier);

      final created = await n.create(const NoteDraft(title: 'Two'));
      await pumpEventQueue();
      expect(c.read(noteListProvider).value!.first.localId, created.localId);

      await n.updateNote(
        const NoteUid('n1'),
        const NotePatch(title: Patch.set('Uno')),
      );
      await pumpEventQueue();
      expect(
        c.read(noteListProvider).value!.map((x) => x.title),
        containsAll(['Two', 'Uno']),
      );

      await n.deleteNote(const NoteUid('n1'));
      await pumpEventQueue();
      expect(c.read(noteListProvider).value!.map((x) => x.title), ['Two']);
      expect(seen.length, greaterThan(2));
    },
  );

  test('failed mutation throws ApiError and keeps the list', () async {
    seedNote(env.server, uid: 'n1');
    await env.sync();
    await live(noteListProvider);
    await expectLater(
      c
          .read(noteListProvider.notifier)
          .updateNote(const NoteUid('ghost'), const NotePatch()),
      throwsA(isA<NotFoundError>()),
    );
    expect(c.read(noteListProvider).value!.length, 1);
  });

  test('refresh runs a manual sync (pull-to-refresh)', () async {
    await live(noteListProvider);
    seedNote(env.server, uid: 'late', title: 'Arrived');
    await c.read(noteListProvider.notifier).refresh();
    await pumpEventQueue();
    expect(c.read(noteListProvider).value!.single.title, 'Arrived');
  });

  test(
    'noteByUidProvider, noteByLocalIdProvider, projectNotesProvider',
    () async {
      await env.insertProject('pl', uid: 'p1');
      seedNote(env.server, uid: 'n1', title: 'A', projectUid: 'p1');
      seedNote(env.server, uid: 'n2', title: 'B');
      await env.sync();

      expect((await live(noteByUidProvider(const NoteUid('n2')))).title, 'B');
      expect(
        (await live(projectNotesProvider(const ProjectUid('p1')))).single.title,
        'A',
      );
      expect(
        (await live(projectNotesByLocalIdProvider(const LocalId('pl'))))
            .single
            .title,
        'A',
      );

      // A note that has no uid yet is reachable by local id.
      final local = await env.notes.create(const NoteDraft(title: 'Local'));
      final byLocal = await live(noteByLocalIdProvider(local.localId!));
      expect(byLocal.uid, isNull);
      expect(byLocal.title, 'Local');

      await expectLater(
        live(noteByUidProvider(const NoteUid('nope'))),
        throwsA(isA<NotFoundError>()),
      );
    },
  );

  test(
    'updateNoteLocal edits a note without uid; sync then creates it once',
    () async {
      final n = await c
          .read(noteListProvider.notifier)
          .create(const NoteDraft(title: 'Draft', content: 'a'));
      await c
          .read(noteListProvider.notifier)
          .updateNoteLocal(
            n.localId!,
            const NotePatch(content: Patch.set('b')),
          );
      await env.syncLater();
      expect(env.count('POST', '/note'), 1);
      expect(env.server.requests.last.body, containsPair('content', 'b'));
    },
  );
}
