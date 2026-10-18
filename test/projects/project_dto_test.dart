import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/api/patch.dart' as pt;
import 'package:tududa/core/ids.dart';
import 'package:tududa/projects/data/project_api.dart';
import 'package:tududa/projects/data/project_dto.dart';
import 'package:tududa/projects/models/project_model.dart';

void main() {
  Project parse(Map<String, dynamic> json) =>
      Project.fromDto(ProjectDto.fromJson(json));

  test('minimal project', () {
    final p = parse({'id': 1, 'uid': 'abc-x', 'name': 'P'});
    expect(p.uid, const ProjectUid('abc-x'));
    expect(p.status, 'not_started');
    expect(p.priority, isNull);
    expect(p.progress, 0);
    expect(p.pinToSidebar, isFalse);
    expect(p.taskSortOrder, 'created_at:desc');
  });

  test('full project with Area and task_status', () {
    final p = parse({
      'id': 2,
      'uid': 'u2',
      'name': 'Big',
      'description': 'd',
      'status': 'in_progress',
      'priority': 2,
      'due_date_at': '2025-03-01T00:00:00.000Z',
      'area_uid': 'a1',
      'Area': {'name': 'Work', 'uid': 'a1'},
      'pin_to_sidebar': true,
      'task_status': {'total': 4, 'done': 1},
      'created_at': '2025-01-01T00:00:00.000Z',
    });
    expect(p.areaUid, const AreaUid('a1'));
    expect(p.areaName, 'Work');
    expect(p.priorityName, 'high');
    expect(p.progress, 0.25);
    expect(p.dueDateAt, DateTime.utc(2025, 3, 1));
    expect(p.pinToSidebar, isTrue);
    expect(p.createdAt, isNotNull);
  });

  test('progress from camelCase counts, area only via Area', () {
    final p = parse({
      'uid': 'u3',
      'name': 'C',
      'taskCount': 10,
      'completedTaskCount': 5,
      'Area': {'name': 'Home', 'uid': 'a9'},
      'priority': 'medium',
    });
    expect(p.progress, 0.5);
    expect(p.areaUid, const AreaUid('a9'));
    expect(p.priority, 1);
  });

  test('progress from snake_case counts and zero total', () {
    expect(
      parse({'uid': 'x', 'task_count': 2, 'completed_task_count': 2}).progress,
      1,
    );
    expect(
      parse({
        'uid': 'x',
        'task_status': {'total': 0, 'done': 0},
      }).progress,
      0,
    );
  });

  test('numeric status maps to a name', () {
    expect(parse({'uid': 'x', 'status': 1}).status, 'in_progress');
  });

  test('ProjectPatch: unset omitted, clear is null, set is value', () {
    expect(const ProjectPatch().toJson(), isEmpty);
    final json = ProjectPatch(
      name: const pt.Patch.set('N'),
      description: const pt.Patch.clear(),
      areaUid: const pt.Patch.set(AreaUid('a1')),
      priority: const pt.Patch.clear(),
      dueDateAt: pt.Patch.set(DateTime.utc(2025, 1, 2)),
    ).toJson();
    expect(json, {
      'name': 'N',
      'description': null,
      'area_uid': 'a1',
      'priority': null,
      'due_date_at': '2025-01-02T00:00:00.000Z',
    });
    expect(json.containsKey('status'), isFalse);
  });

  test('NewProject body omits nulls', () {
    expect(const NewProject(name: 'N').toJson(), {
      'name': 'N',
      'status': 'not_started',
      'pin_to_sidebar': false,
    });
  });
}
