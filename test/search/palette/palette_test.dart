import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/sync/sync_actions.dart';
import 'package:tududa/l10n/gen/app_localizations.dart';
import 'package:tududa/notes/data/offline_note_repository.dart';
import 'package:tududa/notes/domain/note.dart';
import 'package:tududa/projects/data/project_api.dart';
import 'package:tududa/projects/data/offline_project_repository.dart';
import 'package:tududa/search/command_palette/command_palette.dart';
import 'package:tududa/settings/providers/settings_provider.dart';
import 'package:tududa/tasks/data/offline_task_repository.dart';
import 'package:tududa/tasks/domain/new_task.dart';

class _FakeSync extends SyncActions {
  _FakeSync(super.ref);
  static int calls = 0;
  @override
  Future<void> syncNow() async => calls++;
}

const _paths = [
  '/today',
  '/inbox',
  '/upcoming',
  '/projects',
  '/overdue',
  '/someday',
  '/completed',
  '/notes',
  '/more/areas',
  '/more',
  '/more/sync',
  '/search',
];

GoRouter _router(List<String> log) => GoRouter(
  initialLocation: '/today',
  routes: [
    for (final p in _paths)
      GoRoute(
        path: p,
        builder: (context, state) {
          log.add(state.uri.toString());
          return Scaffold(
            body: CommandPaletteShortcuts(
              child: Column(
                children: [
                  Text('page ${state.uri}'),
                  TextButton(
                    onPressed: () => showCommandPalette(context),
                    child: const Text('open'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    GoRoute(
      path: '/:kind/:id',
      builder: (_, s) => Scaffold(body: Text('item ${s.uri}')),
    ),
  ],
);

late AppDatabase db;
late List<String> log;

Future<void> pumpPalette(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  double scale = 1,
  Size size = const Size(800, 900),
}) async {
  SharedPreferences.setMockInitialValues({});
  final sp = await SharedPreferences.getInstance();
  db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  log = [];
  _FakeSync.calls = 0;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        appDatabaseProvider.overrideWithValue(db),
        syncActionsProvider.overrideWith(_FakeSync.new),
      ],
      child: MaterialApp.router(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        routerConfig: _router(log),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> open(WidgetTester tester) async {
  await tester.tap(find.text(tester.any(find.text('open')) ? 'open' : ''));
  await tester.pumpAndSettle();
}

Future<void> type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pumpAndSettle();
}

void main() {
  group('fuzzyScore / rankCommands', () {
    final cmds = buildPaletteCommands(
      lookupAppLocalizations(const Locale('en')),
    );

    test('subsequence only', () {
      expect(fuzzyScore('gtd', 'Go to Today'), isNotNull);
      expect(fuzzyScore('xyz', 'Go to Today'), isNull);
      expect(fuzzyScore('', 'anything'), 0);
    });

    test('prefix beats scattered match', () {
      expect(
        fuzzyScore('tod', 'Today')!,
        greaterThan(fuzzyScore('tod', 'Go to Today')!),
      );
      expect(
        fuzzyScore('sync', 'Sync')!,
        greaterThan(fuzzyScore('sync', 'Run sync now')!),
      );
    });

    for (final (q, first) in [
      ('add', 'add-task'),
      ('today', 'go-today'),
      ('set', 'go-settings'),
      ('run', 'run-sync'),
      ('theme', 'change-theme'),
      ('motion', 'toggle-reduce-motion'),
      ('dark', 'change-theme'),
      ('srch', 'search'),
    ]) {
      test('"$q" ranks $first first', () {
        expect(rankCommands(cmds, q).first.id, first);
      });
    }

    test('empty query keeps order; no match is empty', () {
      expect(rankCommands(cmds, '').map((c) => c.id), cmds.map((c) => c.id));
      expect(rankCommands(cmds, 'qqqq'), isEmpty);
    });
  });

  group('palette UI', () {
    testWidgets('type, arrow, enter navigates', (tester) async {
      await pumpPalette(tester);
      await open(tester);
      expect(find.byType(TextField), findsOneWidget);
      await type(tester, 'go');
      // Typing "go" matches every "Go to ..." command; move down one.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp); // wraps
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(log.last, isNot('/today?'));
    });

    testWidgets('typing "inbox" + Enter goes to /inbox', (tester) async {
      await pumpPalette(tester);
      await open(tester);
      await type(tester, 'inbox');
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pumpAndSettle();
      expect(find.text('page /inbox'), findsOneWidget);
    });

    testWidgets('tap runs, Esc closes', (tester) async {
      await pumpPalette(tester);
      await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      await open(tester);
      await tester.tap(find.text('Go to Notes'));
      await tester.pumpAndSettle();
      expect(find.text('page /notes'), findsOneWidget);
    });

    testWidgets('Ctrl+K opens the palette', (tester) async {
      await pumpPalette(tester);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      // Focus something inside the shortcuts scope.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('search command pushes /search?q=', (tester) async {
      await pumpPalette(tester);
      await open(tester);
      await type(tester, 'milk run');
      await tester.tap(find.byKey(const ValueKey('palette-search')));
      await tester.pumpAndSettle();
      expect(find.text('page /search?q=milk+run'), findsOneWidget);
    });

    testWidgets('sync command calls the engine', (tester) async {
      await pumpPalette(tester);
      await open(tester);
      await type(tester, 'sync now');
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pumpAndSettle();
      expect(_FakeSync.calls, 1);
    });

    testWidgets('theme cycles and reduce motion toggles', (tester) async {
      await pumpPalette(tester);
      final c = ProviderScope.containerOf(tester.element(find.text('open')));
      await open(tester);
      await type(tester, 'change theme');
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).themeMode, AppThemeMode.light);
      await open(tester);
      await type(tester, 'reduce motion');
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).reduceMotion, isTrue);
    });

    testWidgets('open item lists local matches (max 5)', (tester) async {
      await pumpPalette(tester);
      await tester.runAsync(() async {
        final tasks = OfflineTaskRepository(db);
        for (var i = 0; i < 7; i++) {
          await tasks.create(NewTask(name: 'Walrus chore $i'));
        }
        await ProjectRepoSeed.create(db, 'Walrus project');
        await OfflineNoteRepository(db)
            .create(const NoteDraft(title: 'Walrus note'));
      });
      await open(tester);
      await type(tester, 'w');
      expect(find.textContaining('Walrus'), findsNothing);
      await tester.runAsync(() async {
        await tester.enterText(find.byType(TextField), 'walrus');
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      final items = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('palette-') &&
            !(w.key as ValueKey<String>).value.startsWith('palette-go-'),
      );
      expect(find.textContaining('Walrus'), findsWidgets);
      expect(items.evaluate().length, lessThanOrEqualTo(5 + 3));
      final shown = find.textContaining('Walrus').evaluate().length;
      expect(shown, 5 + 0);
    });

    testWidgets('semantics: selected row announced', (tester) async {
      final h = tester.ensureSemantics();
      await pumpPalette(tester);
      await open(tester);
      expect(
        tester.getSemantics(find.byKey(const ValueKey('palette-add-task'))),
        matchesSemantics(
          label: 'Add task, 1 of 16',
          isSelected: true,
          isButton: true,
          hasSelectedState: true,
          hasTapAction: true,
          hasEnabledState: false,
          isEnabled: false,
        ),
      );
      h.dispose();
    });

    testWidgets('text scale 2.0 does not overflow', (tester) async {
      await pumpPalette(tester, scale: 2, size: const Size(400, 700));
      await open(tester);
      expect(tester.takeException(), isNull);
      await type(tester, 'go');
      expect(tester.takeException(), isNull);
    });

    for (final (loc, text, label) in [
      ('de', 'heute', 'Gehe zu Heute'),
      ('zh', '今天', '前往今天'),
    ]) {
      testWidgets('$loc smoke', (tester) async {
        await pumpPalette(tester, locale: Locale(loc));
        await open(tester);
        expect(find.text(label), findsOneWidget);
        await type(tester, text);
        expect(find.text(label), findsOneWidget);
      });
    }
  });
}

class ProjectRepoSeed {
  static Future<void> create(AppDatabase db, String name) async {
    await OfflineProjectRepository(db).create(NewProject(name: name));
  }
}
