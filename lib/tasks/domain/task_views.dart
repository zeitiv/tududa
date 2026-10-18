import 'package:drift/drift.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/db/app_database.dart';
import '../../core/time/calendar_date.dart';
import '../../core/time/user_clock.dart';
import 'task.dart';

/// The lists the app shows. Each mirrors a list of the Tududi server, so the
/// offline answer matches what the web app shows for the same data:
///
/// * `backend/modules/tasks/queries/query-builders.js` (`filterTasksByParams`:
///   `type=today|upcoming|someday|all` and the `status` filter), and
/// * `backend/modules/tasks/queries/metrics-queries.js`
///   (`fetchOverdueTasks`, `fetchTasksDueToday`, `fetchTodayPlanTasks`,
///   `fetchTasksCompletedToday`), assembled in `metrics-computation.js`.
///
/// Deliberate differences from the server: project due dates do not make a
/// task overdue / due today, and "someday"-tagged tasks are not special-cased.
enum TaskView {
  /// [overdue] + [dueToday] + [todayPlan]: everything the Today screen lists
  /// as still to do.
  today,

  /// Open tasks whose due date is before today.
  overdue,

  /// Open tasks due today.
  dueToday,

  /// In progress / planned / waiting tasks that are not deferred
  /// (`TODAY_PLAN_STATUSES` on the server).
  todayPlan,

  /// Done today in the user's zone.
  completedToday,

  /// Due (or deferred to) one of the next 7 days, plus recurring templates.
  upcoming,

  /// No due date.
  someday,

  /// Done or archived.
  completed,

  /// Everything that is not finished.
  all,
}

/// "Today" for the user: the calendar date and the instants that bound it.
/// Build it from a `UserClock` so the user's time zone (and the measured
/// server skew) decide where the day starts.
class TaskDay {
  const TaskDay({
    required this.date,
    required this.startUtc,
    required this.endUtc,
    required this.upcomingEndUtc,
    required this.nowUtc,
  });

  /// [date] interpreted in UTC (no zone information available).
  factory TaskDay.utc(CalendarDate date, {DateTime? now}) {
    DateTime at(CalendarDate d) => DateTime.utc(d.year, d.month, d.day);
    return TaskDay(
      date: date,
      startUtc: at(date),
      endUtc: at(date.addDays(1)),
      upcomingEndUtc: at(date.addDays(8)),
      nowUtc: (now ?? at(date)).toUtc(),
    );
  }

  factory TaskDay.fromClock(UserClock clock) {
    final now = clock.nowInZone();
    final date = CalendarDate.fromDateTime(now);
    DateTime at(CalendarDate d) =>
        tz.TZDateTime(now.location, d.year, d.month, d.day).toUtc();
    return TaskDay(
      date: date,
      startUtc: at(date),
      endUtc: at(date.addDays(1)),
      upcomingEndUtc: at(date.addDays(8)),
      nowUtc: now.toUtc(),
    );
  }

  final CalendarDate date;

  /// First instant of [date] (inclusive).
  final DateTime startUtc;

  /// First instant of the next day (exclusive).
  final DateTime endUtc;

  /// First instant after the 7th day from today (exclusive).
  final DateTime upcomingEndUtc;
  final DateTime nowUtc;

  @override
  bool operator ==(Object other) =>
      other is TaskDay &&
      other.date == date &&
      other.startUtc == startUtc &&
      other.nowUtc == nowUtc;

  @override
  int get hashCode => Object.hash(date, startUtc, nowUtc);
}

/// Status codes (see `TaskStatus`).
const _done = 2, _archived = 3, _cancelled = 5;
const _planStatuses = [1, 4, 6]; // in progress, waiting, planned

bool _isPlan(TaskStatus s) => _planStatuses.contains(s.code);

/// Pure-Dart mirror of the SQL in [taskViewWhere]. Used by tests and by code
/// that already holds a list of tasks.
abstract final class TaskViews {
  /// Whether [t] is a subtask (listed under its parent, never top-level).
  static bool isSubtask(Task t) =>
      t.parentLocalId != null || t.parentTaskId != null;

  static bool _isInstance(Task t) => t.recurringParentUid != null;

  static bool _isTemplate(Task t) => t.isRecurring && !_isInstance(t);

  static bool _open(Task t) =>
      t.status != TaskStatus.done &&
      t.status != TaskStatus.archived &&
      t.status != TaskStatus.cancelled;

  static bool _notDeferred(Task t, TaskDay day) =>
      t.deferUntil == null || !t.deferUntil!.toUtc().isAfter(day.nowUtc);

  /// Uids of recurring templates that have an instance due today. Their
  /// template is hidden from the today lists (the instance stands for it).
  static Set<String> templatesWithInstanceToday(
    Iterable<Task> all,
    TaskDay day,
  ) => {
    for (final t in all)
      if (_isInstance(t) && !t.isCompleted && t.dueDate == day.date)
        t.recurringParentUid!.value,
  };

  /// Whether [t] belongs to [view] today. [hiddenTemplates] comes from
  /// [templatesWithInstanceToday].
  static bool matches(
    TaskView view,
    Task t,
    TaskDay day, {
    Set<String> hiddenTemplates = const {},
  }) {
    if (isSubtask(t)) return false;
    final hidden = _isTemplate(t) && hiddenTemplates.contains(t.uid.value);
    final due = t.dueDate;
    switch (view) {
      case TaskView.overdue:
        // query: fetchOverdueTasks (instances are never listed as overdue).
        return !hidden &&
            !_isInstance(t) &&
            _open(t) &&
            due != null &&
            due.isBefore(day.date);
      case TaskView.dueToday:
        // query: fetchTasksDueToday.
        return !hidden && _open(t) && due == day.date;
      case TaskView.todayPlan:
        // query: fetchTodayPlanTasks / type=today.
        return !hidden && _isPlan(t.status) && _notDeferred(t, day);
      case TaskView.today:
        return matches(
              TaskView.overdue,
              t,
              day,
              hiddenTemplates: hiddenTemplates,
            ) ||
            matches(
              TaskView.dueToday,
              t,
              day,
              hiddenTemplates: hiddenTemplates,
            ) ||
            matches(
              TaskView.todayPlan,
              t,
              day,
              hiddenTemplates: hiddenTemplates,
            );
      case TaskView.completedToday:
        // query: fetchTasksCompletedToday.
        final at = t.completedAt?.toUtc();
        return t.status == TaskStatus.done &&
            at != null &&
            !at.isBefore(day.startUtc) &&
            at.isBefore(day.endUtc);
      case TaskView.upcoming:
        // query-builders.js `type=upcoming`.
        if (t.isCompleted) return false;
        if (_isTemplate(t)) return true;
        if (_isInstance(t)) return false;
        final nextWeekEnd = day.date.addDays(7);
        final dueInRange =
            due != null && due.isAfter(day.date) && !due.isAfter(nextWeekEnd);
        final defer = t.deferUntil?.toUtc();
        final deferInRange =
            defer != null &&
            !defer.isBefore(day.endUtc) &&
            defer.isBefore(day.upcomingEndUtc);
        return dueInRange || deferInRange;
      case TaskView.someday:
        // query-builders.js `type=someday`.
        return due == null && !_isInstance(t) && !t.isCompleted;
      case TaskView.completed:
        return t.isCompleted;
      case TaskView.all:
        return !t.isCompleted;
    }
  }

  /// The tasks of [view] among [all], in input order.
  static List<Task> select(TaskView view, Iterable<Task> all, TaskDay day) {
    final list = all.toList();
    final hidden = templatesWithInstanceToday(list, day);
    return [
      for (final t in list)
        if (matches(view, t, day, hiddenTemplates: hidden)) t,
    ];
  }
}

// ---- SQL ----

/// The SQL `where` of [view] over the tasks table; the SQL twin of
/// [TaskViews.matches]. Pending-delete rows and subtasks never match.
Expression<bool> taskViewWhere($TasksTable t, TaskView view, TaskDay day) {
  final todayIso = day.date.toIso();
  final topLevel = t.parentLocalId.isNull() & t.pendingDelete.equals(false);
  final open = t.status.isNotIn([_done, _archived, _cancelled]);
  final notFinished = t.status.isNotIn([_done, _archived]);
  final isInstance = t.recurringParentUid.isNotNull();
  final isRecurring =
      t.recurrenceType.isNotNull() &
      t.recurrenceType.equals('none').not() &
      t.recurrenceType.equals('').not();
  final isTemplate = isRecurring & t.recurringParentUid.isNull();
  // todayIso is digits and dashes only, so inlining it is safe.
  final hasInstanceToday = CustomExpression<bool>(
    'EXISTS (SELECT 1 FROM tasks i WHERE i.recurring_parent_uid = tasks.uid '
    "AND i.due_date = '$todayIso' AND i.pending_delete = 0 "
    'AND i.status NOT IN ($_done, $_archived))',
    precedence: Precedence.primary,
  );
  final visible = (isTemplate & hasInstanceToday).not();
  final notDeferred =
      t.deferUntil.isNull() | t.deferUntil.isSmallerOrEqualValue(day.nowUtc);

  Expression<bool> overdue() =>
      topLevel &
      visible &
      isInstance.not() &
      open &
      t.dueDate.isNotNull() &
      t.dueDate.isSmallerThanValue(todayIso);
  Expression<bool> dueToday() =>
      topLevel & visible & open & t.dueDate.equals(todayIso);
  Expression<bool> todayPlan() =>
      topLevel & visible & t.status.isIn(_planStatuses) & notDeferred;

  switch (view) {
    case TaskView.overdue:
      return overdue();
    case TaskView.dueToday:
      return dueToday();
    case TaskView.todayPlan:
      return todayPlan();
    case TaskView.today:
      return overdue() | dueToday() | todayPlan();
    case TaskView.completedToday:
      return topLevel &
          t.status.equals(_done) &
          t.completedAt.isBiggerOrEqualValue(day.startUtc) &
          t.completedAt.isSmallerThanValue(day.endUtc);
    case TaskView.upcoming:
      final nextWeekEnd = day.date.addDays(7).toIso();
      final plain = isInstance.not() & isTemplate.not();
      return topLevel &
          notFinished &
          (isTemplate |
              (plain &
                  ((t.dueDate.isBiggerThanValue(todayIso) &
                          t.dueDate.isSmallerOrEqualValue(nextWeekEnd)) |
                      (t.deferUntil.isBiggerOrEqualValue(day.endUtc) &
                          t.deferUntil.isSmallerThanValue(
                            day.upcomingEndUtc,
                          )))));
    case TaskView.someday:
      return topLevel & notFinished & t.dueDate.isNull() & isInstance.not();
    case TaskView.completed:
      return topLevel & notFinished.not();
    case TaskView.all:
      return topLevel & notFinished;
  }
}
