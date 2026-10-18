import '../../core/api/page.dart';
import '../../core/ids.dart';
import '../../core/time/calendar_date.dart';
import '../domain/new_task.dart';
import '../domain/task.dart';
import 'task_patch.dart';
import 'task_query.dart';

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
}
