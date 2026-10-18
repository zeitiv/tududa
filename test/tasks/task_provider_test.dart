import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/api/api_error.dart';
import 'package:tududa/core/api/patch.dart' show Patch;
import 'package:tududa/core/ids.dart';
import 'package:tududa/core/time/calendar_date.dart';
import 'package:tududa/tasks/data/task_patch.dart';
import 'package:tududa/tasks/domain/new_task.dart';
import 'package:tududa/tasks/domain/task.dart';
import 'package:tududa/tasks/providers/task_provider.dart';
import 'package:tududa/tasks/widgets/api_error_message.dart';

import 'task_test_support.dart';

void main() {
  late TaskTestRig rig;

  setUp(() async {
    rig = TaskTestRig();
    await rig.login();
  });

  String today() => DateTime.now().toIso8601String().substring(0, 10);

  Task find(List<Task>? list, String uid) =>
      list!.firstWhere((t) => t.uid.value == uid);

  group('taskListProvider', () {
    test('loads the view from the server', () async {
      rig.server
        ..seedTask(uid: 'due', dueDate: today())
        ..seedTask(uid: 'later', dueDate: '2999-01-01')
        ..seedTask(uid: 'free');
      final c = rig.container();

      final todayTasks = await c.read(
        taskListProvider(TaskFilter.today).future,
      );
      expect(todayTasks.map((t) => t.uid.value), ['due']);
      expect(rig.sent('GET', '/tasks').last.query['type'], 'today');

      final someday = await c.read(taskListProvider(TaskFilter.someday).future);
      expect(someday.map((t) => t.uid.value), ['free']);

      final upcoming = await c.read(
        taskListProvider(TaskFilter.upcoming).future,
      );
      expect(upcoming.map((t) => t.uid.value), ['later']);
    });

    test('completed and all views send the old query', () async {
      rig.server
        ..seedTask(uid: 'a', status: 2)
        ..seedTask(uid: 'b');
      final c = rig.container();
      final done = await c.read(taskListProvider(TaskFilter.completed).future);
      expect(done.map((t) => t.uid.value), ['a']);
      expect(rig.sent('GET', '/tasks').last.query, {
        'type': 'all',
        'status': 'completed',
      });
      final all = await c.read(taskListProvider(TaskFilter.all).future);
      expect(all, hasLength(2));
    });

    test('a failing load is an AsyncError carrying the ApiError', () async {
      rig.server.failNext('/tasks', 500);
      final c = rig.container();
      final sub = c.listen(taskListProvider(TaskFilter.all), (_, _) {});
      await expectLater(
        c.read(taskListProvider(TaskFilter.all).future),
        throwsA(isA<ServerError>()),
      );
      expect(sub.read().hasError, isTrue);
      expect(apiErrorMessage(sub.read().error!), 'Server error (500)');
    });

    test('refresh reloads, and keeps the list when the reload fails', () async {
      rig.server.seedTask(uid: 'a');
      final c = rig.container();
      final p = taskListProvider(TaskFilter.all);
      c.listen(p, (_, _) {});
      await c.read(p.future);

      rig.server.seedTask(uid: 'b');
      await c.read(p.notifier).refresh();
      expect(c.read(p).value!.map((t) => t.uid.value), ['a', 'b']);

      rig.server.failNext('/tasks', 500);
      await expectLater(
        c.read(p.notifier).refresh(),
        throwsA(isA<ServerError>()),
      );
      expect(c.read(p).value, hasLength(2));
    });

    test('sortTasks', () async {
      rig.server
        ..seedTask(uid: 'a', name: 'b', priority: 0, dueDate: '2025-02-01')
        ..seedTask(uid: 'b', name: 'a', priority: 2)
        ..seedTask(uid: 'c', name: 'c', priority: 1, dueDate: '2025-01-01');
      final tasks = await rig.container().read(
        taskListProvider(TaskFilter.all).future,
      );
      List<String> uids(TaskSort s, {bool asc = true}) => [
        for (final t in sortTasks(tasks, s, ascending: asc)) t.uid.value,
      ];
      expect(uids(TaskSort.name), ['b', 'a', 'c']);
      expect(uids(TaskSort.dueDate), ['c', 'a', 'b']);
      expect(uids(TaskSort.priority), ['b', 'c', 'a']);
      expect(uids(TaskSort.priority, asc: false), ['a', 'c', 'b']);
    });
  });

  group('mutations', () {
    test('complete is optimistic, then settles with the server task', () async {
      rig.server.seedTask(uid: 'a', status: 1);
      final c = rig.container();
      final p = taskListProvider(TaskFilter.all);
      c.listen(p, (_, _) {});
      final task = find(await c.read(p.future), 'a');

      final pending = c.read(taskActionsProvider).complete(task);
      // Before the request finished:
      expect(find(c.read(p).value, 'a').status, TaskStatus.done);
      expect(rig.sent('PATCH', '/task/a'), isEmpty);

      final result = await pending;
      expect(result.ok, isTrue);
      expect(rig.sent('PATCH', '/task/a').single.body, {'status': 2});
      expect(find(c.read(p).value, 'a').status, TaskStatus.done);
      expect(find(c.read(p).value, 'a').completedAt, isNotNull);
    });

    test('a failed complete is rolled back and returns the ApiError', () async {
      rig.server.seedTask(uid: 'a', status: 1);
      final c = rig.container();
      final p = taskListProvider(TaskFilter.all);
      c.listen(p, (_, _) {});
      final task = find(await c.read(p.future), 'a');

      rig.server.failNext('/task/a', 500);
      final pending = c.read(taskActionsProvider).complete(task);
      expect(find(c.read(p).value, 'a').status, TaskStatus.done);

      final result = await pending;
      expect(result.ok, isFalse);
      expect(result.error, isA<ServerError>());
      expect(find(c.read(p).value, 'a').status, TaskStatus.inProgress);
      expect(rig.server.tasks['a']!['status'], 1);
    });

    test('uncomplete restores the status the task had before', () async {
      rig.server.seedTask(uid: 'a', status: 1);
      final c = rig.container();
      final p = taskListProvider(TaskFilter.all);
      c.listen(p, (_, _) {});
      final actions = c.read(taskActionsProvider);

      await actions.complete(find(await c.read(p.future), 'a'));
      expect(rig.server.tasks['a']!['status'], 2);

      final reopened = await actions.uncomplete(find(c.read(p).value, 'a'));
      expect(reopened.ok, isTrue);
      expect(rig.server.tasks['a']!['status'], 1);
      expect(find(c.read(p).value, 'a').status, TaskStatus.inProgress);
    });

    test(
      'uncomplete without history defaults to not started (no note rule)',
      () async {
        rig.server.seedTask(uid: 'a', status: 2, note: 'has a note');
        final c = rig.container();
        final p = taskListProvider(TaskFilter.all);
        c.listen(p, (_, _) {});
        final task = find(await c.read(p.future), 'a');
        await c.read(taskActionsProvider).uncomplete(task);
        expect(rig.server.tasks['a']!['status'], 0);
      },
    );

    test('toggleComplete flips both ways', () async {
      rig.server.seedTask(uid: 'a');
      final c = rig.container();
      final p = taskListProvider(TaskFilter.all);
      c.listen(p, (_, _) {});
      final actions = c.read(taskActionsProvider);
      await actions.toggleComplete(find(await c.read(p.future), 'a'));
      expect(rig.server.tasks['a']!['status'], 2);
      await actions.toggleComplete(find(c.read(p).value, 'a'));
      expect(rig.server.tasks['a']!['status'], 0);
    });

    test(
      'a failed uncomplete keeps the remembered status for the retry',
      () async {
        rig.server.seedTask(uid: 'a', status: 1);
        final c = rig.container();
        final p = taskListProvider(TaskFilter.all);
        c.listen(p, (_, _) {});
        final actions = c.read(taskActionsProvider);
        await actions.complete(find(await c.read(p.future), 'a'));

        rig.server.failNext('/task/a', 500);
        final failed = await actions.uncomplete(find(c.read(p).value, 'a'));
        expect(failed.ok, isFalse);
        expect(find(c.read(p).value, 'a').status, TaskStatus.done);

        await actions.uncomplete(find(c.read(p).value, 'a'));
        expect(rig.server.tasks['a']!['status'], 1);
      },
    );

    test('updates every loaded view and the detail provider', () async {
      rig.server.seedTask(uid: 'a', dueDate: today());
      final c = rig.container();
      final todayP = taskListProvider(TaskFilter.today);
      final allP = taskListProvider(TaskFilter.all);
      final detailP = taskDetailProvider(const TaskUid('a'));
      for (final p in [todayP, allP, detailP]) {
        c.listen(p, (_, _) {});
      }
      final task = find(await c.read(todayP.future), 'a');
      await c.read(allP.future);
      await c.read(detailP.future);

      final pending = c.read(taskActionsProvider).complete(task);
      expect(find(c.read(todayP).value, 'a').isDone, isTrue);
      expect(find(c.read(allP).value, 'a').isDone, isTrue);
      expect(c.read(detailP).value!.isDone, isTrue);
      await pending;
    });

    test('the completed view drops a reopened task', () async {
      rig.server.seedTask(uid: 'a', status: 2);
      final c = rig.container();
      final p = taskListProvider(TaskFilter.completed);
      c.listen(p, (_, _) {});
      final task = find(await c.read(p.future), 'a');
      await c.read(taskActionsProvider).uncomplete(task);
      expect(c.read(p).value, isEmpty);
    });

    test('delete is optimistic and rolls back on failure', () async {
      rig.server
        ..seedTask(uid: 'a')
        ..seedTask(uid: 'b');
      final c = rig.container();
      final p = taskListProvider(TaskFilter.all);
      c.listen(p, (_, _) {});
      await c.read(p.future);
      final actions = c.read(taskActionsProvider);

      rig.server.failNext('/task/a', 500);
      final failing = actions.delete(const TaskUid('a'));
      expect(c.read(p).value!.map((t) => t.uid.value), ['b']);
      expect((await failing).ok, isFalse);
      expect(c.read(p).value!.map((t) => t.uid.value), ['a', 'b']);

      final ok = await actions.delete(const TaskUid('a'));
      expect(ok.ok, isTrue);
      expect(c.read(p).value!.map((t) => t.uid.value), ['b']);
      expect(rig.server.tasks.keys, ['b']);
    });

    test('postpone moves the date and keeps the time', () async {
      rig.server.seedTask(uid: 'a', dueDate: '2025-01-01', dueTime: '09:00');
      final c = rig.container();
      final p = taskListProvider(TaskFilter.all);
      c.listen(p, (_, _) {});
      final task = find(await c.read(p.future), 'a');
      final r = await c
          .read(taskActionsProvider)
          .postpone(task, const CalendarDate(2025, 1, 8));
      expect(r.value!.dueDate, const CalendarDate(2025, 1, 8));
      expect(r.value!.dueTime, const LocalTime(9, 0));
      expect(rig.sent('PATCH', '/task/a').single.body, {
        'due_date': '2025-01-08',
        'due_time': '09:00',
      });
    });

    test('setStatus (kanban) is optimistic with rollback', () async {
      rig.server.seedTask(uid: 'a');
      final c = rig.container();
      final p = taskListProvider(TaskFilter.all);
      c.listen(p, (_, _) {});
      final task = find(await c.read(p.future), 'a');
      final actions = c.read(taskActionsProvider);

      await actions.setStatus(task, TaskStatus.waiting);
      expect(rig.server.tasks['a']!['status'], 4);
      expect(find(c.read(p).value, 'a').status, TaskStatus.waiting);

      rig.server.failNext('/task/a', 500);
      final r = await actions.setStatus(
        find(c.read(p).value, 'a'),
        TaskStatus.planned,
      );
      expect(r.ok, isFalse);
      expect(find(c.read(p).value, 'a').status, TaskStatus.waiting);
    });

    test('update applies the server result; errors are returned', () async {
      rig.server.seedTask(uid: 'a', name: 'A');
      final c = rig.container();
      final p = taskListProvider(TaskFilter.all);
      c.listen(p, (_, _) {});
      await c.read(p.future);
      final actions = c.read(taskActionsProvider);

      final ok = await actions.update(
        const TaskUid('a'),
        const TaskPatch(name: Patch.set('Renamed')),
      );
      expect(ok.ok, isTrue);
      expect(find(c.read(p).value, 'a').name, 'Renamed');

      final bad = await actions.update(
        const TaskUid('a'),
        const TaskPatch(name: Patch.set('')),
      );
      expect(bad.error, isA<ValidationError>());
      expect(find(c.read(p).value, 'a').name, 'Renamed');
    });

    test(
      'create files the task under a ProjectUid and reloads lists',
      () async {
        final c = rig.container();
        final p = taskListProvider(TaskFilter.all);
        c.listen(p, (_, _) {});
        expect(await c.read(p.future), isEmpty);

        final r = await c
            .read(taskActionsProvider)
            .create(
              const NewTask(name: 'New', projectUid: ProjectUid('proj-1')),
            );
        expect(r.ok, isTrue);
        expect(rig.sent('POST', '/task').single.body, {
          'name': 'New',
          'project_uid': 'proj-1',
        });
        final reloaded = await c.read(p.future);
        expect(reloaded.single.projectUid, const ProjectUid('proj-1'));

        final bad = await c
            .read(taskActionsProvider)
            .create(const NewTask(name: ' '));
        expect(bad.error, isA<ValidationError>());
      },
    );

    test('createSubtask uses the numeric parent id', () async {
      rig.server.seedTask(uid: 'p');
      final c = rig.container();
      final parent = await c.read(
        taskDetailProvider(const TaskUid('p')).future,
      );
      final r = await c
          .read(taskActionsProvider)
          .createSubtask(parent, 'Child');
      expect(r.ok, isTrue);
      final again = await c.read(taskDetailProvider(const TaskUid('p')).future);
      expect(again.subtasks.single.name, 'Child');
    });

    test('skipOccurrence updates the lists', () async {
      rig.server.seedTask(
        uid: 'r',
        dueDate: '2025-01-01',
        extra: {'recurrence_type': 'weekly', 'recurrence_interval': 1},
      );
      final c = rig.container();
      final p = taskListProvider(TaskFilter.all);
      c.listen(p, (_, _) {});
      await c.read(p.future);
      final r = await c
          .read(taskActionsProvider)
          .skipOccurrence(const TaskUid('r'));
      expect(r.ok, isTrue);
      expect(
        find(c.read(p).value, 'r').dueDate,
        const CalendarDate(2025, 1, 8),
      );
    });
  });

  group('taskDetailProvider', () {
    test('loads one task', () async {
      rig.server.seedTask(uid: 'a', name: 'A', note: 'n');
      final t = await rig.container().read(
        taskDetailProvider(const TaskUid('a')).future,
      );
      expect(t.name, 'A');
      expect(t.note, 'n');
    });

    test('unknown uid is a NotFoundError', () async {
      final c = rig.container();
      final p = taskDetailProvider(const TaskUid('nope'));
      c.listen(p, (_, _) {});
      await expectLater(c.read(p.future), throwsA(isA<NotFoundError>()));
      expect(apiErrorMessage(c.read(p).error!), 'Task not found');
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
