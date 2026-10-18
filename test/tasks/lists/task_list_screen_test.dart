import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/ids.dart';
import 'package:tududa/core/sync/sync_engine.dart';
import 'package:tududa/core/sync/sync_handler.dart' show SyncReason;
import 'package:tududa/core/sync/sync_status.dart';
import 'package:tududa/core/time/calendar_date.dart';
import 'package:tududa/tasks/domain/new_task.dart';
import 'package:tududa/tasks/domain/task.dart';
import 'package:tududa/tasks/screens/task_list_screen.dart';

import '../offline_rig.dart';
import 'list_test_support.dart';

Task _task(String name, {CalendarDate? due, DateTime? defer}) =>
    Task(uid: TaskUid(name), name: name, dueDate: due, deferUntil: defer);

void main() {
  late OfflineRig rig;

  setUp(() async {
    rig = OfflineRig();
    await rig.init();
  });

  group('groupTasksByDay', () {
    test('sorts days, keeps order inside a day, undated last', () {
      final d = CalendarDate(2026, 10, 20);
      final groups = groupTasksByDay([
        _task('c', due: d.addDays(2)),
        _task('none'),
        _task('a', due: d),
        _task('b', due: d),
      ]);
      expect(groups.map((g) => g.day), [d, d.addDays(2), null]);
      expect(groups.first.tasks.map((t) => t.name), ['a', 'b']);
    });
  });

  testWidgets('upcoming groups tasks under day headers', (tester) async {
    final today = rig.today().date;
    await seed(tester, () async {
      await rig.repo.create(NewTask(name: 'tom', dueDate: today.addDays(1)));
      await rig.repo.create(NewTask(name: 'later', dueDate: today.addDays(3)));
    });
    await pumpWithRig(
      tester,
      rig,
      home: const TaskListScreen(view: TaskListView.upcoming),
    );
    expect(
      find.descendant(
        of: find.byKey(ValueKey('day-${today.addDays(1).toIso()}')),
        matching: find.text('Tomorrow'),
      ),
      findsOneWidget,
    );
    expect(find.text('tom'), findsOneWidget);
    expect(find.text('later'), findsOneWidget);
    expect(find.byKey(ValueKey('day-${today.addDays(3).toIso()}')), findsOne);
    await unmount(tester);
  });

  testWidgets('empty state per view', (tester) async {
    await pumpWithRig(
      tester,
      rig,
      home: const TaskListScreen(view: TaskListView.overdue),
    );
    expect(find.text('All caught up'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('overdue reschedule all moves tasks to today', (tester) async {
    final today = rig.today().date;
    await seed(
      tester,
      () => rig.repo.create(NewTask(name: 'old', dueDate: today.addDays(-3))),
    );
    await pumpWithRig(
      tester,
      rig,
      home: const TaskListScreen(view: TaskListView.overdue),
    );
    expect(find.text('old'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reschedule-all')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('old'), findsNothing);
    expect(find.text('All caught up'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('completed pages with load more, newest first', (tester) async {
    await seed(tester, () async {
      for (var i = 0; i < completedPageSize + 5; i++) {
        final t = await rig.repo.create(NewTask(name: 't$i'));
        await rig.repo.complete(t.uid);
        rig.advance(const Duration(minutes: 1));
      }
    });
    await pumpWithRig(
      tester,
      rig,
      home: const TaskListScreen(view: TaskListView.completed),
    );
    final list = find.byType(Scrollable).first;
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('load-more')),
      list,
      const Offset(0, -300),
    );
    expect(find.text('t4'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('load-more')));
    await tester.pump();
    await tester.dragUntilVisible(find.text('t0'), list, const Offset(0, -300));
    expect(find.text('t0'), findsOneWidget);
    expect(find.byKey(const ValueKey('load-more')), findsNothing);
    await unmount(tester);
  });

  testWidgets('pull to refresh syncs and keeps local edits', (tester) async {
    final today = rig.today().date;
    await seed(
      tester,
      () => rig.repo.create(NewTask(name: 'mine', dueDate: today.addDays(2))),
    );
    final engine = _RecordingEngine();
    await pumpWithRig(
      tester,
      rig,
      engine: engine,
      home: const TaskListScreen(view: TaskListView.upcoming),
    );
    await tester.fling(find.text('mine'), const Offset(0, 400), 1000);
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(engine.reasons, [SyncReason.manual]);
    expect(find.text('mine'), findsOneWidget);
    await unmount(tester);
    // The unsent local edit is still queued.
    final outbox = await seed(tester, () => rig.outbox());
    expect(outbox, isNotEmpty);
  });

  for (final loc in const [Locale('de'), Locale('zh')]) {
    testWidgets('${loc.languageCode} smoke at text scale 2.0', (tester) async {
      final today = rig.today().date;
      await seed(
        tester,
        () => rig.repo.create(NewTask(name: 'x', dueDate: today.addDays(4))),
      );
      await pumpWithRig(
        tester,
        rig,
        locale: loc,
        textScale: 2.0,
        home: const TaskListScreen(view: TaskListView.upcoming),
      );
      expect(find.text('x'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }
}

class _RecordingEngine extends Fake implements SyncEngine {
  final reasons = <SyncReason>[];

  @override
  SyncStatus get status => const SyncStatus();

  @override
  Stream<SyncStatus> get statuses => const Stream.empty();

  @override
  Future<void> requestSync(SyncReason reason) async => reasons.add(reason);
}
