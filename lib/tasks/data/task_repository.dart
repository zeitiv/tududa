import '../../core/api/api_error.dart';
import '../../core/api/page.dart';
import '../../core/ids.dart';
import '../../core/time/calendar_date.dart';
import '../domain/new_task.dart';
import '../domain/task.dart';
import 'task_patch.dart';
import 'task_query.dart';
import 'undo_token.dart';

/// What the app needs from task storage. The remote implementation talks to
/// Tududi; the offline milestone adds a database-backed one behind the same
/// interface. Failures are thrown as `ApiError`.
abstract class TaskRepository {
  Future<Page<Task>> fetch(TaskQuery query);

  Future<Task> get(TaskUid uid);

  Future<Task> create(NewTask task);

  Future<Task> update(TaskUid uid, TaskPatch patch);

  /// Sets the status to done.
  Future<Task> complete(TaskUid uid);

  /// Reopens a task, setting its status to [restoreTo].
  Future<Task> uncomplete(
    TaskUid uid, {
    TaskStatus restoreTo = TaskStatus.notStarted,
  });

  Future<void> delete(TaskUid uid);

  /// Moves the due date to [to]. Tududi drops the due time when only the date
  /// is sent, so pass [keepTime] to preserve it.
  Future<Task> postpone(TaskUid uid, CalendarDate to, {LocalTime? keepTime});

  /// Skips the current occurrence of a recurring task. Null when the server
  /// did not return the updated task.
  Future<Task?> skipOccurrence(TaskUid uid);

  /// Creates a subtask under the task whose numeric id is [parentId].
  Future<Task> createSubtask({required int parentId, required String name});

  Future<List<Task>> subtasks(TaskUid uid);

  // ---- additive API (offline milestone) ----
  //
  // The `...Tracked` variants do what the plain method does and also return
  // an [UndoToken]. The defaults wrap the plain methods without a token, so
  // remote implementations keep working.

  Future<Change<Task>> updateTracked(TaskUid uid, TaskPatch patch) async =>
      Change(await update(uid, patch));

  Future<Change<Task>> completeTracked(TaskUid uid) async =>
      Change(await complete(uid));

  Future<Change<Task>> uncompleteTracked(
    TaskUid uid, {
    TaskStatus restoreTo = TaskStatus.notStarted,
  }) async => Change(await uncomplete(uid, restoreTo: restoreTo));

  Future<Change<void>> deleteTracked(TaskUid uid) async {
    await delete(uid);
    return const Change(null);
  }

  Future<Change<Task>> postponeTracked(
    TaskUid uid,
    CalendarDate to, {
    LocalTime? keepTime,
  }) async => Change(await postpone(uid, to, keepTime: keepTime));

  Future<Change<Task?>> skipOccurrenceTracked(TaskUid uid) async =>
      Change(await skipOccurrence(uid));

  /// Applies [patch] to every task in [uids] as one change (one token).
  Future<Change<List<Task>>> bulk(List<TaskUid> uids, TaskPatch patch) async =>
      Change([for (final u in uids) await update(u, patch)]);

  /// Creates a subtask under [parent], which may not be on the server yet.
  Future<Task> createSubtaskOf(TaskUid parent, String name) async {
    final id = (await get(parent)).serverId;
    if (id == null) {
      throw const ValidationError('The parent task has no id yet');
    }
    return createSubtask(parentId: id, name: name);
  }

  /// Reverts the change behind [token]. Returns false when nothing could be
  /// reverted (already used, or not undoable).
  Future<bool> undo(UndoToken token) async => false;
}
