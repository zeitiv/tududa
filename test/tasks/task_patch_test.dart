import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/api/patch.dart' show Patch;
import 'package:tududa/core/ids.dart';
import 'package:tududa/core/time/calendar_date.dart';
import 'package:tududa/tasks/data/task_create.dart';
import 'package:tududa/tasks/data/task_patch.dart';
import 'package:tududa/tasks/data/task_query.dart';
import 'package:tududa/tasks/domain/new_task.dart';
import 'package:tududa/tasks/domain/task.dart';

void main() {
  group('TaskPatch', () {
    test('an empty patch sends nothing', () {
      const p = TaskPatch();
      expect(p.toJson(), isEmpty);
      expect(p.isEmpty, isTrue);
    });

    test('unset is omitted, clear is null, set is the value', () {
      final json = const TaskPatch(
        name: Patch.set('New'),
        note: Patch.clear(),
        dueDate: Patch.clear(),
        priority: Patch.set(Priority.high),
        status: Patch.set(TaskStatus.done),
        estimatedMinutes: Patch.set(30),
      ).toJson();
      expect(json, {
        'name': 'New',
        'note': null,
        'due_date': null,
        'priority': 2,
        'status': 2,
        'estimated_minutes': 30,
      });
      expect(json.containsKey('due_time'), isFalse);
      expect(json.containsKey('project_uid'), isFalse);
    });

    test('typed values are encoded', () {
      final json = TaskPatch(
        dueDate: const Patch.set(CalendarDate(2025, 3, 4)),
        dueTime: const Patch.set(LocalTime(7, 5)),
        deferUntil: Patch.set(DateTime.utc(2025, 1, 2, 3)),
        projectUid: const Patch.set(ProjectUid('p1')),
        areaUid: const Patch.clear(),
        recurrenceEndDate: const Patch.set(CalendarDate(2026, 1, 1)),
        recurrenceWeekdays: const Patch.set([1, 3]),
        completionBased: const Patch.set(true),
      ).toJson();
      expect(json, {
        'due_date': '2025-03-04',
        'due_time': '07:05',
        'defer_until': '2025-01-02T03:00:00.000Z',
        'project_uid': 'p1',
        'area_uid': null,
        'recurrence_end_date': '2026-01-01',
        'recurrence_weekdays': [1, 3],
        'completion_based': true,
      });
    });

    test('tags are a full replacement list of names', () {
      expect(const TaskPatch(tags: Patch.set(['a', 'b'])).toJson(), {
        'tags': [
          {'name': 'a'},
          {'name': 'b'},
        ],
      });
      expect(const TaskPatch(tags: Patch.set([])).toJson(), {'tags': []});
      expect(const TaskPatch(tags: Patch.clear()).toJson(), {'tags': null});
    });

    test('due_date alone does not add due_time (server drops it)', () {
      final json = const TaskPatch(dueDate: Patch.set(CalendarDate(2025, 3, 4)))
          .toJson();
      expect(json.keys, ['due_date']);
    });

    test('moveTo writes the time too, or clears it explicitly', () {
      expect(
        TaskPatch.moveTo(
          const CalendarDate(2025, 3, 4),
          time: const LocalTime(9, 0),
        ).toJson(),
        {'due_date': '2025-03-04', 'due_time': '09:00'},
      );
      expect(TaskPatch.moveTo(const CalendarDate(2025, 3, 4)).toJson(), {
        'due_date': '2025-03-04',
        'due_time': null,
      });
    });
  });

  test('TaskCreate sends only what is set', () {
    final json = const TaskCreate(
      NewTask(name: '  Buy milk  ', projectUid: ProjectUid('p1')),
    ).toJson();
    expect(json, {'name': 'Buy milk', 'project_uid': 'p1'});

    final full = const TaskCreate(
      NewTask(
        name: 'x',
        priority: Priority.medium,
        dueDate: CalendarDate(2025, 1, 1),
        dueTime: LocalTime(8, 0),
        tags: ['a'],
        parentTaskId: 7,
      ),
    ).toJson();
    expect(full['priority'], 1);
    expect(full['due_time'], '08:00');
    expect(full['parent_task_id'], 7);
    expect(full['tags'], [
      {'name': 'a'},
    ]);
  });

  test('TaskQuery sends project_uid and skips unset fields', () {
    expect(const TaskQuery().toQueryParameters(), isEmpty);
    final q = const TaskQuery(
      type: 'all',
      projectUid: ProjectUid('p1'),
      areaUid: AreaUid('a1'),
      search: '',
      includeSubtasks: true,
      limit: 20,
      offset: 40,
    ).toQueryParameters();
    expect(q, {
      'type': 'all',
      'project_uid': 'p1',
      'area_uid': 'a1',
      'include_subtasks': 'true',
      'limit': 20,
      'offset': 40,
    });
  });
}
