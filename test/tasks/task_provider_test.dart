import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/auth/session/session_providers.dart';
import 'package:tududa/core/api/api_error.dart';
import 'package:tududa/core/api/patch.dart' show Patch;
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/db/dirty_fields.dart';
import 'package:tududa/core/ids.dart';
import 'package:tududa/core/sync/sync_engine.dart';
import 'package:tududa/core/time/calendar_date.dart';
import 'package:tududa/tasks/data/offline_task_repository.dart';
import 'package:tududa/tasks/data/task_patch.dart';
import 'package:tududa/tasks/domain/new_task.dart';
import 'package:tududa/tasks/domain/task.dart';
import 'package:tududa/tasks/providers/task_provider.dart';
import 'package:tududa/tasks/widgets/api_error_message.dart';

import 'offline_rig.dart';

void main() {
  late OfflineRig rig;
  late ProviderContainer c;

  setUp(() async {
    rig = OfflineRig();
    await rig.init();
    c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(rig.db),
        syncEngineProvider.overrideWithValue(rig.engine),
        userClockProvider.overrideWithValue(rig.clock),
      ],
    );
    addTearDown(c.dispose);
  });

  List<String> names(TaskFilter f) => [
    for (final t in c.read(taskListProvider(f)).value ?? const <Task>[]) t.name,
  ];

  group('taskListProvider', () {
    test('lists follow the database without reloading', () async {
      c.listen(taskListProvider(TaskFilter.all), (_, _) {});
      c.listen(taskListProvider(TaskFilter.completed), (_, _) {});
      expect(await c.read(taskListProvider(TaskFilter.all).future), isEmpty);

      final actions = c.read(taskActionsProvider);
      final a = (await actions.create(const NewTask(name: 'A'))).value!;
      await actions.create(const NewTask(name: 'B'));
      await pumpEventQueue();
      expect(names(TaskFilter.all), unorderedEquals(['A', 'B']));
      expect(
        c.read(taskListProvider(TaskFilter.all)).value!.first.hasPendingSync,
        isTrue,
      );

      await actions.complete(a);
      await pumpEventQueue();
      expect(names(TaskFilter.all), ['B']);
      expect(names(TaskFilter.completed), ['A']);
    });

    test('today lists overdue, due today and the plan', () async {
      c.listen(taskListProvider(TaskFilter.today), (_, _) {});
      final today = rig.today().date;
      final repo = rig.repo;
      await repo.create(NewTask(name: 'late', dueDate: today.addDays(-1)));
      await repo.create(NewTask(name: 'now', dueDate: today));
      await repo.create(
        const NewTask(name: 'plan', status: TaskStatus.planned),
      );
      await repo.create(NewTask(name: 'later', dueDate: today.addDays(3)));
      await repo.create(const NewTask(name: 'free'));
      await pumpEventQueue();
      expect(names(TaskFilter.today), unorderedEquals(['late', 'now', 'plan']));
    });

    test('refresh syncs and keeps unsent local edits', () async {
      rig.net.server.seedTask(uid: 'a', name: 'Server', note: 'old');
      c.listen(taskListProvider(TaskFilter.all), (_, _) {});
      final notifier = c.read(taskListProvider(TaskFilter.all).notifier);
      await notifier.refresh();
      expect(names(TaskFilter.all), ['Server']);

      final actions = c.read(taskActionsProvider);
      await actions.update(
        const TaskUid('a'),
        const TaskPatch(name: Patch.set('Local')),
      );
      // The server changes another field in the meantime.
      rig.net.server.tasks['a']!
        ..['note'] = 'new note'
        ..['updated_at'] = rig.t
            .add(const Duration(minutes: 1))
            .toIso8601String();

      await notifier.refresh(); // the edit is still inside its undo window
      await pumpEventQueue();
      final task = c.read(taskListProvider(TaskFilter.all)).value!.single;
      expect(task.name, 'Local');
      expect(task.note, 'new note');
      expect(task.hasPendingSync, isTrue);
      final row = await rig.row('a');
      expect(DirtyFields.decode(row.dirtyFields).fields, {'name'});
    });
  });

  group('taskDetailProvider', () {
    test('follows a task from its local id to its server uid', () async {
      final t =
          (await c
                  .read(taskActionsProvider)
                  .create(const NewTask(name: 'Offline')))
              .value!;
      final p = taskDetailProvider(t.uid);
      c.listen(p, (_, _) {});
      expect((await c.read(p.future)).name, 'Offline');
      expect(c.read(p).value!.hasPendingSync, isTrue);

      await rig.flush();
      await pumpEventQueue();
      final synced = c.read(p).value!;
      expect(synced.hasPendingSync, isFalse);
      expect(synced.uid.value, isNot(t.uid.value));
    });

    test('unknown uid is a NotFoundError', () async {
      final p = taskDetailProvider(const TaskUid('nope'));
      final sub = c.listen(p, (_, _) {});
      addTearDown(sub.close);
      await expectLater(c.read(p.future), throwsA(isA<NotFoundError>()));
      expect(apiErrorMessage(c.read(p).error!), 'Task not found');
    });
  });

  group('taskActions', () {
    test('complete is undoable; uncomplete restores the old status', () async {
      final actions = c.read(taskActionsProvider);
      final t = (await actions.create(
        const NewTask(name: 'a', status: TaskStatus.inProgress),
      )).value!;
      await rig.flush();

      final done = await actions.complete(t);
      expect(done.value!.status, TaskStatus.done);
      expect(done.undo, isNotNull);
      expect(
        await c.read(statusBeforeDoneProvider(t.uid).future),
        TaskStatus.inProgress,
      );

      expect(await actions.undo(done.undo!), isTrue);
      expect(
        (await c.read(offlineTaskRepositoryProvider).get(t.uid)).status,
        TaskStatus.inProgress,
      );

      final again = (await actions.complete(t)).value!;
      final back = await actions.uncomplete(again);
      expect(back.value!.status, TaskStatus.inProgress);
    });

    test('toggleComplete flips both ways', () async {
      final actions = c.read(taskActionsProvider);
      final t = (await actions.create(const NewTask(name: 'a'))).value!;
      final done = (await actions.toggleComplete(t)).value!;
      expect(done.isCompleted, isTrue);
      expect((await actions.toggleComplete(done)).value!.isCompleted, isFalse);
    });

    test('validation errors come back as results', () async {
      final actions = c.read(taskActionsProvider);
      final r = await actions.create(const NewTask(name: '  '));
      expect(r.ok, isFalse);
      expect(r.error, isA<ValidationError>());
      final missing = await actions.update(
        const TaskUid('nope'),
        const TaskPatch(name: Patch.set('x')),
      );
      expect(missing.error, isA<NotFoundError>());
    });

    test('postpone keeps the time; delete hides the task', () async {
      final actions = c.read(taskActionsProvider);
      final t = (await actions.create(
        NewTask(
          name: 'a',
          dueDate: CalendarDate(2026, 5, 1),
          dueTime: const LocalTime(8, 0),
        ),
      )).value!;
      final moved = (await actions.postpone(
        t,
        CalendarDate(2026, 5, 2),
      )).value!;
      expect(moved.dueDate, CalendarDate(2026, 5, 2));
      expect(moved.dueTime, const LocalTime(8, 0));
      expect((await actions.delete(t.uid)).ok, isTrue);
      expect(await c.read(taskDaoProvider).taskByAnyId(t.uid.value), isNull);
    });

    test('createSubtask works under a parent that is not synced', () async {
      final actions = c.read(taskActionsProvider);
      final parent = (await actions.create(const NewTask(name: 'P'))).value!;
      final sub = await actions.createSubtask(parent, 'S');
      expect(sub.ok, isTrue);
      final shown = await c.read(offlineTaskRepositoryProvider).get(parent.uid);
      expect(shown.subtasks.map((s) => s.name), ['S']);
    });
  });

  group('sortTasks', () {
    test('orders by name, due date and priority', () async {
      final repo = rig.repo;
      await repo.create(
        NewTask(
          name: 'b',
          priority: Priority.low,
          dueDate: CalendarDate(2025, 2, 1),
        ),
      );
      await repo.create(const NewTask(name: 'a', priority: Priority.high));
      await repo.create(
        NewTask(
          name: 'c',
          priority: Priority.medium,
          dueDate: CalendarDate(2025, 1, 1),
        ),
      );
      c.listen(taskListProvider(TaskFilter.all), (_, _) {});
      final tasks = await c.read(taskListProvider(TaskFilter.all).future);
      List<String> order(TaskSort s, {bool asc = true}) => [
        for (final t in sortTasks(tasks, s, ascending: asc)) t.name,
      ];
      expect(order(TaskSort.name), ['a', 'b', 'c']);
      expect(order(TaskSort.dueDate), ['c', 'b', 'a']);
      expect(order(TaskSort.priority), ['a', 'c', 'b']);
      expect(order(TaskSort.priority, asc: false), ['b', 'c', 'a']);
    });
  });

  group('apiErrorMessage', () {
    test('maps every error to a short string', () {
      const errors = <ApiError>[
        NetworkError(),
        TimeoutError(),
        CancelledError(),
        UnauthorizedError(),
        InvalidCredentialsError(),
        EmailNotVerifiedError(),
        PasswordLoginDisabledError(),
        CsrfError(),
        ForbiddenError(),
        NotFoundError(),
        ValidationError('Task name is required'),
        RateLimitedError(),
        ServerError(503),
        DecodingError('x'),
      ];
      for (final e in errors) {
        expect(apiErrorMessage(e), isNotEmpty);
        expect(apiErrorMessage(e), isNot(contains('Instance of')));
      }
      expect(
        apiErrorMessage(const ValidationError('Task name is required')),
        'Task name is required',
      );
      expect(apiErrorMessage(StateError('x')), 'Something went wrong');
    });
  });
}
