import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/api/api_error.dart';
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/db/dirty_fields.dart';
import 'package:tududa/core/ids.dart';
import 'package:tududa/projects/data/project_api.dart';
import 'package:tududa/projects/data/project_tasks_source.dart';

import '../support/fake_tududi/routes/projects_routes.dart';
import 'offline_harness.dart';

void main() {
  late OfflineHarness h;
  late DbProjectTasksSource source;

  setUp(() async {
    h = await OfflineHarness.create();
    source = DbProjectTasksSource(h.db, now: () => h.t);
  });
  tearDown(() => h.dispose());

  Future<void> task(
    String id, {
    String? project,
    String name = 'task',
    int status = 0,
    int priority = 0,
    String? dueDate,
    bool hidden = false,
    String? uid,
  }) => h.db
      .into(h.db.tasks)
      .insert(
        TasksCompanion.insert(
          localId: id,
          uid: Value(uid),
          projectLocalId: Value(project),
          name: Value(name),
          status: Value(status),
          priority: Value(priority),
          dueDate: Value(dueDate),
          pendingDelete: Value(hidden),
        ),
      );

  test('reads only the project tasks from the table', () async {
    seedProject(h.remote.server, uid: 'p1', name: 'One');
    seedProject(h.remote.server, uid: 'p2', name: 'Two');
    await h.sync();
    final l1 = (await h.projects.get(const ProjectUid('p1'))).localId!;
    final l2 = (await h.projects.get(const ProjectUid('p2'))).localId!;
    await task(
      't1',
      project: l1,
      name: 'one',
      status: 1,
      priority: 2,
      dueDate: '2025-02-03',
      uid: 'tu1',
    );
    await task('t2', project: l2, name: 'two');
    await task('t3', project: l1, name: 'gone', hidden: true);
    await task('t4', name: 'loose');

    final tasks = await source.tasksFor(const ProjectUid('p1'));
    expect(tasks, hasLength(1));
    final t = tasks.single;
    expect(t.uid, const TaskUid('tu1'));
    expect((t.status, t.priority), (1, 2));
    expect(t.dueDate, DateTime.parse('2025-02-03'));
    // A project without a uid yet is addressed by its local id.
    expect(await source.tasksFor(ProjectUid(l1)), hasLength(1));
    expect(h.remote.server.requests.where((r) => r.path == '/tasks'), isEmpty);
  });

  test('watch emits when tasks change', () async {
    final p = await h.projects.create(const NewProject(name: 'P'));
    final emissions = <int>[];
    final sub = source
        .watchTasksFor(p.uid)
        .listen((l) => emissions.add(l.length));
    await pumpEventQueue();
    await task('t1', project: p.localId);
    await pumpEventQueue();
    expect(emissions, [0, 1]);
    await sub.cancel();
  });

  test('setStatus updates the row, marks it dirty and enqueues', () async {
    await task('t1', uid: 'tu1', status: 1);
    h.t = DateTime.utc(2025, 3, 1, 10);
    await source.setStatus(const TaskUid('tu1'), 2);

    final row = await (h.db.select(
      h.db.tasks,
    )..where((t) => t.localId.equals('t1'))).getSingle();
    expect(row.status, 2);
    expect(row.statusBeforeDone, 1);
    expect(row.completedAt, h.t);
    expect(
      DirtyFields.decode(row.dirtyFields).editedAt('status'),
      h.t.millisecondsSinceEpoch,
    );
    final e = (await h.db.outboxDao.all()).single;
    expect((e.entity, e.localId, e.op), ('task', 't1', OutboxOp.update));

    await source.setStatus(const TaskUid('t1'), 0); // by local id, un-done
    final back = await (h.db.select(
      h.db.tasks,
    )..where((t) => t.localId.equals('t1'))).getSingle();
    expect(back.status, 0);
    expect(back.completedAt, isNull);
    expect(await h.db.outboxDao.all(), hasLength(1)); // update + update merged
  });

  test('unknown or hidden task is NotFoundError', () async {
    await task('t1', hidden: true);
    await expectLater(
      source.setStatus(const TaskUid('missing'), 2),
      throwsA(isA<NotFoundError>()),
    );
    await expectLater(
      source.setStatus(const TaskUid('t1'), 2),
      throwsA(isA<NotFoundError>()),
    );
  });

  test('ProjectTaskRef parses string status and priority', () {
    final t = ProjectTaskRef.fromJson({
      'uid': 'x',
      'name': 'n',
      'status': 'in_progress',
      'priority': 'high',
    });
    expect(t.status, 1);
    expect(t.priority, 2);
  });
}
