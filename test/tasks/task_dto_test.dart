import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/time/calendar_date.dart';
import 'package:tududa/tasks/data/dto/task_dto.dart';
import 'package:tududa/tasks/data/dto/task_list_response.dart';
import 'package:tududa/tasks/domain/task.dart';
import 'package:tududa/tasks/domain/task_mapper.dart';

import '../support/fixtures/fixtures.dart';

Map<String, dynamic> obj(String fixture) =>
    Map<String, dynamic>.from(loadFixture(fixture) as Map);

void main() {
  group('TaskDto', () {
    test('full fixture', () {
      final d = TaskDto.parse(obj('task_full.json'));
      expect(d.id, 42);
      expect(d.uid, 'task-full');
      expect(d.status, 1);
      expect(d.priority, 2);
      expect(d.dueDate, const CalendarDate(2025, 3, 14));
      expect(d.dueTime, const LocalTime(9, 30));
      expect(d.projectUid, 'proj-1');
      expect(d.recurrenceType, 'weekly');
      expect(d.recurrenceInterval, 2);
      expect(d.recurrenceEndDate, const CalendarDate(2025, 12, 31));
      expect(d.recurrenceWeekdays, [1, 3]);
      expect(d.completionBased, false);
      expect(d.estimatedMinutes, 45);
      expect(d.todayMoveCount, 3);
      expect(d.tags.map((t) => t.name), ['work', 'urgent']);
      expect(d.subtasks.single.uid, 'task-sub');
      expect(d.subtasks.single.status, 2);
      expect(d.createdAt, DateTime.utc(2025, 3, 1, 8));
      expect(d.updatedAt, DateTime.utc(2025, 3, 10, 12, 15, 30));
    });

    test('minimal fixture: everything else is null or empty', () {
      final d = TaskDto.parse(obj('task_minimal.json'));
      expect(d.name, 'Minimal task');
      expect(d.dueDate, isNull);
      expect(d.dueTime, isNull);
      expect(d.tags, isEmpty);
      expect(d.subtasks, isEmpty);
    });

    test('status and priority as names', () {
      final d = TaskDto.parse(obj('task_status_as_string.json'));
      expect(d.status, 1);
      expect(d.priority, 2);
      final t = taskFromDto(d);
      expect(t.status, TaskStatus.inProgress);
      expect(t.priority, Priority.high);
    });

    test('status and priority are written back as numbers', () {
      final json = TaskDto.parse(obj('task_status_as_string.json')).toJson();
      expect(json['status'], 1);
      expect(json['priority'], 2);
    });

    test('original_name wins for display, name is the fallback', () {
      final a = TaskDto.parse({
        'uid': 'a',
        'name': 'Rewritten template name',
        'original_name': 'Water plants',
      });
      expect(a.displayName, 'Water plants');
      expect(taskFromDto(a).name, 'Water plants');
      final b = TaskDto.parse({'uid': 'b', 'name': 'Plain'});
      expect(b.displayName, 'Plain');
      final c = TaskDto.parse({'uid': 'c', 'name': 'N', 'original_name': ''});
      expect(c.displayName, 'N');
    });

    test('nulls, unknown keys and bad values are tolerated', () {
      final d = TaskDto.parse({
        'uid': 'x',
        'name': 'X',
        'note': null,
        'status': null,
        'priority': 'bogus',
        'due_date': null,
        'due_time': 'not a time',
        'tags': null,
        'subtasks': null,
        'created_at': 'garbage',
        'habit_mode': true,
        'something_new': {'a': 1},
      });
      expect(d.status, isNull);
      expect(d.priority, isNull);
      expect(d.dueTime, isNull);
      expect(d.createdAt, isNull);
      expect(d.tags, isEmpty);
      final t = taskFromDto(d);
      expect(t.status, TaskStatus.notStarted);
      expect(t.priority, Priority.low);
    });

    test('a due_date with a timestamp keeps the written day', () {
      final d = TaskDto.parse({
        'uid': 'x',
        'name': 'X',
        'due_date': '2025-03-14T00:00:00.000Z',
      });
      expect(d.dueDate, const CalendarDate(2025, 3, 14));
    });

    test('camelCase and PascalCase fallbacks', () {
      final d = TaskDto.parse({
        'uid': 'x',
        'name': 'X',
        'dueDate': '2025-01-02',
        'completedAt': '2025-01-03T10:00:00Z',
        'Subtasks': [
          {'uid': 'y', 'name': 'Y', 'dueDate': '2025-01-04'},
        ],
        'Tags': [
          {'name': 'a'},
          'b',
        ],
        'Project': {'uid': 'proj', 'name': 'Home'},
      });
      expect(d.dueDate, const CalendarDate(2025, 1, 2));
      expect(d.completedAt, DateTime.utc(2025, 1, 3, 10));
      expect(d.subtasks.single.dueDate, const CalendarDate(2025, 1, 4));
      expect(d.tags.map((t) => t.name), ['a', 'b']);
      expect(d.projectUid, 'proj');
      expect(d.projectName, 'Home');
    });

    test('snake_case wins over camelCase', () {
      final d = TaskDto.parse({
        'uid': 'x',
        'name': 'X',
        'due_date': '2025-01-02',
        'dueDate': '2030-01-01',
      });
      expect(d.dueDate, const CalendarDate(2025, 1, 2));
    });

    test('a wrongly typed field is a FormatException', () {
      expect(
        () => TaskDto.parse({'uid': 'x', 'name': 5}),
        throwsFormatException,
      );
    });
  });

  group('TaskListResponse', () {
    test('bare list', () {
      final r = TaskListResponse.fromJson(loadFixture('tasks_list_bare.json'));
      expect(r.tasks.map((t) => t.uid), ['task-a', 'task-b']);
      expect(r.page.total, 2);
      expect(r.page.hasMore, isFalse);
      expect(r.lists, isNull);
    });

    test('wrapped list with pagination', () {
      final r = TaskListResponse.fromJson(
        loadFixture('tasks_list_wrapped.json'),
      );
      expect(r.tasks, hasLength(2));
      expect(r.page.limit, 50);
      expect(r.page.offset, 0);
    });

    test('include_lists extras are typed and not mixed into tasks', () {
      final r = TaskListResponse.fromJson({
        'tasks': [
          {'uid': 'main', 'name': 'main'},
        ],
        'tasks_overdue': [
          {'uid': 'o1', 'name': 'o1'},
          {'uid': 'o2', 'name': 'o2'},
        ],
        'tasks_due_today': [
          {'uid': 'd1', 'name': 'd1'},
        ],
        'tasks_today_plan': [],
        'tasks_in_progress': [
          {'uid': 'p1', 'name': 'p1'},
        ],
        'tasks_completed_today': [
          {'uid': 'c1', 'name': 'c1'},
        ],
        'pagination': {'total': 9, 'limit': 1, 'offset': 0, 'hasMore': true},
      });
      expect(r.tasks.map((x) => x.uid), ['main']);
      expect(r.page.hasMore, isTrue);
      expect(r.lists!.overdue.map((x) => x.uid), ['o1', 'o2']);
      expect(r.lists!.dueToday.map((x) => x.uid), ['d1']);
      expect(r.lists!.todayPlan, isEmpty);
      expect(r.lists!.inProgress.map((x) => x.uid), ['p1']);
      expect(r.lists!.completedToday.map((x) => x.uid), ['c1']);
    });

    test('an object without tasks is an empty list', () {
      final r = TaskListResponse.fromJson({
        'pagination': {'total': 0},
      });
      expect(r.tasks, isEmpty);
    });

    test('garbage is a FormatException', () {
      expect(() => TaskListResponse.fromJson('nope'), throwsFormatException);
    });
  });

  group('Task domain', () {
    test('status and priority codes', () {
      expect(TaskStatus.fromCode(6), TaskStatus.planned);
      expect(TaskStatus.fromCode(99), TaskStatus.unknown);
      expect(TaskStatus.fromCode(null), TaskStatus.notStarted);
      expect(TaskStatus.done.code, 2);
      expect(Priority.fromCode(2), Priority.high);
      expect(Priority.fromCode(9), Priority.low);
    });

    test('isDone, isOverdue and isRecurring', () {
      final today = const CalendarDate(2025, 3, 14);
      final t = taskFromDto(
        TaskDto.parse({'uid': 'a', 'name': 'A', 'due_date': '2025-03-13'}),
      );
      expect(t.isOverdue(today), isTrue);
      expect(t.copyWith(dueDate: today).isOverdue(today), isFalse);
      expect(t.copyWith(status: TaskStatus.done).isOverdue(today), isFalse);
      expect(t.copyWith(status: TaskStatus.done).isDone, isTrue);
      expect(t.copyWith(status: TaskStatus.archived).isDone, isFalse);
      expect(t.copyWith(status: TaskStatus.archived).isCompleted, isTrue);
      expect(t.copyWith(dueDate: null).isOverdue(today), isFalse);
      expect(t.isRecurring, isFalse);
      expect(t.copyWith(recurrenceType: 'daily').isRecurring, isTrue);
    });

    test('mapper round trip keeps the fields', () {
      final t = taskFromDto(TaskDto.parse(obj('task_full.json')));
      expect(t.dueTime, const LocalTime(9, 30));
      expect(t.subtasks.single.isDone, isTrue);
      expect(t.tags.map((g) => g.name), ['work', 'urgent']);
      final again = taskFromDto(taskToDto(t));
      expect(again, t);
    });
  });
}
