import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/calendar_date.dart';
import '../domain/task.dart';
import 'task_provider.dart';

/// The parts of the day a task can fall into.
enum TodayBucket { overdue, morning, afternoon, evening, anytime }

/// The Today screen's lists, already split and de-duplicated.
class TodaySections {
  const TodaySections({
    this.overdue = const [],
    this.morning = const [],
    this.afternoon = const [],
    this.evening = const [],
    this.anytime = const [],
    this.completed = const [],
  });

  final List<Task> overdue;
  final List<Task> morning;
  final List<Task> afternoon;
  final List<Task> evening;
  final List<Task> anytime;
  final List<Task> completed;

  /// Everything still to do, in display order.
  List<Task> get remaining => [
    ...overdue,
    ...morning,
    ...afternoon,
    ...evening,
    ...anytime,
  ];

  int get doneCount => completed.length;
  int get totalCount => doneCount + remaining.length;

  /// Done share of today's tasks, 0..1 (0 when there are none).
  double get progress => totalCount == 0 ? 0 : doneCount / totalCount;

  /// Sum of the estimates of the tasks still to do.
  int get remainingMinutes =>
      remaining.fold(0, (sum, t) => sum + (t.estimatedMinutes ?? 0));

  bool get isEmpty => totalCount == 0;
}

/// The bucket of a task that is not overdue. Only tasks due today are placed
/// by their time; plan tasks with another (or no) date are "anytime".
TodayBucket bucketFor(Task t, CalendarDate today) {
  final time = t.dueTime;
  if (time == null || t.dueDate != today) return TodayBucket.anytime;
  if (time.hour < 12) return TodayBucket.morning;
  if (time.hour < 18) return TodayBucket.afternoon;
  return TodayBucket.evening;
}

int _compare(Task a, Task b) {
  final at = a.dueTime, bt = b.dueTime;
  if (at != null && bt != null) {
    final c = at.compareTo(bt);
    if (c != 0) return c;
  }
  final p = b.priority.code.compareTo(a.priority.code);
  return p != 0 ? p : a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

/// Splits the four views into sections. A task shows once: overdue wins, then
/// due today, then the plan.
TodaySections buildTodaySections({
  required CalendarDate today,
  required List<Task> overdue,
  required List<Task> dueToday,
  required List<Task> todayPlan,
  required List<Task> completedToday,
}) {
  final seen = <String>{};
  String key(Task t) => t.localId ?? t.uid.value;
  final over = <Task>[];
  final buckets = {for (final b in TodayBucket.values) b: <Task>[]};
  for (final t in overdue) {
    if (seen.add(key(t))) over.add(t);
  }
  for (final t in [...dueToday, ...todayPlan]) {
    if (t.isCompleted || !seen.add(key(t))) continue;
    buckets[bucketFor(t, today)]!.add(t);
  }
  // Completed tasks are listed only in their own section.
  final done = [
    for (final t in completedToday)
      if (!seen.contains(key(t))) t,
  ];
  List<Task> sorted(List<Task> l) => l..sort(_compare);
  return TodaySections(
    overdue: sorted(over),
    morning: sorted(buckets[TodayBucket.morning]!),
    afternoon: sorted(buckets[TodayBucket.afternoon]!),
    evening: sorted(buckets[TodayBucket.evening]!),
    anytime: sorted(buckets[TodayBucket.anytime]!),
    completed: done,
  );
}

/// The Today screen's data, live. Loading until all four lists have loaded;
/// an error in any of them is the error.
final todaySectionsProvider = Provider<AsyncValue<TodaySections>>((ref) {
  final today = ref.watch(taskDayProvider).date;
  final lists = [
    ref.watch(taskViewListProvider(TaskView.overdue)),
    ref.watch(taskViewListProvider(TaskView.dueToday)),
    ref.watch(taskViewListProvider(TaskView.todayPlan)),
    ref.watch(taskViewListProvider(TaskView.completedToday)),
  ];
  for (final l in lists) {
    if (l.hasError && !l.hasValue) {
      return AsyncError(l.error!, l.stackTrace ?? StackTrace.empty);
    }
  }
  if (lists.any((l) => !l.hasValue)) return const AsyncLoading();
  return AsyncData(
    buildTodaySections(
      today: today,
      overdue: lists[0].value!,
      dueToday: lists[1].value!,
      todayPlan: lists[2].value!,
      completedToday: lists[3].value!,
    ),
  );
});
