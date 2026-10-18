import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/auth/session/session_providers.dart';
import 'package:tududa/common/undo/undo_controller.dart';
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/design/app_theme.dart';
import 'package:tududa/core/ids.dart';
import 'package:tududa/core/sync/sync_engine.dart';
import 'package:tududa/core/time/calendar_date.dart';
import 'package:tududa/core/time/date_formatters.dart';
import 'package:tududa/l10n/gen/app_localizations.dart';
import 'package:tududa/settings/providers/settings_provider.dart';
import 'package:tududa/tasks/domain/new_task.dart';
import 'package:tududa/tasks/domain/task.dart';
import 'package:tududa/tasks/providers/task_provider.dart';
import 'package:tududa/tasks/widgets/bulk_action_bar.dart';
import 'package:tududa/tasks/widgets/postpone_sheet.dart';
import 'package:tududa/tasks/widgets/selection_controller.dart';
import 'package:tududa/tasks/widgets/task_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../offline_rig.dart';

final _today = CalendarDate(2026, 10, 14);

Task _task(
  String name, {
  String uid = 't1',
  CalendarDate? due,
  Priority priority = Priority.low,
  String recurrence = 'none',
  List<Task> subtasks = const [],
  List<TaskTag> tags = const [],
  int moves = 0,
  TaskStatus status = TaskStatus.notStarted,
}) => Task(
  uid: TaskUid(uid),
  name: name,
  dueDate: due,
  priority: priority,
  recurrenceType: recurrence,
  subtasks: subtasks,
  tags: tags,
  todayMoveCount: moves,
  status: status,
);

void main() {
  setUpAll(DateFormats.ensureInitialized);

  late OfflineRig rig;

  setUp(() async {
    rig = OfflineRig();
    await rig.init();
  });

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Locale locale = const Locale('en'),
    double textScale = 1,
    bool withDb = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final sp = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sp),
          taskDayProvider.overrideWithValue(TaskDay.utc(_today)),
          if (withDb) ...[
            appDatabaseProvider.overrideWithValue(rig.db),
            syncEngineProvider.overrideWithValue(rig.engine),
            userClockProvider.overrideWithValue(rig.clock),
          ],
        ],
        child: MaterialApp(
          theme: buildTheme(
            brightness: Brightness.light,
            contrast: ContrastLevel.standard,
            density: DensityLevel.comfortable,
            reduceMotion: false,
          ),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, c) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: c!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(child: child),
            bottomNavigationBar: const BulkActionBar(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('indicators', () {
    testWidgets('overdue, subtasks, recurrence, tags, postponed', (t) async {
      final sub = [
        _task('s1', uid: 's1', status: TaskStatus.done),
        _task('s2', uid: 's2'),
        _task('s3', uid: 's3'),
        _task('s4', uid: 's4'),
      ];
      await pump(
        t,
        TaskTile(
          task: _task(
            'Write report',
            due: _today.addDays(-3),
            priority: Priority.high,
            recurrence: 'daily',
            subtasks: sub,
            moves: 2,
            tags: const [
              TaskTag(name: 'a'),
              TaskTag(name: 'b'),
              TaskTag(name: 'c'),
              TaskTag(name: 'd'),
            ],
          ),
          onTap: () {},
        ),
      );
      expect(find.text('3 days overdue'), findsOneWidget);
      expect(find.text('1/4'), findsOneWidget);
      expect(find.byIcon(Icons.repeat), findsOneWidget);
      expect(find.text('Postponed ×2'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
      expect(find.text('c'), findsNothing);
      // First 3 subtasks previewed.
      expect(find.text('s3'), findsOneWidget);
      expect(find.text('s4'), findsNothing);
      final overdue = t.widget<Text>(find.text('3 days overdue'));
      expect(overdue.style?.color, isNotNull);
    });

    testWidgets('done task is struck through', (t) async {
      await pump(t, TaskTile(task: _task('Done', status: TaskStatus.done)));
      final text = t.widget<Text>(find.text('Done'));
      expect(text.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('showDueDate/showProject false hide them', (t) async {
      await pump(
        t,
        TaskTile(
          task: _task('X', due: _today).copyWith(projectName: 'Proj'),
          showDueDate: false,
          showProject: false,
        ),
      );
      expect(find.text('Today'), findsNothing);
      expect(find.text('Proj'), findsNothing);
    });
  });

  group('accessibility', () {
    testWidgets('label and custom actions', (t) async {
      final handle = t.ensureSemantics();
      await pump(
        t,
        TaskTile(
          task: _task('Pay rent', due: _today, priority: Priority.high),
          onTap: () {},
        ),
      );
      final node = t.getSemantics(find.bySemanticsLabel(RegExp('^Pay rent')));
      expect(node.label, contains('Due Today'));
      expect(node.label, contains('Priority High'));
      final data = node.getSemanticsData();
      final labels = [
        for (final id in data.customSemanticsActionIds!)
          CustomSemanticsAction.getAction(id)!.label,
      ];
      expect(labels, containsAll(['Complete', 'Postpone', 'Delete', 'Edit']));
      handle.dispose();
    });
  });

  group('layout', () {
    testWidgets('text scale 2.0 does not overflow', (t) async {
      await pump(
        t,
        TaskTile(
          task: _task(
            'A rather long task title that has to wrap on small screens',
            due: _today.addDays(-1),
            priority: Priority.medium,
            recurrence: 'weekly',
            moves: 3,
            subtasks: [_task('sub', uid: 's')],
            tags: const [
              TaskTag(name: 'errands'),
              TaskTag(name: 'home'),
            ],
          ).copyWith(projectName: 'Household', estimatedMinutes: 30),
        ),
        textScale: 2,
      );
      expect(t.takeException(), isNull);
      expect(t.getSize(find.byType(TaskTile)).height, greaterThan(56));
    });

    for (final loc in const [Locale('de'), Locale('zh')]) {
      testWidgets('smoke ${loc.languageCode}', (t) async {
        await pump(
          t,
          TaskTile(
            task: _task('Test', due: _today.addDays(-2), recurrence: 'daily'),
          ),
          locale: loc,
        );
        expect(t.takeException(), isNull);
        final l = lookupAppLocalizations(loc);
        expect(find.text(l.tileOverdueDays(2)), findsOneWidget);
      });
    }
  });

  group('selection', () {
    testWidgets('long press selects, tap toggles, bar shows count', (t) async {
      await pump(
        t,
        Column(
          children: [
            TaskTile(
              task: _task('A', uid: 'a'),
              onTap: () {},
            ),
            TaskTile(
              task: _task('B', uid: 'b'),
              onTap: () {},
            ),
          ],
        ),
      );
      final c = ProviderScope.containerOf(t.element(find.byType(Column).first));
      await t.longPress(find.text('A'));
      await t.pump();
      expect(c.read(taskSelectionProvider), {'a'});
      expect(find.text('1 selected'), findsOneWidget);
      await t.tap(find.text('B'));
      await t.pump();
      expect(c.read(taskSelectionProvider), {'a', 'b'});
      expect(find.text('2 selected'), findsOneWidget);
      await t.tap(find.text('A'));
      await t.pump();
      expect(c.read(taskSelectionProvider), {'b'});
      await t.tap(find.byTooltip('Clear selection'));
      await t.pump();
      expect(c.read(taskSelectionProvider), isEmpty);
      expect(find.textContaining('selected'), findsNothing);
    });

    testWidgets('bulk complete completes all and undo restores', (t) async {
      final a = (await t.runAsync(
        () => rig.repo.create(const NewTask(name: 'A')),
      ))!;
      final b = (await t.runAsync(
        () => rig.repo.create(const NewTask(name: 'B')),
      ))!;
      await pump(
        t,
        Column(
          children: [
            TaskTile(task: a, onTap: () {}),
            TaskTile(task: b, onTap: () {}),
          ],
        ),
        withDb: true,
      );
      await t.longPress(find.text('A'));
      await t.pump();
      await t.tap(find.text('B'));
      await t.pump();
      await t.tap(find.byTooltip('Complete'));
      await t.runAsync(() => pumpEventQueue());
      await t.pump();
      expect(find.text('2 tasks completed'), findsOneWidget);
      var rows = (await t.runAsync(
        () => Future.wait([rig.row(a.uid.value), rig.row(b.uid.value)]),
      ))!;
      expect(rows.every((r) => r.status == TaskStatus.done.code), isTrue);

      await t.pump(const Duration(milliseconds: 500));
      await t.tap(find.text('Undo'));
      await t.runAsync(() => pumpEventQueue());
      rows = (await t.runAsync(
        () => Future.wait([rig.row(a.uid.value), rig.row(b.uid.value)]),
      ))!;
      expect(rows.every((r) => r.status != TaskStatus.done.code), isTrue);
      // Unmount so drift streams are closed before the rig tears down.
      await t.pumpWidget(const SizedBox());
    });
  });

  group('editing', () {
    testWidgets('double tap title, edit, submit saves', (t) async {
      final task = (await t.runAsync(
        () => rig.repo.create(const NewTask(name: 'Old')),
      ))!;
      await pump(t, TaskTile(task: task, onTap: () {}), withDb: true);
      await t.tap(find.text('Old'));
      await t.pump(const Duration(milliseconds: 50));
      await t.tap(find.text('Old'));
      await t.pump(const Duration(milliseconds: 50));
      expect(find.byType(TextField), findsOneWidget);
      await t.enterText(find.byType(TextField), 'New name');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.runAsync(() => pumpEventQueue());
      await t.pump();
      expect(find.byType(TextField), findsNothing);
      final row = (await t.runAsync(() => rig.row(task.uid.value)))!;
      expect(row.name, 'New name');
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('escape cancels without saving', (t) async {
      final task = (await t.runAsync(
        () => rig.repo.create(const NewTask(name: 'Keep')),
      ))!;
      await pump(t, TaskTile(task: task, onTap: () {}), withDb: true);
      await t.tap(find.text('Keep'));
      await t.pump(const Duration(milliseconds: 50));
      await t.tap(find.text('Keep'));
      await t.pump(const Duration(milliseconds: 50));
      await t.enterText(find.byType(TextField), 'Changed');
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.runAsync(() => pumpEventQueue());
      await t.pump();
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Keep'), findsOneWidget);
      final row = (await t.runAsync(() => rig.row(task.uid.value)))!;
      expect(row.name, 'Keep');
      await t.pumpWidget(const SizedBox());
    });
  });

  group('swipe + undo', () {
    testWidgets('swipe completes, undo restores and drops the outbox entry', (
      t,
    ) async {
      final task = (await t.runAsync(
        () => rig.repo.create(const NewTask(name: 'Swipe me')),
      ))!;
      final before = (await t.runAsync(() => rig.outbox()))!.length;
      await pump(t, TaskTile(task: task, onTap: () {}), withDb: true);

      await t.fling(find.text('Swipe me'), const Offset(700, 0), 1500);
      await t.pumpAndSettle();
      await t.runAsync(() => pumpEventQueue());
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Task completed'), findsOneWidget);
      var row = (await t.runAsync(() => rig.row(task.uid.value)))!;
      expect(row.status, TaskStatus.done.code);
      expect((await t.runAsync(() => rig.outbox()))!.length, before + 1);

      await t.pump(const Duration(milliseconds: 500));
      await t.tap(find.text('Undo'));
      await t.runAsync(() => pumpEventQueue());
      await t.pump();
      row = (await t.runAsync(() => rig.row(task.uid.value)))!;
      expect(row.status, isNot(TaskStatus.done.code));
      expect((await t.runAsync(() => rig.outbox()))!.length, before);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('swipe the other way reveals postpone and priority', (t) async {
      await pump(t, TaskTile(task: _task('Swipe'), onTap: () {}));
      await t.fling(find.text('Swipe'), const Offset(-300, 0), 1000);
      await t.pumpAndSettle();
      expect(find.text('Postpone'), findsOneWidget);
      expect(find.text('Priority'), findsOneWidget);
    });
  });

  group('postpone', () {
    test('weekend and next week dates', () {
      final wed = CalendarDate(2026, 10, 14);
      expect(wed.weekday, 3);
      expect(thisWeekend(wed), CalendarDate(2026, 10, 17));
      expect(
        thisWeekend(CalendarDate(2026, 10, 17)),
        CalendarDate(2026, 10, 24),
      );
      expect(
        thisWeekend(CalendarDate(2026, 10, 18)),
        CalendarDate(2026, 10, 24),
      );
      final mon = DateFormats(const Locale('de'));
      final sun = DateFormats(const Locale('en'));
      expect(nextWeekStart(wed, mon), CalendarDate(2026, 10, 19));
      expect(nextWeekStart(wed, sun), CalendarDate(2026, 10, 18));
    });

    testWidgets('tomorrow postpones; recurring offers skip', (t) async {
      final task = (await t.runAsync(
        () => rig.repo.create(
          NewTask(name: 'P', dueDate: _today, recurrenceType: 'daily'),
        ),
      ))!;
      await pump(t, TaskTile(task: task, onTap: () {}), withDb: true);
      await t.tap(find.byTooltip('More actions'));
      await t.pumpAndSettle();
      await t.tap(find.text('Postpone'));
      await t.pumpAndSettle();
      expect(find.text('Skip this occurrence'), findsOneWidget);
      await t.tap(find.text('Tomorrow').last);
      await t.runAsync(() => pumpEventQueue());
      await t.pumpAndSettle();
      final row = (await t.runAsync(() => rig.row(task.uid.value)))!;
      expect(row.dueDate, _today.addDays(1).toIso());
      expect(find.text('Task postponed'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  });

  test('UndoController is exposed as a provider', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(undoControllerProvider), isA<UndoController>());
  });
}
