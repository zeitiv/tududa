import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/time/calendar_date.dart';
import 'package:tududa/core/time/user_clock.dart';
import 'package:tududa/tasks/data/task_dao.dart';
import 'package:tududa/tasks/domain/task_views.dart';

void main() {
  late AppDatabase db;
  late TaskDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = TaskDao(db);
  });
  tearDown(() => db.close());

  Future<void> put(
    String id, {
    int status = 0,
    String? due,
    DateTime? defer,
    DateTime? completedAt,
    String? recurrence,
    String? instanceOf,
    String? parent,
    bool deleted = false,
  }) => dao.insertRow(
    TasksCompanion.insert(
      localId: id,
      uid: Value(id),
      name: Value(id),
      status: Value(status),
      dueDate: Value(due),
      deferUntil: Value(defer),
      completedAt: Value(completedAt),
      recurrenceType: Value(recurrence),
      recurringParentUid: Value(instanceOf),
      parentLocalId: Value(parent),
      pendingDelete: Value(deleted),
    ),
  );

  // Wednesday 2026-10-14, noon UTC.
  final now = DateTime.utc(2026, 10, 14, 12);
  final day = TaskDay.utc(CalendarDate(2026, 10, 14), now: now);

  Future<void> seed() async {
    await put('overdue', due: '2026-10-13');
    await put('overdue_done', due: '2026-10-13', status: 2);
    await put('overdue_archived', due: '2026-10-13', status: 3);
    await put('overdue_cancelled', due: '2026-10-13', status: 5);
    await put('overdue_inprogress', due: '2026-10-01', status: 1);
    await put('due_today', due: '2026-10-14');
    await put('due_today_done', due: '2026-10-14', status: 2);
    await put('plan_inprogress', status: 1);
    await put('plan_waiting', status: 4, due: '2026-10-20');
    await put('plan_planned', status: 6);
    await put('plan_deferred', status: 6, defer: DateTime.utc(2026, 10, 15));
    await put(
      'plan_defer_passed',
      status: 6,
      defer: DateTime.utc(2026, 10, 14, 8),
    );
    await put(
      'done_today',
      status: 2,
      completedAt: DateTime.utc(2026, 10, 14, 8),
    );
    await put(
      'done_yesterday',
      status: 2,
      completedAt: DateTime.utc(2026, 10, 13, 23, 59, 59),
    );
    await put('up_in', due: '2026-10-18');
    await put('up_edge', due: '2026-10-21');
    await put('up_out', due: '2026-10-22');
    await put('up_deferred', defer: DateTime.utc(2026, 10, 16));
    await put('someday');
    await put('tpl', recurrence: 'daily', due: '2026-10-14');
    await put('tpl_hidden', recurrence: 'daily', due: '2026-10-14');
    await put(
      'instance_today',
      recurrence: 'daily',
      instanceOf: 'tpl_hidden',
      due: '2026-10-14',
    );
    await put(
      'instance_old',
      recurrence: 'daily',
      instanceOf: 'tpl',
      due: '2026-10-10',
    );
    await put('child', due: '2026-10-14', parent: 'overdue');
    await put('trashed', due: '2026-10-14', deleted: true);
  }

  Future<Set<String>> sql(TaskView v) async => {
    for (final t in await dao.fetchView(v, day)) t.uid.value,
  };

  test('each view lists what the server lists', () async {
    await seed();
    expect(await sql(TaskView.overdue), {'overdue', 'overdue_inprogress'});
    expect(await sql(TaskView.dueToday), {
      'due_today',
      'tpl',
      'instance_today',
    });
    expect(await sql(TaskView.todayPlan), {
      'plan_inprogress',
      'plan_waiting',
      'plan_planned',
      'plan_defer_passed',
      'overdue_inprogress',
    });
    expect(await sql(TaskView.completedToday), {'done_today'});
    expect(await sql(TaskView.upcoming), {
      'up_in',
      'up_edge',
      'up_deferred',
      'plan_waiting',
      'plan_deferred',
      'tpl',
      'tpl_hidden',
    });
    expect(
      await sql(TaskView.someday),
      {
        'someday',
        'plan_inprogress',
        'plan_planned',
        'plan_deferred',
        'plan_defer_passed',
        'up_deferred',
      }.union({'tpl_hidden', 'tpl'}.intersection({})),
    );
    expect(await sql(TaskView.completed), {
      'overdue_done',
      'overdue_archived',
      'due_today_done',
      'done_today',
      'done_yesterday',
    });
    // The Today tab is the union of the three today lists.
    expect(await sql(TaskView.today), {
      ...await sql(TaskView.overdue),
      ...await sql(TaskView.dueToday),
      ...await sql(TaskView.todayPlan),
    });
  });

  test('a template is hidden while an instance for today exists', () async {
    await seed();
    final today = await sql(TaskView.today);
    expect(today, contains('tpl'));
    expect(today, isNot(contains('tpl_hidden')));
    expect(today, contains('instance_today'));
    // Stale instances are never overdue.
    expect(await sql(TaskView.overdue), isNot(contains('instance_old')));
  });

  test('subtasks and deleted rows appear in no view', () async {
    await seed();
    for (final v in TaskView.values) {
      final ids = await sql(v);
      expect(ids, isNot(contains('child')), reason: '$v');
      expect(ids, isNot(contains('trashed')), reason: '$v');
    }
  });

  test('the pure predicates agree with the SQL for every view', () async {
    await seed();
    final all = await dao.hydrate(await dao.allRows(), withSubtasks: false);
    for (final v in TaskView.values) {
      final pure = {for (final t in TaskViews.select(v, all, day)) t.uid.value};
      // The pure mirror cannot see pending-delete rows (they are not loaded).
      expect(pure.difference({'trashed'}), await sql(v), reason: '$v');
    }
  });

  group('the day follows the user zone', () {
    // 23:59 and 00:01 local time, as UTC instants.
    final cases = {
      'Pacific/Kiritimati': (
        DateTime.utc(2026, 10, 14, 9, 59),
        DateTime.utc(2026, 10, 14, 10, 1),
      ),
      'America/Los_Angeles': (
        DateTime.utc(2026, 10, 15, 6, 59),
        DateTime.utc(2026, 10, 15, 7, 1),
      ),
    };

    cases.forEach((zone, instants) {
      test(zone, () async {
        final (before, after) = instants;
        TaskDay at(DateTime t) =>
            TaskDay.fromClock(UserClock(now: () => t, zoneName: zone));

        final late = at(before);
        final early = at(after);
        expect(late.date, CalendarDate(2026, 10, 14));
        expect(early.date, CalendarDate(2026, 10, 15));
        expect(early.startUtc, after.subtract(const Duration(minutes: 1)));
        expect(late.endUtc, early.startUtc);

        await put('d14', due: '2026-10-14');
        await put('d15', due: '2026-10-15');
        await put(
          'done_last_minute',
          status: 2,
          completedAt: after.subtract(const Duration(minutes: 2)),
        );
        await put('done_new_day', status: 2, completedAt: after);

        Future<Set<String>> ids(TaskDay d, TaskView v) async => {
          for (final t in await dao.fetchView(v, d)) t.uid.value,
        };

        expect(await ids(late, TaskView.dueToday), {'d14'});
        expect(await ids(late, TaskView.overdue), isEmpty);
        expect(await ids(late, TaskView.completedToday), {'done_last_minute'});
        expect(await ids(late, TaskView.upcoming), {'d15'});

        expect(await ids(early, TaskView.dueToday), {'d15'});
        expect(await ids(early, TaskView.overdue), {'d14'});
        expect(await ids(early, TaskView.completedToday), {'done_new_day'});
        expect(await ids(early, TaskView.upcoming), isEmpty);

        // The pure mirror agrees at both instants.
        final all = await dao.hydrate(await dao.allRows(), withSubtasks: false);
        for (final d in [late, early]) {
          for (final v in TaskView.values) {
            expect(
              {for (final t in TaskViews.select(v, all, d)) t.uid.value},
              await ids(d, v),
              reason: '$zone $v ${d.date}',
            );
          }
        }
      });
    });

    test('the same instant is a different day in UTC and Kiritimati', () {
      final instant = DateTime.utc(2026, 10, 14, 11);
      expect(
        TaskDay.fromClock(UserClock(now: () => instant, zoneName: 'UTC')).date,
        CalendarDate(2026, 10, 14),
      );
      expect(
        TaskDay.fromClock(
          UserClock(now: () => instant, zoneName: 'Pacific/Kiritimati'),
        ).date,
        CalendarDate(2026, 10, 15),
      );
    });
  });

  test('watchView re-emits when a task changes', () async {
    final emitted = <List<String>>[];
    final sub = dao
        .watchView(TaskView.dueToday, today: day.date, day: day)
        .listen((l) => emitted.add([for (final t in l) t.uid.value]));
    addTearDown(sub.cancel);
    await pumpEventQueue();
    expect(emitted.last, isEmpty);
    await put('x', due: '2026-10-14');
    await pumpEventQueue();
    expect(emitted.last, ['x']);
    await dao.updateRow('x', const TasksCompanion(status: Value(2)));
    await pumpEventQueue();
    expect(emitted.last, isEmpty);
  });
}
