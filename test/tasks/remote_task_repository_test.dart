import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/api/api_error.dart';
import 'package:tududa/core/api/patch.dart' show Patch;
import 'package:tududa/core/ids.dart';
import 'package:tududa/core/time/calendar_date.dart';
import 'package:tududa/tasks/data/remote_task_repository.dart';
import 'package:tududa/tasks/data/task_patch.dart';
import 'package:tududa/tasks/data/task_query.dart';
import 'package:tududa/tasks/data/task_repository.dart';
import 'package:tududa/tasks/domain/new_task.dart';
import 'package:tududa/tasks/domain/task.dart';

import 'task_test_support.dart';

void main() {
  late TaskTestRig rig;
  late TaskRepository repo;

  setUp(() async {
    rig = TaskTestRig();
    await rig.login();
    repo = rig.container().read(remoteTaskRepositoryProvider);
  });

  test('the provider builds a RemoteTaskRepository', () {
    expect(repo, isA<RemoteTaskRepository>());
  });

  test('fetch maps tasks and paging to the domain', () async {
    rig.server
      ..seedTask(
        uid: 'a',
        name: 'Rewritten',
        priority: 2,
        status: 1,
        dueDate: '2025-03-04',
        dueTime: '08:30',
        projectUid: 'p1',
        tags: ['x'],
        extra: {'original_name': 'Original'},
      )
      ..seedTask(uid: 'b');
    final page = await repo.fetch(const TaskQuery(limit: 1));
    expect(page.items, hasLength(1));
    expect(page.total, 2);
    expect(page.hasMore, isTrue);
    final t = page.items.single;
    expect(t.uid, const TaskUid('a'));
    expect(t.name, 'Original');
    expect(t.priority, Priority.high);
    expect(t.status, TaskStatus.inProgress);
    expect(t.dueDate, const CalendarDate(2025, 3, 4));
    expect(t.dueTime, const LocalTime(8, 30));
    expect(t.projectUid, const ProjectUid('p1'));
    expect(t.tags.single.name, 'x');
  });

  test('create and get', () async {
    final created = await repo.create(
      const NewTask(name: 'New', projectUid: ProjectUid('p9')),
    );
    expect(created.name, 'New');
    expect(created.projectUid, const ProjectUid('p9'));
    final got = await repo.get(created.uid);
    expect(got.uid, created.uid);
  });

  test('complete then uncomplete restores the given status', () async {
    rig.server.seedTask(uid: 'a', status: 1);
    final done = await repo.complete(const TaskUid('a'));
    expect(done.status, TaskStatus.done);
    expect(done.completedAt, isNotNull);

    final back = await repo.uncomplete(
      const TaskUid('a'),
      restoreTo: TaskStatus.inProgress,
    );
    expect(back.status, TaskStatus.inProgress);
    expect(back.completedAt, isNull);
  });

  test(
    'uncomplete defaults to not started and never reopens into done',
    () async {
      rig.server.seedTask(uid: 'a', status: 2);
      expect(
        (await repo.uncomplete(const TaskUid('a'))).status,
        TaskStatus.notStarted,
      );
      rig.server.seedTask(uid: 'b', status: 2);
      expect(
        (await repo.uncomplete(
          const TaskUid('b'),
          restoreTo: TaskStatus.done,
        )).status,
        TaskStatus.notStarted,
      );
    },
  );

  test('postpone keeps the time only when asked', () async {
    rig.server
      ..seedTask(uid: 'a', dueDate: '2025-01-01', dueTime: '09:00')
      ..seedTask(uid: 'b', dueDate: '2025-01-01', dueTime: '09:00');
    const to = CalendarDate(2025, 1, 8);
    final kept = await repo.postpone(
      const TaskUid('a'),
      to,
      keepTime: const LocalTime(9, 0),
    );
    expect(kept.dueDate, to);
    expect(kept.dueTime, const LocalTime(9, 0));
    final dropped = await repo.postpone(const TaskUid('b'), to);
    expect(dropped.dueTime, isNull);
  });

  test('update, delete, skipOccurrence, subtasks', () async {
    rig.server
      ..seedTask(uid: 'a', name: 'A')
      ..seedTask(
        uid: 'r',
        dueDate: '2025-01-01',
        extra: {'recurrence_type': 'daily', 'recurrence_interval': 3},
      );
    final upd = await repo.update(
      const TaskUid('a'),
      const TaskPatch(name: Patch.set('B')),
    );
    expect(upd.name, 'B');

    final skipped = await repo.skipOccurrence(const TaskUid('r'));
    expect(skipped!.dueDate, const CalendarDate(2025, 1, 4));

    final parent = await repo.get(const TaskUid('a'));
    final sub = await repo.createSubtask(
      parentId: parent.serverId!,
      name: 'Sub',
    );
    expect(sub.parentTaskId, parent.serverId);
    expect((await repo.subtasks(parent.uid)).single.name, 'Sub');

    await repo.delete(const TaskUid('a'));
    await expectLater(
      repo.get(const TaskUid('a')),
      throwsA(isA<NotFoundError>()),
    );
  });

  test('errors surface as ApiError, never DioException', () async {
    await expectLater(
      repo.complete(const TaskUid('missing')),
      throwsA(isA<NotFoundError>()),
    );
    await expectLater(
      repo.create(const NewTask(name: '')),
      throwsA(isA<ValidationError>()),
    );
    rig.server.failNext('/tasks', 500);
    await expectLater(
      repo.fetch(const TaskQuery()),
      throwsA(isA<ServerError>()),
    );
  });

  test('ProviderContainer without the override fails loudly', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(() => c.read(remoteTaskRepositoryProvider), throwsA(anything));
  });
}
