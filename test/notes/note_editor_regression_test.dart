import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tududa/core/api/api_providers.dart';
import 'package:tududa/core/api/patch.dart' show Patch;
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/ids.dart';
import 'package:tududa/core/sync/sync_engine.dart';
import 'package:tududa/l10n/gen/app_localizations.dart';
import 'package:tududa/notes/data/note_patch.dart';
import 'package:tududa/notes/domain/note.dart';
import 'package:tududa/notes/providers/note_provider.dart';
import 'package:tududa/notes/screens/note_editor_screen.dart';
import 'package:tududa/settings/providers/settings_provider.dart';

import '../support/fake_tududi/routes/notes_routes.dart';
import 'note_test_env.dart';

void main() {
  // Regression: the list opens /notes/<uid>, so the editor only ever knew the
  // uid. Updating used `note.id!` and always failed. Everything goes by uid,
  // and now also works offline.
  test('a note opened only by uid can be loaded and edited', () async {
    final env = await OfflineEnv.create();
    addTearDown(env.dispose);
    seedNote(env.server, uid: 'abc123', title: 'Old', content: 'body');
    await env.sync();
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(env.db),
        noteRepositoryProvider.overrideWithValue(env.notes),
      ],
    );
    addTearDown(c.dispose);

    const uid = NoteUid('abc123');
    final loaded = await c.read(noteRepositoryProvider).get(uid);
    expect(loaded.uid, uid);

    await c
        .read(noteListProvider.notifier)
        .updateNote(uid, const NotePatch(title: Patch.set('Edited')));
    // Saved locally without any request.
    expect(env.count('PATCH', '/note/abc123'), 0);
    await env.syncLater();

    final patch = env.server.requests.lastWhere((r) => r.method == 'PATCH');
    expect(patch.path, '/note/abc123');
    expect(patch.status, 200);
    expect(patch.body, containsPair('title', 'Edited'));
    expect(env.remote.notes['abc123']!['title'], 'Edited');
  });

  Future<(GoRouter, OfflineEnv)> pumpEditor(WidgetTester tester) async {
    final env = (await tester.runAsync(OfflineEnv.create))!;
    seedNote(env.server, uid: 'abc123', title: 'Old', content: 'body');
    await tester.runAsync(env.sync);
    SharedPreferences.setMockInitialValues({});
    final sp = await SharedPreferences.getInstance();
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Scaffold()),
        GoRoute(
          path: '/notes/:id',
          builder: (_, state) =>
              NoteEditorScreen(noteId: state.pathParameters['id']),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sp),
          appDatabaseProvider.overrideWithValue(env.db),
          syncEngineProvider.overrideWithValue(env.engine),
          noteRepositoryProvider.overrideWithValue(env.notes),
          dioProvider.overrideWithValue(env.stack.dio),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    return (router, env);
  }

  Future<void> settle(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 80 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  testWidgets(
    'NoteEditorScreen saves an edit offline, PATCH /note/<uid> later',
    (tester) async {
      final (router, env) = await pumpEditor(tester);
      router.push('/notes/abc123');
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await settle(tester, () => find.text('Old').evaluate().isNotEmpty);

      expect(find.text('Old'), findsOneWidget);
      await tester.enterText(find.text('Old'), 'Edited');
      await tester.tap(find.byType(TextButton));
      await settle(tester, () => false);
      await tester.pumpAndSettle();
      // Nothing was sent while saving.
      expect(env.count('PATCH', '/note/abc123'), 0);
      final saved = await tester.runAsync(
        () => env.notes.get(const NoteUid('abc123')),
      );
      expect(saved!.title, 'Edited');
      // Unmount first so no stream of the fake-async zone is live while the
      // engine runs.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(env.syncLater);
      final patch = env.server.requests.lastWhere((r) => r.method == 'PATCH');
      expect(patch.path, '/note/abc123');
      expect(patch.status, 200);
      expect(patch.body, containsPair('title', 'Edited'));
      expect(env.remote.notes['abc123']!['title'], 'Edited');
      await tester.runAsync(env.dispose);
    },
  );

  testWidgets('the editor opens a note that has no uid by its local id', (
    tester,
  ) async {
    final (router, env) = await pumpEditor(tester);
    final local = (await tester.runAsync(
      () => env.notes.create(const NoteDraft(title: 'Draft', content: 'x')),
    ))!;
    router.push('/notes/${local.localId!.value}');
    await settle(tester, () => find.text('Draft').evaluate().isNotEmpty);
    expect(find.text('Draft'), findsOneWidget);

    await tester.enterText(find.text('Draft'), 'Draft 2');
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    final saved = await tester.runAsync(
      () => env.notes.getByLocalId(local.localId!),
    );
    expect(saved!.title, 'Draft 2');
    // Still one create entry carrying the final text.
    final entries = (await tester.runAsync(env.outbox))!;
    expect(entries, hasLength(1));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
