import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/api/api_error.dart';
import 'package:tududa/core/api/patch.dart' show Patch;
import 'package:tududa/core/ids.dart';
import 'package:tududa/core/time/calendar_date.dart';
import 'package:tududa/tasks/data/task_create.dart';
import 'package:tududa/tasks/data/task_patch.dart';
import 'package:tududa/tasks/data/task_query.dart';
import 'package:tududa/tasks/data/tasks_api.dart';
import 'package:tududa/tasks/domain/new_task.dart';
import 'package:tududa/tasks/domain/task.dart';

import 'task_test_support.dart';

void main() {
  late TaskTestRig rig;
  late TasksApi api;

  setUp(() async {
    rig = TaskTestRig();
    await rig.login();
    api = TasksApi(rig.stack.dio);
  });

  group('list', () {
    test('sends the query parameters', () async {
      await api.list(
        const TaskQuery(
          type: 'all',
          status: 'completed',
          priority: 'high',
          tag: 'work',
          projectUid: ProjectUid('p1'),
          areaUid: AreaUid('a1'),
          search: 'milk',
          orderBy: 'due_date:asc',
          includeSubtasks: true,
          limit: 10,
          offset: 20,
        ),
      );
      expect(rig.server.requests.last.query, {
        'type': 'all',
        'status': 'completed',
        'priority': 'high',
        'tag': 'work',
        'project_uid': 'p1',
        'area_uid': 'a1',
        'search': 'milk',
        'order_by': 'due_date:asc',
        'include_subtasks': 'true',
        'limit': '10',
        'offset': '20',
      });
    });

    test('filters and pages like the server', () async {
      for (var i = 0; i < 5; i++) {
        rig.server.seedTask(
          uid: 't$i',
          name: 'Task $i',
          projectUid: i.isEven ? 'p1' : 'p2',
        );
      }
      final res = await api.list(
        const TaskQuery(projectUid: ProjectUid('p1'), limit: 2, offset: 0),
      );
      expect(res.tasks.map((t) => t.uid), ['t0', 't2']);
      expect(res.page.total, 3);
      expect(res.page.hasMore, isTrue);

      final next = await api.list(
        const TaskQuery(projectUid: ProjectUid('p1'), limit: 2, offset: 2),
      );
      expect(next.tasks.map((t) => t.uid), ['t4']);
      expect(next.page.hasMore, isFalse);
    });

    test('a bare list response parses', () async {
      rig.server.tasksListBare = true;
      rig.server.seedTask(uid: 'a');
      final res = await api.list(const TaskQuery());
      expect(res.tasks.single.uid, 'a');
      expect(res.page.total, 1);
    });

    test('today with include_lists returns the extra lists', () async {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final yesterday = DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String()
          .substring(0, 10);
      rig.server
        ..seedTask(uid: 'late', dueDate: yesterday)
        ..seedTask(uid: 'now', dueDate: today)
        ..seedTask(uid: 'busy', status: 1)
        ..seedTask(uid: 'later', dueDate: '2999-01-01');
      final res = await api.list(
        const TaskQuery(type: 'today', includeLists: true),
      );
      expect(rig.server.requests.last.query['include_lists'], 'true');
      expect(res.tasks.map((t) => t.uid), ['late', 'now']);
      expect(res.lists!.overdue.map((t) => t.uid), ['late']);
      expect(res.lists!.dueToday.map((t) => t.uid), ['now']);
      expect(res.lists!.inProgress.map((t) => t.uid), ['busy']);
      expect(res.lists!.completedToday, isEmpty);
    });

    test('type filters', () async {
      rig.server
        ..seedTask(uid: 'someday')
        ..seedTask(uid: 'dated', dueDate: '2999-01-01')
        ..seedTask(uid: 'done', status: 2);
      Future<List<String>> uids(TaskQuery q) async => [
        for (final t in (await api.list(q)).tasks) t.uid!,
      ];
      expect(await uids(const TaskQuery(type: 'someday')), ['someday']);
      expect(await uids(const TaskQuery(type: 'upcoming')), ['dated']);
      expect(await uids(const TaskQuery(type: 'all')), [
        'someday',
        'dated',
        'done',
      ]);
      expect(await uids(const TaskQuery(type: 'all', status: 'completed')), [
        'done',
      ]);
    });
  });

  group('create / get / update / delete', () {
    test('create returns the new task and sends the body', () async {
      final dto = await api.create(
        const TaskCreate(
          NewTask(
            name: 'Buy milk',
            priority: Priority.high,
            dueDate: CalendarDate(2025, 3, 4),
            dueTime: LocalTime(9, 15),
            projectUid: ProjectUid('p1'),
            tags: ['home'],
          ),
        ),
      );
      expect(dto.uid, isNotNull);
      expect(dto.displayName, 'Buy milk');
      expect(dto.priority, 2);
      expect(dto.dueDate, const CalendarDate(2025, 3, 4));
      expect(dto.dueTime, const LocalTime(9, 15));
      expect(dto.projectUid, 'p1');
      expect(dto.tags.single.name, 'home');
      final body = rig.server.requests.last.body as Map;
      expect(body['project_uid'], 'p1');
      expect(body['due_time'], '09:15');
    });

    test('create with an empty name is a ValidationError', () async {
      await expectLater(
        api.create(const TaskCreate(NewTask(name: '   '))),
        throwsA(isA<ValidationError>()),
      );
    });

    test('get and 404', () async {
      rig.server.seedTask(uid: 'a', name: 'A');
      expect((await api.get(const TaskUid('a'))).name, 'A');
      await expectLater(
        api.get(const TaskUid('nope')),
        throwsA(isA<NotFoundError>()),
      );
    });

    test('update: omitted keys are kept, null clears', () async {
      rig.server.seedTask(
        uid: 'a',
        name: 'A',
        note: 'keep me',
        dueDate: '2025-01-02',
        dueTime: '10:00',
        priority: 1,
      );
      var dto = await api.update(
        const TaskUid('a'),
        const TaskPatch(priority: Patch.set(Priority.high)),
      );
      expect(dto.priority, 2);
      expect(dto.note, 'keep me');
      expect(dto.dueDate, const CalendarDate(2025, 1, 2));
      expect(dto.dueTime, const LocalTime(10, 0));
      expect(rig.server.requests.last.body, {'priority': 2});

      dto = await api.update(
        const TaskUid('a'),
        const TaskPatch(note: Patch.clear(), dueDate: Patch.clear()),
      );
      expect(dto.note, isNull);
      expect(dto.dueDate, isNull);
      expect(dto.priority, 2);
    });

    test('Tududi drops the due time when only the date is sent', () async {
      rig.server.seedTask(uid: 'a', dueDate: '2025-01-02', dueTime: '10:00');
      var dto = await api.update(
        const TaskUid('a'),
        const TaskPatch(dueDate: Patch.set(CalendarDate(2025, 1, 5))),
      );
      expect(dto.dueDate, const CalendarDate(2025, 1, 5));
      expect(dto.dueTime, isNull);

      rig.server.seedTask(uid: 'b', dueDate: '2025-01-02', dueTime: '10:00');
      dto = await api.update(
        const TaskUid('b'),
        TaskPatch.moveTo(
          const CalendarDate(2025, 1, 5),
          time: const LocalTime(10, 0),
        ),
      );
      expect(dto.dueTime, const LocalTime(10, 0));
    });

    test('tags are replaced by name', () async {
      rig.server.seedTask(uid: 'a', tags: ['x', 'y']);
      final dto = await api.update(
        const TaskUid('a'),
        const TaskPatch(tags: Patch.set(['y', 'z'])),
      );
      expect(dto.tags.map((t) => t.name), ['y', 'z']);
      final cleared = await api.update(
        const TaskUid('a'),
        const TaskPatch(tags: Patch.set([])),
      );
      expect(cleared.tags, isEmpty);
    });

    test('update errors: unknown uid and empty name', () async {
      rig.server.seedTask(uid: 'a');
      await expectLater(
        api.update(
          const TaskUid('nope'),
          const TaskPatch(note: Patch.set('x')),
        ),
        throwsA(isA<NotFoundError>()),
      );
      await expectLater(
        api.update(const TaskUid('a'), const TaskPatch(name: Patch.set(' '))),
        throwsA(isA<ValidationError>()),
      );
      await expectLater(
        api.update(
          const TaskUid('a'),
          const TaskPatch(estimatedMinutes: Patch.set(1)),
        ),
        throwsA(isA<ValidationError>()),
      );
    });

    test('completing sets completed_at, reopening clears it', () async {
      rig.server.seedTask(uid: 'a');
      var dto = await api.update(
        const TaskUid('a'),
        TaskPatch.withStatus(TaskStatus.done),
      );
      expect(dto.status, 2);
      expect(dto.completedAt, isNotNull);
      dto = await api.update(
        const TaskUid('a'),
        TaskPatch.withStatus(TaskStatus.inProgress),
      );
      expect(dto.completedAt, isNull);
    });

    test('delete and 404', () async {
      rig.server.seedTask(uid: 'a');
      await api.delete(const TaskUid('a'));
      expect(rig.server.tasks, isEmpty);
      await expectLater(
        api.delete(const TaskUid('a')),
        throwsA(isA<NotFoundError>()),
      );
    });
  });

  group('subtasks and recurrence', () {
    test(
      'createSubtask uses parent_task_id and appears under the parent',
      () async {
        final parent = rig.server.seedTask(uid: 'p', name: 'Parent');
        final sub = await api.createSubtask(parent['id'] as int, 'Child');
        expect(sub.parentTaskId, parent['id']);
        expect(
          (rig.server.requests.where((r) => r.method == 'POST').last.body
              as Map),
          {'name': 'Child', 'parent_task_id': parent['id']},
        );

        final fetched = await api.get(const TaskUid('p'));
        expect(fetched.subtasks.single.displayName, 'Child');
        expect((await api.subtasks(const TaskUid('p'))).single.name, 'Child');
        // Subtasks never show at top level.
        expect((await api.list(const TaskQuery())).tasks.map((t) => t.uid), [
          'p',
        ]);
      },
    );

    test('createSubtask under an unknown parent is a 404', () async {
      await expectLater(
        api.createSubtask(9999, 'x'),
        throwsA(isA<NotFoundError>()),
      );
    });

    test('skipOccurrence moves a recurring task and rejects others', () async {
      rig.server
        ..seedTask(
          uid: 'r',
          dueDate: '2025-01-31',
          extra: {'recurrence_type': 'monthly', 'recurrence_interval': 1},
        )
        ..seedTask(uid: 'plain');
      final dto = await api.skipOccurrence(const TaskUid('r'));
      expect(dto!.dueDate, const CalendarDate(2025, 2, 28));
      await expectLater(
        api.skipOccurrence(const TaskUid('plain')),
        throwsA(isA<ValidationError>()),
      );
      await expectLater(
        api.skipOccurrence(const TaskUid('nope')),
        throwsA(isA<NotFoundError>()),
      );
    });

    test('metrics', () async {
      rig.server
        ..seedTask(uid: 'a')
        ..seedTask(uid: 'b', status: 2);
      final m = await api.metrics();
      expect(m['total_open_tasks'], 1);
    });
  });

  group('transport', () {
    test('a mutation fetches a CSRF token and sends it', () async {
      await api.create(const TaskCreate(NewTask(name: 'x')));
      expect(rig.sent('GET', '/csrf-token'), hasLength(1));
      expect(
        rig.sent('POST', '/task').single.headers['x-csrf-token'],
        isNotEmpty,
      );
    });

    test('401 re-logs in and retries once', () async {
      rig.server.seedTask(uid: 'a', name: 'A');
      rig.server.expireAllSessions();
      final dto = await api.get(const TaskUid('a'));
      expect(dto.name, 'A');
      expect(rig.stack.callbacks.calls, 1);
      expect(rig.sent('GET', '/task/a'), hasLength(2));
    });

    test('a failed re-login surfaces UnauthorizedError', () async {
      rig.stack.callbacks.onReauth = () async => false;
      rig.server.expireAllSessions();
      await expectLater(
        api.list(const TaskQuery()),
        throwsA(isA<UnauthorizedError>()),
      );
    });

    test('403 with a stale CSRF token refetches it and retries', () async {
      await api.create(const TaskCreate(NewTask(name: 'one')));
      rig.server.failNext('/task', 403, body: {'error': 'Invalid CSRF token'});
      final dto = await api.create(const TaskCreate(NewTask(name: 'two')));
      expect(dto.name, 'two');
      expect(rig.sent('GET', '/csrf-token').length, greaterThanOrEqualTo(2));
    });

    test('server and network failures are typed', () async {
      rig.server.failNext('/task/a', 500);
      await expectLater(
        api.update(const TaskUid('a'), const TaskPatch(note: Patch.set('x'))),
        throwsA(isA<ServerError>()),
      );
      rig.server.failNextConnection('/tasks', times: 5);
      // The fake reports a dropped connection as a connect timeout.
      await expectLater(
        api.list(const TaskQuery()),
        throwsA(isA<TimeoutError>()),
      );
    });

    test('an unusable body is a DecodingError', () async {
      rig.server.failNext('/tasks', 200, body: 'not a list');
      await expectLater(
        api.list(const TaskQuery()),
        throwsA(isA<DecodingError>()),
      );
    });
  });
}
