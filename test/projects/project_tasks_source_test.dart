import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/api/api_error.dart';
import 'package:tududa/core/ids.dart';
import 'package:tududa/projects/data/project_tasks_source.dart';

import 'harness.dart';

void main() {
  late ProjectsHarness h;
  late DioProjectTasksSource source;

  setUp(() async {
    h = await ProjectsHarness.create();
    source = DioProjectTasksSource(h.dio);
  });

  test('fetches only the project tasks through project_uid', () async {
    h.server.seedTask(
      uid: 't1',
      name: 'one',
      status: 1,
      priority: 2,
      dueDate: '2025-02-03',
      projectUid: 'p1',
    );
    h.server.seedTask(name: 'two', projectUid: 'p2');

    final tasks = await source.tasksFor(const ProjectUid('p1'));
    expect(tasks, hasLength(1));
    final t = tasks.single;
    expect(t.uid, const TaskUid('t1'));
    expect(t.status, 1);
    expect(t.priority, 2);
    expect(t.dueDate, DateTime.parse('2025-02-03'));
    final req = h.server.requests.lastWhere((r) => r.path == '/tasks');
    expect(req.query['project_uid'], 'p1');
    expect(req.query.containsKey('project_id'), isFalse);
  });

  test('setStatus patches the task; unknown task is NotFoundError', () async {
    final t = h.server.seedTask(uid: 't1', projectUid: 'p1');
    await source.setStatus(const TaskUid('t1'), 2);
    expect(t['status'], 2);
    await expectLater(
      source.setStatus(const TaskUid('missing'), 2),
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
