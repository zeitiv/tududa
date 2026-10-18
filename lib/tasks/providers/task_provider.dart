import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/ids.dart';
import '../../core/time/calendar_date.dart';
import '../data/remote_task_repository.dart';
import '../data/task_patch.dart';
import '../data/task_query.dart';
import '../data/task_repository.dart';
import '../domain/new_task.dart';
import '../domain/task.dart';

/// The task views of the Tasks screen.
enum TaskFilter { today, upcoming, someday, completed, all }

/// Alias used by newer code.
typedef TaskView = TaskFilter;

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

/// Outcome of a task mutation. On failure the optimistic change has already
/// been rolled back.
class TaskResult<T> {
  const TaskResult.ok([this.value]) : error = null;
  const TaskResult.failure(ApiError this.error) : value = null;

  final T? value;
  final ApiError? error;

  bool get ok => error == null;
}

/// The tasks of one view.
class TaskListNotifier extends AsyncNotifier<List<Task>> {
  TaskListNotifier(this.filter);

  final TaskFilter filter;

  @override
  Future<List<Task>> build() => _load();

  Future<List<Task>> _load() async {
    final repo = ref.read(taskRepositoryProvider);
    final page = await repo.fetch(taskQueryFor(filter));
    return page.items;
  }

  /// Reloads from the server, keeping the old list on screen meanwhile.
  /// Throws the [ApiError] if the reload fails and a list is already shown.
  Future<void> refresh() async {
    final result = await AsyncValue.guard(_load);
    // A failed refresh keeps the list that is already on screen.
    if (result.hasError && state.hasValue) throw result.error!;
    state = result;
  }

  /// Replaces the list without a request (optimistic updates, rollbacks).
  void replaceAll(List<Task> tasks) => state = AsyncData(tasks);
}

final taskListProvider =
    AsyncNotifierProvider.family<TaskListNotifier, List<Task>, TaskFilter>(
      TaskListNotifier.new,
    );

/// One task, fetched by uid.
class TaskDetailNotifier extends AsyncNotifier<Task> {
  TaskDetailNotifier(this.uid);

  final TaskUid uid;

  @override
  Future<Task> build() => ref.read(taskRepositoryProvider).get(uid);

  void replace(Task task) => state = AsyncData(task);
}

final taskDetailProvider =
    AsyncNotifierProvider.family<TaskDetailNotifier, Task, TaskUid>(
      TaskDetailNotifier.new,
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

/// Status each task had before it was completed, so reopening restores it
/// (default: not started). In memory only; the offline milestone persists it.
final statusBeforeDoneProvider = Provider<Map<TaskUid, TaskStatus>>(
  (ref) => {},
);

/// All task mutations. Each one updates every loaded list and the detail
/// provider optimistically, calls the repository, and on failure restores
/// what it changed and returns the [ApiError] in the [TaskResult].
final taskActionsProvider = Provider<TaskActions>(TaskActions.new);

class TaskActions {
  TaskActions(this._ref);

  final Ref _ref;

  TaskRepository get _repo => _ref.read(taskRepositoryProvider);

  Future<TaskResult<Task>> complete(Task task) {
    if (task.isCompleted) return Future.value(TaskResult.ok(task));
    _ref.read(statusBeforeDoneProvider)[task.uid] = task.status;
    return _mutate(
      task.uid,
      (t) => t.copyWith(status: TaskStatus.done, completedAt: DateTime.now()),
      () => _repo.complete(task.uid),
    );
  }

  Future<TaskResult<Task>> uncomplete(Task task) async {
    final before = _ref.read(statusBeforeDoneProvider);
    final restoreTo = before[task.uid] ?? TaskStatus.notStarted;
    final result = await _mutate(
      task.uid,
      (t) => t.copyWith(status: restoreTo, completedAt: null),
      () => _repo.uncomplete(task.uid, restoreTo: restoreTo),
    );
    // Keep the remembered status if the request failed, for the retry.
    if (result.ok) before.remove(task.uid);
    return result;
  }

  Future<TaskResult<Task>> toggleComplete(Task task) =>
      task.isCompleted ? uncomplete(task) : complete(task);

  /// Sets an arbitrary status (Kanban drag, form).
  Future<TaskResult<Task>> setStatus(Task task, TaskStatus status) {
    if (status == TaskStatus.done) return complete(task);
    if (task.isCompleted) {
      _ref.read(statusBeforeDoneProvider).remove(task.uid);
    }
    return _mutate(
      task.uid,
      (t) => t.copyWith(
        status: status,
        completedAt: status.isFinished ? t.completedAt : null,
      ),
      () => _repo.update(task.uid, TaskPatch.withStatus(status)),
    );
  }

  Future<TaskResult<Task>> postpone(Task task, CalendarDate to) => _mutate(
    task.uid,
    (t) => t.copyWith(dueDate: to),
    () => _repo.postpone(task.uid, to, keepTime: task.dueTime),
  );

  Future<TaskResult<void>> delete(TaskUid uid) async {
    final snapshot = _snapshot(uid);
    _edit(uid, (_) => null);
    try {
      await _repo.delete(uid);
      return const TaskResult.ok();
    } on ApiError catch (e) {
      _restore(snapshot);
      return TaskResult.failure(e);
    }
  }

  /// Applies [patch] on the server, then updates the lists with the result.
  Future<TaskResult<Task>> update(TaskUid uid, TaskPatch patch) async {
    try {
      final saved = await _repo.update(uid, patch);
      _settle(uid, saved);
      return TaskResult.ok(saved);
    } on ApiError catch (e) {
      return TaskResult.failure(e);
    }
  }

  /// Creates a task, then reloads the lists that are on screen.
  Future<TaskResult<Task>> create(NewTask task) async {
    try {
      final created = await _repo.create(task);
      for (final f in TaskFilter.values) {
        if (_ref.exists(taskListProvider(f))) {
          _ref.invalidate(taskListProvider(f));
        }
      }
      return TaskResult.ok(created);
    } on ApiError catch (e) {
      return TaskResult.failure(e);
    }
  }

  Future<TaskResult<Task>> createSubtask(Task parent, String name) async {
    final parentId = parent.serverId;
    if (parentId == null) {
      return const TaskResult.failure(
        ValidationError('The parent task has no id yet'),
      );
    }
    try {
      final sub = await _repo.createSubtask(parentId: parentId, name: name);
      _ref.invalidate(taskDetailProvider(parent.uid));
      return TaskResult.ok(sub);
    } on ApiError catch (e) {
      return TaskResult.failure(e);
    }
  }

  Future<TaskResult<Task?>> skipOccurrence(TaskUid uid) async {
    try {
      final next = await _repo.skipOccurrence(uid);
      if (next != null) {
        _settle(uid, next);
      } else {
        for (final f in TaskFilter.values) {
          if (_ref.exists(taskListProvider(f))) {
            _ref.invalidate(taskListProvider(f));
          }
        }
        _ref.invalidate(taskDetailProvider(uid));
      }
      return TaskResult.ok(next);
    } on ApiError catch (e) {
      return TaskResult.failure(e);
    }
  }

  // ---- optimistic plumbing ----

  Future<TaskResult<Task>> _mutate(
    TaskUid uid,
    Task Function(Task) optimistic,
    Future<Task> Function() call,
  ) async {
    final snapshot = _snapshot(uid);
    _edit(uid, optimistic);
    try {
      final saved = await call();
      _settle(uid, saved);
      return TaskResult.ok(saved);
    } on ApiError catch (e) {
      _restore(snapshot);
      return TaskResult.failure(e);
    }
  }

  _Snapshot _snapshot(TaskUid uid) {
    final lists = <TaskFilter, List<Task>>{};
    for (final f in TaskFilter.values) {
      if (!_ref.exists(taskListProvider(f))) continue;
      final value = _ref.read(taskListProvider(f)).value;
      if (value != null) lists[f] = value;
    }
    final details = <TaskUid, Task>{};
    if (_ref.exists(taskDetailProvider(uid))) {
      final detail = _ref.read(taskDetailProvider(uid)).value;
      if (detail != null) details[uid] = detail;
    }
    return _Snapshot(lists, details);
  }

  void _restore(_Snapshot s) {
    s.lists.forEach((f, list) {
      if (_ref.exists(taskListProvider(f))) {
        _ref.read(taskListProvider(f).notifier).replaceAll(list);
      }
    });
    s.details.forEach((uid, task) {
      if (_ref.exists(taskDetailProvider(uid))) {
        _ref.read(taskDetailProvider(uid).notifier).replace(task);
      }
    });
  }

  /// Maps the task [uid] through [change] (null removes it) in every loaded
  /// list and the detail provider.
  void _edit(TaskUid uid, Task? Function(Task) change) {
    for (final f in TaskFilter.values) {
      if (!_ref.exists(taskListProvider(f))) continue;
      final list = _ref.read(taskListProvider(f)).value;
      if (list == null || !list.any((t) => t.uid == uid)) continue;
      _ref.read(taskListProvider(f).notifier).replaceAll([
        for (final t in list)
          if (t.uid != uid) t else ?change(t),
      ]);
    }
    if (_ref.exists(taskDetailProvider(uid))) {
      final current = _ref.read(taskDetailProvider(uid)).value;
      final changed = current == null ? null : change(current);
      if (changed != null) {
        _ref.read(taskDetailProvider(uid).notifier).replace(changed);
      }
    }
  }

  /// Puts the server's version into the lists. The completed view drops tasks
  /// that are no longer finished.
  void _settle(TaskUid uid, Task saved) {
    for (final f in TaskFilter.values) {
      if (!_ref.exists(taskListProvider(f))) continue;
      final list = _ref.read(taskListProvider(f)).value;
      if (list == null || !list.any((t) => t.uid == uid)) continue;
      final keep = !(f == TaskFilter.completed && !saved.isCompleted);
      _ref.read(taskListProvider(f).notifier).replaceAll([
        for (final t in list)
          if (t.uid != uid) t else if (keep) saved,
      ]);
    }
    if (_ref.exists(taskDetailProvider(uid))) {
      _ref.read(taskDetailProvider(uid).notifier).replace(saved);
    }
  }
}

class _Snapshot {
  _Snapshot(this.lists, this.details);
  final Map<TaskFilter, List<Task>> lists;
  final Map<TaskUid, Task> details;
}
