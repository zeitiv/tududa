import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tududa/notes/screens/note_editor_screen.dart';
import 'package:tududa/settings/providers/settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/api/api_providers.dart';
import 'package:tududa/core/ids.dart';
import 'package:tududa/notes/data/note_patch.dart';
import 'package:tududa/notes/providers/note_provider.dart';

import '../support/fake_tududi/routes/notes_routes.dart';
import 'note_test_env.dart';

import 'package:tududa/core/api/patch.dart' show Patch;

void main() {
  // Regression: the list opens /notes/<uid>, so the editor only ever knew the
  // uid. Updating used `note.id!` and always failed. Everything goes by uid.
  test('a note opened only by uid can be loaded and edited', () async {
    final stack = await signedInStack();
    seedNote(stack.server, uid: 'abc123', title: 'Old', content: 'body');
    final c = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(stack.dio)],
    );
    addTearDown(c.dispose);

    const uid = NoteUid('abc123');
    final loaded = await c.read(noteRepositoryProvider).get(uid);
    expect(loaded.uid, uid);

    await c
        .read(noteListProvider.notifier)
        .updateNote(uid, const NotePatch(title: Patch.set('Edited')));

    final patch = stack.server.requests.lastWhere((r) => r.method == 'PATCH');
    expect(patch.path, '/note/abc123');
    expect(patch.status, 200);
    expect(patch.body, containsPair('title', 'Edited'));
    expect(notesStoreOf(stack.server).notes['abc123']!['title'], 'Edited');
  });

  testWidgets('NoteEditorScreen saves an edit through PATCH /note/<uid>', (
    tester,
  ) async {
    final stack = (await tester.runAsync(signedInStack))!;
    seedNote(stack.server, uid: 'abc123', title: 'Old', content: 'body');
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
          dioProvider.overrideWithValue(stack.dio),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.push('/notes/abc123');
    for (var i = 0; i < 40 && find.text('Old').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 25));
    }

    expect(find.text('Old'), findsOneWidget);
    await tester.enterText(find.text('Old'), 'Edited');
    await tester.tap(find.byType(TextButton));
    for (var i = 0; i < 40 && stack.count('PATCH', '/note/abc123') == 0; i++) {
      await tester.pump(const Duration(milliseconds: 25));
    }
    await tester.pumpAndSettle();

    final patch = stack.server.requests.lastWhere((r) => r.method == 'PATCH');
    expect(patch.path, '/note/abc123');
    expect(patch.status, 200);
    expect(patch.body, containsPair('title', 'Edited'));
    expect(notesStoreOf(stack.server).notes['abc123']!['title'], 'Edited');
  });
}
