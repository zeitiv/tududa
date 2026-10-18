import '../../../core/api/page.dart';
import 'task_dto.dart';

/// The extra lists Tududi adds to `GET /tasks?type=today&include_lists=true`.
class TodayLists {
  const TodayLists({
    this.overdue = const [],
    this.dueToday = const [],
    this.todayPlan = const [],
    this.inProgress = const [],
    this.completedToday = const [],
  });

  final List<TaskDto> overdue;
  final List<TaskDto> dueToday;
  final List<TaskDto> todayPlan;
  final List<TaskDto> inProgress;
  final List<TaskDto> completedToday;
}

/// `GET /tasks`: either a bare list or `{tasks, pagination}`, optionally with
/// the `include_lists` extras.
class TaskListResponse {
  const TaskListResponse({required this.page, this.lists});

  final Page<TaskDto> page;

  /// Non-null only when the response carried at least one extra list.
  final TodayLists? lists;

  List<TaskDto> get tasks => page.items;

  /// Throws [FormatException] when [json] is neither a list nor an object.
  factory TaskListResponse.fromJson(Object? json) {
    TaskDto one(Map<String, dynamic> m) => TaskDto.parse(m);

    if (json is List) {
      return TaskListResponse(page: Page.fromJson(json, one));
    }
    if (json is! Map) {
      throw FormatException('Expected a task list', json);
    }

    // Only look at `tasks` / `pagination`; the `tasks_*` extras are lists too
    // and must not be mistaken for the main list.
    final page = Page.fromJson(
      <String, Object?>{
        'tasks': json['tasks'] is List ? json['tasks'] : const [],
        'pagination': json['pagination'],
      },
      one,
      itemsKey: 'tasks',
    );

    List<TaskDto> extra(String key) {
      final v = json[key];
      if (v is! List) return const [];
      return [for (final e in v) one(Map<String, dynamic>.from(e as Map))];
    }

    const keys = [
      'tasks_overdue',
      'tasks_due_today',
      'tasks_today_plan',
      'tasks_in_progress',
      'tasks_completed_today',
    ];
    final lists = keys.any(json.containsKey)
        ? TodayLists(
            overdue: extra('tasks_overdue'),
            dueToday: extra('tasks_due_today'),
            todayPlan: extra('tasks_today_plan'),
            inProgress: extra('tasks_in_progress'),
            completedToday: extra('tasks_completed_today'),
          )
        : null;
    return TaskListResponse(page: page, lists: lists);
  }
}
