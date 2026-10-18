import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/ids.dart';
import 'package:tududa/core/time/calendar_date.dart';
import 'package:tududa/tasks/domain/new_task.dart';
import 'package:tududa/tasks/domain/task.dart';
import 'package:tududa/tasks/providers/task_provider.dart';
import 'package:tududa/tasks/providers/today_provider.dart';
import 'package:tududa/tasks/screens/daily_review_screen.dart';
import 'package:tududa/tasks/screens/focus_screen.dart';
import 'package:tududa/tasks/screens/today_screen.dart';

import '../lists/list_test_support.dart';
import '../offline_rig.dart';

final _today = CalendarDate(2026, 10, 18);

Task _t(
  String name, {
  CalendarDate? due,
  LocalTime? time,
  TaskStatus status = TaskStatus.notStarted,
  int? minutes,
}) => Task(
  uid: TaskUid(name),
  name: name,
  dueDate: due,
  dueTime: time,
  status: status,
  estimatedMinutes: minutes,
);

TodaySections _build({
  List<Task> overdue = const [],
  List<Task> dueToday = const [],
  List<Task> plan = const [],
  List<Task> done = const [],
}) => buildTodaySections(
  today: _today,
  overdue: overdue,
  dueToday: dueToday,
  todayPlan: plan,
  completedToday: done,
);

void main() {
  group('buildTodaySections', () {
    test('boundary times fall in the right part of the day', () {
      final s = _build(
        dueToday: [
          _t('a1159', due: _today, time: const LocalTime(11, 59)),
          _t('b1200', due: _today, time: const LocalTime(12, 0)),
          _t('c1759', due: _today, time: const LocalTime(17, 59)),
          _t('d1800', due: _today, time: const LocalTime(18, 0)),
          _t('e', due: _today),
        ],
      );
      expect(s.morning.map((t) => t.name), ['a1159']);
      expect(s.afternoon.map((t) => t.name), ['b1200', 'c1759']);
      expect(s.evening.map((t) => t.name), ['d1800']);
      expect(s.anytime.map((t) => t.name), ['e']);
    });

    test('a task is listed once: overdue, then due today, then the plan', () {
      final late = _t('x', due: _today.addDays(-1));
      final now = _t('y', due: _today);
      final s = _build(
        overdue: [late],
        dueToday: [
          now,
          _t('x', due: _today.addDays(-1)),
        ],
        plan: [
          _t('y', due: _today),
          _t('z', status: TaskStatus.planned),
        ],
      );
      expect(s.overdue.map((t) => t.name), ['x']);
      expect(s.remaining.map((t) => t.name).toList()..sort(), ['x', 'y', 'z']);
      expect(s.remaining, hasLength(3));
    });

    test('progress and estimated minutes', () {
      final s = _build(
        dueToday: [
          _t('a', due: _today, minutes: 30),
          _t('b', minutes: 45),
        ],
        plan: [_t('c', status: TaskStatus.planned)],
        done: [_t('d'), _t('e', minutes: 99)],
      );
      expect(s.doneCount, 2);
      expect(s.totalCount, 5);
      expect(s.progress, closeTo(0.4, 1e-9));
      expect(s.remainingMinutes, 75);
      expect(_build().progress, 0);
      expect(_build().isEmpty, isTrue);
    });
  });

  group('TodayScreen', () {
    late OfflineRig rig;

    setUp(() async {
      rig = OfflineRig();
      await rig.init();
    });

    testWidgets('sections, counts and header', (tester) async {
      // Tall enough that the lazy list builds every section.
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final today = rig.today().date;
      Future<void> mk(String n, {LocalTime? time, int? min}) => seed(
        tester,
        () => rig.repo.create(
          NewTask(
            name: n,
            dueDate: today,
            dueTime: time,
            estimatedMinutes: min,
          ),
        ),
      );
      await mk('m', time: const LocalTime(11, 59), min: 30);
      await mk('n', time: const LocalTime(12, 0), min: 60);
      await mk('e', time: const LocalTime(18, 0));
      await mk('any');
      await seed(
        tester,
        () => rig.repo.create(NewTask(name: 'old', dueDate: today.addDays(-2))),
      );
      await pumpWithRig(tester, rig, home: const TodayScreen());
      await settle(tester);

      String count(String id) => (tester.widget(
        find.byKey(Key('today.section.$id.count')),
      ) as Text).data!;
      for (final id in [
        'overdue',
        'morning',
        'afternoon',
        'evening',
        'anytime',
      ]) {
        expect(count(id), '1', reason: id);
      }
      expect(find.byKey(const Key('today.section.completed')), findsNothing);
      expect(find.text('0 of 5 done'), findsOneWidget);
      expect(find.text('1 h 30 min left'), findsOneWidget);
      expect(find.byKey(const Key('today.ring')), findsOneWidget);
      expect(find.byKey(const Key('today.rescheduleAll')), findsOneWidget);

      // Collapse a section.
      expect(find.text('m'), findsOneWidget);
      await tester.tap(find.byKey(const Key('today.section.morning')));
      await tester.pump();
      expect(find.text('m'), findsNothing);
      await unmount(tester);
    });

    testWidgets('completing moves a task to the collapsed completed section', (
      tester,
    ) async {
      final today = rig.today().date;
      final t = await seed(
        tester,
        () => rig.repo.create(NewTask(name: 'one', dueDate: today)),
      );
      await seed(
        tester,
        () => rig.repo.create(NewTask(name: 'two', dueDate: today)),
      );
      await pumpWithRig(tester, rig, home: const TodayScreen());
      await settle(tester);
      expect(find.text('0%'), findsOneWidget);
      await seed(tester, () => rig.repo.complete(t.uid));
      await settle(tester);
      expect(find.text('1 of 2 done'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(
        (tester.widget(
          find.byKey(const Key('today.section.completed.count')),
        ) as Text).data,
        '1',
      );
      await unmount(tester);
    });

    testWidgets('empty state', (tester) async {
      await pumpWithRig(tester, rig, home: const TodayScreen());
      await settle(tester);
      expect(find.byKey(const Key('today.empty')), findsOneWidget);
      expect(find.text('All done for today'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('error state retries', (tester) async {
      var fail = true;
      await pumpWithRig(
        tester,
        rig,
        home: const TodayScreen(),
        overrides: [
          todaySectionsProvider.overrideWith((ref) {
            ref.watch(taskViewListProvider(TaskView.overdue));
            return fail
                ? AsyncError(Exception('x'), StackTrace.empty)
                : const AsyncData(TodaySections());
          }),
        ],
      );
      await settle(tester);
      expect(find.byKey(const Key('today.error')), findsOneWidget);
      fail = false;
      await tester.tap(find.byKey(const Key('today.retry')));
      await settle(tester);
      expect(find.byKey(const Key('today.error')), findsNothing);
      expect(find.byKey(const Key('today.empty')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('loading state shows a skeleton', (tester) async {
      await pumpWithRig(
        tester,
        rig,
        home: const TodayScreen(),
        overrides: [
          todaySectionsProvider.overrideWithValue(const AsyncLoading()),
        ],
      );
      expect(find.byKey(const Key('today.loading')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('text scale 2.0 does not overflow', (tester) async {
      final today = rig.today().date;
      await seed(
        tester,
        () => rig.repo.create(
          NewTask(
            name: 'A rather long task name that has to wrap on small screens',
            dueDate: today.addDays(-1),
            estimatedMinutes: 90,
          ),
        ),
      );
      await seed(
        tester,
        () => rig.repo.create(NewTask(name: 'B', dueDate: today)),
      );
      await pumpWithRig(tester, rig, home: const TodayScreen(), textScale: 2.0);
      await settle(tester);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    for (final code in ['de', 'zh']) {
      testWidgets('smoke in $code', (tester) async {
        final today = rig.today().date;
        await seed(
          tester,
          () => rig.repo.create(NewTask(name: 'A', dueDate: today)),
        );
        await pumpWithRig(
          tester,
          rig,
          home: const TodayScreen(),
          locale: Locale(code),
        );
        await settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('Today'), findsNothing);
        expect(find.byKey(const Key('today.progress')), findsOneWidget);
        await unmount(tester);
      });
    }
  });

  group('DailyReviewScreen', () {
    late OfflineRig rig;

    setUp(() async {
      rig = OfflineRig();
      await rig.init();
    });

    testWidgets('steps through tasks and summarises', (tester) async {
      final today = rig.today().date;
      final a = await seed(
        tester,
        () => rig.repo.create(NewTask(name: 'a', dueDate: today)),
      );
      final b = await seed(
        tester,
        () => rig.repo.create(NewTask(name: 'b', dueDate: today)),
      );
      final c = await seed(
        tester,
        () => rig.repo.create(NewTask(name: 'c', dueDate: today)),
      );
      await pumpWithRig(tester, rig, home: const DailyReviewScreen());
      await settle(tester);
      expect(find.text('Task 1 of 3'), findsOneWidget);

      await tester.tap(find.byKey(const Key('review.done')));
      await settle(tester);
      expect(find.text('Task 2 of 3'), findsOneWidget);
      await tester.tap(find.byKey(const Key('review.tomorrow')));
      await settle(tester);
      expect(find.text('Task 3 of 3'), findsOneWidget);
      await tester.tap(find.byKey(const Key('review.someday')));
      await settle(tester);

      expect(find.byKey(const Key('review.summary')), findsOneWidget);
      expect(find.text('1 task completed'), findsOneWidget);
      expect(find.text('1 task rescheduled'), findsOneWidget);
      expect(find.text('1 task moved to Someday'), findsOneWidget);

      final rows = await tester.runAsync(
        () async => [
          await rig.dao.byAnyId(a.uid.value),
          await rig.dao.byAnyId(b.uid.value),
          await rig.dao.byAnyId(c.uid.value),
        ],
      );
      expect(rows![0]!.status, TaskStatus.done.code);
      expect(rows[1]!.dueDate, today.addDays(1).toIso());
      expect(rows[2]!.dueDate, isNull);
      await unmount(tester);
    });

    testWidgets('empty review and text scale 2.0', (tester) async {
      await pumpWithRig(
        tester,
        rig,
        home: const DailyReviewScreen(),
        textScale: 2.0,
      );
      await settle(tester);
      expect(find.text('No open tasks to review.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('review page at text scale 2.0 and zh', (tester) async {
      final today = rig.today().date;
      await seed(
        tester,
        () => rig.repo.create(NewTask(name: 'a', dueDate: today)),
      );
      await pumpWithRig(
        tester,
        rig,
        home: const DailyReviewScreen(),
        textScale: 2.0,
        locale: const Locale('zh'),
      );
      await settle(tester);
      expect(find.byKey(const Key('review.keep')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });

  group('FocusScreen', () {
    late OfflineRig rig;

    setUp(() async {
      rig = OfflineRig();
      await rig.init();
    });

    testWidgets('starts the task, skips and completes', (tester) async {
      final today = rig.today().date;
      final a = await seed(
        tester,
        () => rig.repo.create(NewTask(name: 'a', dueDate: today)),
      );
      final b = await seed(
        tester,
        () => rig.repo.create(NewTask(name: 'b', dueDate: today)),
      );
      await pumpWithRig(tester, rig, home: const FocusScreen(), textScale: 2.0);
      await settle(tester);
      await settle(tester);
      expect(find.byKey(const Key('focus.title')), findsOneWidget);
      expect(tester.takeException(), isNull);
      final first =
          (tester.widget(find.byKey(const Key('focus.title'))) as Text).data!;

      await tester.ensureVisible(find.byKey(const Key('focus.skip')));
      await tester.tap(find.byKey(const Key('focus.skip')));
      await settle(tester);
      final second =
          (tester.widget(find.byKey(const Key('focus.title'))) as Text).data!;
      expect(second, isNot(first));

      await tester.ensureVisible(find.byKey(const Key('focus.done')));
      await tester.tap(find.byKey(const Key('focus.done')));
      await settle(tester);
      final rows = await seed(
        tester,
        () async => [
          for (final id in [a.uid.value, b.uid.value])
            (await rig.dao.byAnyId(id))!.status,
        ],
      );
      // The task that was skipped stays in progress, the other is done.
      expect(
        rows,
        unorderedEquals([TaskStatus.inProgress.code, TaskStatus.done.code]),
      );
      await unmount(tester);
    });

    testWidgets('empty state', (tester) async {
      await pumpWithRig(tester, rig, home: const FocusScreen());
      await settle(tester);
      expect(find.byKey(const Key('focus.empty')), findsOneWidget);
      await unmount(tester);
    });
  });
}
