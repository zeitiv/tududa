import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_providers.dart';
import '../../core/api/page.dart';
import '../../core/ids.dart';
import '../../core/time/calendar_date.dart';
import '../domain/new_task.dart';
import '../domain/task.dart';
import '../domain/task_mapper.dart';
import 'task_create.dart';
import 'task_patch.dart';
import 'task_query.dart';
import 'task_repository.dart';
import 'tasks_api.dart';

/// [TaskRepository] over the Tududi HTTP API.
class RemoteTaskRepository implements TaskRepository {
  RemoteTaskRepository(this._api);

  final TasksApi _api;

  @override
  Future<Page<Task>> fetch(TaskQuery query) async {
    final res = await _api.list(query);
    final p = res.page;
    return Page(
      items: [for (final d in p.items) taskFromDto(d)],
      total: p.total,
      limit: p.limit,
      offset: p.offset,
      hasMore: p.hasMore,
    );
  }

  @override
  Future<Task> get(TaskUid uid) async => taskFromDto(await _api.get(uid));

  @override
  Future<Task> create(NewTask task) async =>
      taskFromDto(await _api.create(TaskCreate(task)));

  @override
  Future<Task> update(TaskUid uid, TaskPatch patch) async =>
      taskFromDto(await _api.update(uid, patch));

  @override
  Future<Task> complete(TaskUid uid) =>
      update(uid, TaskPatch.withStatus(TaskStatus.done));

  @override
  Future<Task> uncomplete(
    TaskUid uid, {
    TaskStatus restoreTo = TaskStatus.notStarted,
  }) {
    // Never "reopen" into a finished state.
    final target = restoreTo.isFinished || restoreTo == TaskStatus.unknown
        ? TaskStatus.notStarted
        : restoreTo;
    return update(uid, TaskPatch.withStatus(target));
  }

  @override
  Future<void> delete(TaskUid uid) => _api.delete(uid);

  @override
  Future<Task> postpone(TaskUid uid, CalendarDate to, {LocalTime? keepTime}) =>
      update(uid, TaskPatch.moveTo(to, time: keepTime));

  @override
  Future<Task?> skipOccurrence(TaskUid uid) async {
    final d = await _api.skipOccurrence(uid);
    return d == null ? null : taskFromDto(d);
  }

  @override
  Future<Task> createSubtask({
    required int parentId,
    required String name,
  }) async => taskFromDto(await _api.createSubtask(parentId, name));

  @override
  Future<List<Task>> subtasks(TaskUid uid) async => [
    for (final d in await _api.subtasks(uid)) taskFromDto(d),
  ];
}

final tasksApiProvider = Provider<TasksApi>(
  (ref) => TasksApi(ref.watch(dioProvider)),
);

/// The repository the app uses. Override in tests or when the offline
/// repository replaces the remote one.
final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => RemoteTaskRepository(ref.watch(tasksApiProvider)),
);
