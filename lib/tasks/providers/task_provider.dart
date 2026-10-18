import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/session/session_providers.dart';
import '../../core/api/api_error.dart';
import '../../core/db/app_database.dart';
import '../../core/ids.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/sync/sync_handler.dart';
import '../../core/time/calendar_date.dart';
import '../data/offline_task_repository.dart';
import '../data/task_dao.dart';
import '../data/task_patch.dart';
import '../data/task_query.dart';
import '../data/task_repository.dart';
import '../data/undo_token.dart';
import '../domain/new_task.dart';
import '../domain/task.dart';
import '../domain/task_views.dart';

export '../data/undo_token.dart' show UndoToken;
export '../domain/task_views.dart' show TaskDay, TaskView;

/// The task views of the Tasks screen.
enum TaskFilter {
  today,
  upcoming,
  someday,
  completed,
  all;

  /// The list behind this tab.
  TaskView get view => switch (this) {
    TaskFilter.today => TaskView.today,
    TaskFilter.upcoming => TaskView.upcoming,
    TaskFilter.someday => TaskView.someday,
    TaskFilter.completed => TaskView.completed,
    TaskFilter.all => TaskView.all,
  };
}

/// Task sort options.
enum TaskSort { name, dueDate, createdAt, priority }

/// The server query behind each view.
TaskQuery taskQueryFor(TaskFilter filter) => switch (filter) {
  TaskFilter.today => const TaskQuery(type: 'today'),
  TaskFilter.upcoming => const TaskQuery(type: 'upcoming'),
  TaskFilter.someday => const TaskQuery(type: 'someday'),
  TaskFilter.completed => const TaskQuery(type: 'all', status: 'completed'),
  TaskFilter.all => const TaskQuery(type: 'all'),
};

/// Sorts [tasks] for display. Tasks without the sort key go last.
List<Task> sortTasks(
  Iterable<Task> tasks,
  TaskSort sort, {
  bool ascending = true,
}) {
  int byDate<T extends Comparable<Object>>(T? a, T? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  final sorted = List<Task>.of(tasks);
  sorted.sort((a, b) {
    final result = switch (sort) {
      TaskSort.name => a.name.compareTo(b.name),
      TaskSort.dueDate => byDate<CalendarDate>(a.dueDate, b.dueDate),
      TaskSort.createdAt => byDate<DateTime>(a.createdAt, b.createdAt),
      TaskSort.priority => b.priority.code.compareTo(a.priority.code),
    };
    return ascending ? result : -result;
  });
  return sorted;
}

/// Outcome of a task mutation. Writes go to the local database first, so a
/// failure here is a local one (validation, unknown task); server errors show
/// up in the sync status instead. [undo] reverts the change (see
/// `TaskActions.undo`).
class TaskResult<T> {
  const TaskResult.ok([this.value, this.undo]) : error = null;
  const TaskResult.failure(ApiError this.error) : value = null, undo = null;

  final T? value;
  final ApiError? error;
  final UndoToken? undo;

  bool get ok => error == null;
}

/// The user's "today" (zone aware). Recomputed after midnight.
final taskDayProvider = Provider<TaskDay>((ref) {
  final day = TaskDay.fromClock(ref.watch(userClockProvider));
  final untilMidnight = day.endUtc.difference(day.nowUtc);
  final timer = Timer(
    untilMidnight + const Duration(seconds: 1),
    ref.invalidateSelf,
  );
  ref.onDispose(timer.cancel);
  return day;
});

final taskDaoProvider = Provider<TaskDao>(
  (ref) => TaskDao(ref.watch(appDatabaseProvider)),
);

/// The tasks of one list, live from the database.
final taskViewListProvider = StreamProvider.family<List<Task>, TaskView>((
  ref,
  view,
) {
  final day = ref.watch(taskDayProvider);
  return ref.watch(taskDaoProvider).watchView(view, today: day.date, day: day);
});

/// The tasks of one tab, live from the database: edits made offline show up
/// at once, and the list follows sync results without reloading.
class TaskListNotifier extends StreamNotifier<List<Task>> {
  TaskListNotifier(this.filter);

  final TaskFilter filter;

  @override
  Stream<List<Task>> build() {
    final day = ref.watch(taskDayProvider);
    return ref
        .watch(taskDaoProvider)
        .watchView(filter.view, today: day.date, day: day);
  }

  /// Pull-to-refresh: runs a sync cycle (pull, then push). Local edits are
  /// merged, never overwritten. Completes when the cycle has finished.
  Future<void> refresh() =>
      ref.read(syncEngineProvider).requestSync(SyncReason.manual);
}

final taskListProvider =
    StreamNotifierProvider.family<TaskListNotifier, List<Task>, TaskFilter>(
      TaskListNotifier.new,
    );

/// One task, live from the database. Accepts the server uid or the local id
/// (tasks created offline have no uid yet).
class TaskDetailNotifier extends StreamNotifier<Task> {
  TaskDetailNotifier(this.uid);

  final TaskUid uid;

  @override
  Stream<Task> build() async* {
    var seen = false;
    await for (final t in ref.watch(taskDaoProvider).watchByAnyId(uid.value)) {
      if (t == null) {
        if (!seen) throw const NotFoundError('Task not found');
        continue; // deleted while shown
      }
      seen = true;
      yield t;
    }
  }
}

final taskDetailProvider =
    StreamNotifierProvider.family<TaskDetailNotifier, Task, TaskUid>(
      TaskDetailNotifier.new,
    );

/// The subtasks of a task, live.
final taskSubtasksProvider = StreamProvider.family<List<Task>, String>(
  (ref, parentLocalId) =>
      ref.watch(taskDaoProvider).watchSubtasks(parentLocalId),
);

/// The view selected on the Tasks screen.
class SelectedTaskFilter extends Notifier<TaskFilter> {
  @override
  TaskFilter build() => TaskFilter.today;

  void select(TaskFilter filter) => state = filter;
}

final selectedTaskFilterProvider =
    NotifierProvider<SelectedTaskFilter, TaskFilter>(SelectedTaskFilter.new);

class TaskSortState {
  const TaskSortState({this.sort = TaskSort.dueDate, this.ascending = true});
  final TaskSort sort;
  final bool ascending;
}

class TaskSortNotifier extends Notifier<TaskSortState> {
  @override
  TaskSortState build() => const TaskSortState();

  void setSort(TaskSort sort, {bool? ascending}) => state = TaskSortState(
    sort: sort,
    ascending: ascending ?? state.ascending,
  );
}

final taskSortProvider = NotifierProvider<TaskSortNotifier, TaskSortState>(
  TaskSortNotifier.new,
);

/// Status a task had before it was completed (the `status_before_done`
/// column), restored when it is reopened; null when unknown.
final statusBeforeDoneProvider = FutureProvider.family<TaskStatus?, TaskUid>(
  (ref, uid) => ref.read(offlineTaskRepositoryProvider).statusBeforeDone(uid),
);

/// All task mutations. They write to the local database (row, dirty marks
/// and outbox entry in one transaction), so every list and the detail screen
/// update at once; `SyncEngine` sends the change after the undo window.
final taskActionsProvider = Provider<TaskActions>(TaskActions.new);

class TaskActions {
  TaskActions(this._ref);

  final Ref _ref;

  TaskRepository get _repo => _ref.read(taskRepositoryProvider);

  Future<TaskResult<T>> _run<T>(Future<Change<T>> Function() call) async {
    try {
      final change = await call();
      return TaskResult.ok(change.value, change.undo);
    } on ApiError catch (e) {
      return TaskResult.failure(e);
    }
  }

  Future<TaskResult<Task>> complete(Task task) {
    if (task.isCompleted) return Future.value(TaskResult.ok(task));
    return _run(() => _repo.completeTracked(task.uid));
  }

  /// Reopens the task into the status it had before (not started if unknown).
  Future<TaskResult<Task>> uncomplete(Task task) =>
      _run(() => _repo.uncompleteTracked(task.uid));

  Future<TaskResult<Task>> toggleComplete(Task task) =>
      task.isCompleted ? uncomplete(task) : complete(task);

  /// Sets an arbitrary status (Kanban drag, form).
  Future<TaskResult<Task>> setStatus(Task task, TaskStatus status) {
    if (status == TaskStatus.done) return complete(task);
    return _run(
      () => _repo.updateTracked(task.uid, TaskPatch.withStatus(status)),
    );
  }

  Future<TaskResult<Task>> postpone(Task task, CalendarDate to) =>
      _run(() => _repo.postponeTracked(task.uid, to, keepTime: task.dueTime));

  Future<TaskResult<void>> delete(TaskUid uid) =>
      _run(() => _repo.deleteTracked(uid));

  Future<TaskResult<Task>> update(TaskUid uid, TaskPatch patch) =>
      _run(() => _repo.updateTracked(uid, patch));

  /// Applies [patch] to several tasks as one undoable change.
  Future<TaskResult<List<Task>>> bulk(List<TaskUid> uids, TaskPatch patch) =>
      _run(() => _repo.bulk(uids, patch));

  Future<TaskResult<Task>> create(NewTask task) async {
    try {
      return TaskResult.ok(await _repo.create(task));
    } on ApiError catch (e) {
      return TaskResult.failure(e);
    }
  }

  /// Creates a subtask; the parent may still be waiting to be synced.
  Future<TaskResult<Task>> createSubtask(Task parent, String name) async {
    try {
      return TaskResult.ok(await _repo.createSubtaskOf(parent.uid, name));
    } on ApiError catch (e) {
      return TaskResult.failure(e);
    }
  }

  Future<TaskResult<Task?>> skipOccurrence(TaskUid uid) =>
      _run(() => _repo.skipOccurrenceTracked(uid));

  /// Reverts the change behind [token]: cancels it if it has not been sent,
  /// otherwise queues the opposite change.
  Future<bool> undo(UndoToken token) => _repo.undo(token);
}
