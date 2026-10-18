import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tududa/areas/data/area_api.dart';
import 'package:tududa/auth/domain/user.dart';
import 'package:tududa/auth/providers/auth_provider.dart';
import 'package:tududa/core/router/app_router.dart';
import 'package:tududa/areas/data/offline_area_repository.dart';
import 'package:tududa/auth/session/session_providers.dart';
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/design/app_theme.dart';
import 'package:tududa/core/sync/sync_engine.dart';
import 'package:tududa/l10n/gen/app_localizations.dart';
import 'package:tududa/notes/data/offline_note_repository.dart';
import 'package:tududa/notes/domain/note.dart';
import 'package:tududa/projects/data/offline_project_repository.dart';
import 'package:tududa/projects/data/project_api.dart';
import 'package:tududa/settings/providers/settings_provider.dart';
import 'package:tududa/tasks/domain/new_task.dart';
import 'package:tududa/tasks/domain/task.dart';

import '../tasks/offline_rig.dart';

/// Shared harness of the accessibility tests: pumps a screen over the
/// in-memory offline stack (real theme, real l10n), in a given brightness,
/// locale and text scale, with some data seeded so lists are not empty.
///
/// Drift streams deadlock under fake async, so data is written inside
/// `runAsync` and every test unmounts the tree at the end (see [a11yTest]).

const a11yLocales = [Locale('en'), Locale('de')];
const a11yBrightnesses = [Brightness.light, Brightness.dark];

/// What [seedA11yData] created, for screens that need an id.
class A11ySeed {
  A11ySeed({
    required this.task,
    required this.subtask,
    required this.overdue,
    required this.projectId,
    required this.noteId,
    required this.areaId,
  });
  final Task task;
  final Task subtask;
  final Task overdue;
  final String projectId;
  final String noteId;
  final String areaId;
}

/// Runs [body] with semantics on, an initialised offline rig and data, and
/// unmounts the tree afterwards so drift's cleanup timers do not leak.
void a11yTest(
  String name,
  Future<void> Function(WidgetTester tester, OfflineRig rig, A11ySeed data)
  body,
) {
  testWidgets(name, (tester) async {
    final handle = tester.ensureSemantics();
    await initializeDateFormatting();
    final rig = OfflineRig();
    await tester.runAsync(rig.init);
    final data = await tester.runAsync(() => seedA11yData(rig));
    await body(tester, rig, data!);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    handle.dispose();
  });
}

Future<A11ySeed> seedA11yData(OfflineRig rig) async {
  final today = rig.today().date;
  final project = await OfflineProjectRepository(
    rig.db,
    now: () => rig.t,
  ).create(const NewProject(name: 'Website relaunch'));
  final area = await OfflineAreaRepository(
    rig.db,
    now: () => rig.t,
  ).create(const NewArea(name: 'Home'));
  final note = await OfflineNoteRepository(rig.db, now: () => rig.t).create(
    const NoteDraft(title: 'Groceries', content: 'Milk, eggs and **bread**'),
  );
  final task = await rig.repo.create(
    NewTask(
      name: 'Pay rent',
      note: 'Transfer before the first.',
      dueDate: today,
      priority: Priority.high,
      estimatedMinutes: 30,
      projectUid: project.uid,
      tags: const ['money'],
    ),
  );
  final subtask = await rig.repo.createSubtaskOf(task.uid, 'Check balance');
  final overdue = await rig.repo.create(
    NewTask(name: 'File taxes', dueDate: today.addDays(-2)),
  );
  await rig.repo.create(
    NewTask(
      name: 'Dentist',
      dueDate: today.addDays(2),
      projectUid: project.uid,
    ),
  );
  await rig.repo.create(
    NewTask(name: 'Learn guitar', status: TaskStatus.notStarted),
  );
  final done = await rig.repo.create(
    NewTask(name: 'Water plants', dueDate: today),
  );
  await rig.repo.complete(done.uid);
  return A11ySeed(
    task: task,
    subtask: subtask,
    overdue: overdue,
    projectId: project.uid.value,
    noteId: note.routeId!,
    areaId: area.uid.value,
  );
}

/// Pumps [home] inside a router (so `context.go/push` work) over [rig].
Future<void> pumpA11y(
  WidgetTester tester,
  OfflineRig rig, {
  required Widget home,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('en'),
  double textScale = 1,
  List<Override> overrides = const [],
  Size size = const Size(412, 892),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final sp = await SharedPreferences.getInstance();
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => home),
      GoRoute(
        path: '/:a',
        builder: (_, s) => Scaffold(body: Text('went ${s.uri}')),
      ),
      GoRoute(
        path: '/:a/:b',
        builder: (_, s) => Scaffold(body: Text('went ${s.uri}')),
      ),
      GoRoute(
        path: '/:a/:b/:c',
        builder: (_, s) => Scaffold(body: Text('went ${s.uri}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        appDatabaseProvider.overrideWithValue(rig.db),
        syncEngineProvider.overrideWithValue(rig.engine),
        userClockProvider.overrideWithValue(rig.clock),
        ...overrides,
      ],
      child: MaterialApp.router(
        locale: locale,
        theme: buildTheme(
          brightness: brightness,
          contrast: ContrastLevel.standard,
          density: DensityLevel.comfortable,
          reduceMotion: true,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: child!,
        ),
      ),
    ),
  );
  await settleA11y(tester);
}

/// Lets drift (real async) and the widget tree finish.
Future<void> settleA11y(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  // Entrance animations (fades) must finish, or contrast is measured on a
  // half-transparent screen. Not pumpAndSettle: spinners never settle.
  await tester.pump(const Duration(seconds: 2));
}

/// A page with one button that runs [onOpen] (sheets and dialogs).
class A11yLauncher extends ConsumerWidget {
  const A11yLauncher({super.key, required this.onOpen});
  final void Function(BuildContext context, WidgetRef ref) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: FilledButton(
        key: const Key('a11y.open'),
        onPressed: () => onOpen(context, ref),
        child: const Text('Open'),
      ),
    ),
  );
}

Future<void> tapLauncher(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('a11y.open')));
  await tester.pump();
  await settleA11y(tester);
  await tester.pump(const Duration(milliseconds: 400));
}

/// One screen (or sheet) under test.
class A11yCase {
  const A11yCase(
    this.name,
    this.home, {
    this.overrides,
    this.open,
    this.shows,
    this.size = const Size(412, 892),
  });
  final String name;
  final Widget Function(A11ySeed data) home;
  final List<Override> Function(A11ySeed data)? overrides;

  /// Runs after the first pump: opens a sheet, selects tasks, and so on.
  final Future<void> Function(WidgetTester tester, A11ySeed data)? open;
  final Size size;

  /// Text that must be on screen: stops a screen that fell into an error or
  /// empty state from passing the guidelines vacuously.
  final String? shows;
}

/// Pumps [c] and runs [open].
Future<void> pumpCase(
  WidgetTester tester,
  OfflineRig rig,
  A11ySeed data,
  A11yCase c, {
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('en'),
  double textScale = 1,
}) async {
  await pumpA11y(
    tester,
    rig,
    home: c.home(data),
    brightness: brightness,
    locale: locale,
    textScale: textScale,
    overrides: c.overrides?.call(data) ?? const [],
    size: c.size,
  );
  if (c.open != null) {
    await c.open!(tester, data);
    await settleA11y(tester);
  }
  if (c.shows != null && locale.languageCode == 'en' && textScale == 1) {
    expect(find.textContaining(c.shows!), findsWidgets, reason: c.name);
  }
}

/// Pumps the real app router (shell with bottom bar or rail, offline banner,
/// quick-add button) signed in, starting at [location].
Future<void> pumpA11yApp(
  WidgetTester tester,
  OfflineRig rig, {
  required String location,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('en'),
  double textScale = 1,
  List<Override> overrides = const [],
  Size size = const Size(412, 892),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final sp = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        appDatabaseProvider.overrideWithValue(rig.db),
        syncEngineProvider.overrideWithValue(rig.engine),
        userClockProvider.overrideWithValue(rig.clock),
        authProvider.overrideWith(
          (ref) => AuthNotifier()
            ..state = const AuthState(
              status: AuthStatus.authenticated,
              serverUrl: 'https://tududi.example.com',
              user: User(uid: 'u1', email: 'ada@example.com', name: 'Ada'),
            ),
        ),
        ...overrides,
      ],
      child: Consumer(
        builder: (context, ref, _) {
          final router = ref.watch(routerProvider);
          return MaterialApp.router(
            locale: locale,
            theme: buildTheme(
              brightness: brightness,
              contrast: ContrastLevel.standard,
              density: DensityLevel.comfortable,
              reduceMotion: true,
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
                disableAnimations: true,
              ),
              child: child!,
            ),
          );
        },
      ),
    ),
  );
  await tester.pump();
  ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
      .read(routerProvider)
      .go(location);
  await settleA11y(tester);
}
