import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/api/page.dart';
import '../../core/ids.dart';
import 'dto/task_dto.dart';
import 'dto/task_list_response.dart';
import 'task_create.dart';
import 'task_patch.dart';
import 'task_query.dart';

/// Raw Tududi task endpoints. Paths are relative to `/api`. Every call goes
/// through `guard()`, so failures surface as `ApiError`.
class TasksApi {
  TasksApi(this._dio);

  final Dio _dio;

  Future<TaskListResponse> list(TaskQuery query, {CancelToken? cancelToken}) =>
      guard(() async {
        final res = await _dio.get<Object?>(
          '/tasks',
          queryParameters: query.toQueryParameters(),
          cancelToken: cancelToken,
        );
        return TaskListResponse.fromJson(res.data);
      });

  Future<TaskDto> get(TaskUid uid, {CancelToken? cancelToken}) =>
      guard(() async {
        final res = await _dio.get<Object?>(
          '/task/${Uri.encodeComponent(uid.value)}',
          cancelToken: cancelToken,
        );
        return _one(res.data);
      });

  Future<TaskDto> create(TaskCreate task) => guard(() async {
    final res = await _dio.post<Object?>('/task', data: task.toJson());
    return _one(res.data);
  });

  Future<TaskDto> update(TaskUid uid, TaskPatch patch) => guard(() async {
    final res = await _dio.patch<Object?>(
      '/task/${Uri.encodeComponent(uid.value)}',
      data: patch.toJson(),
    );
    return _one(res.data);
  });

  Future<void> delete(TaskUid uid) => guard(() async {
    await _dio.delete<Object?>('/task/${Uri.encodeComponent(uid.value)}');
  });

  Future<List<TaskDto>> subtasks(TaskUid uid) => guard(() async {
    final res = await _dio.get<Object?>(
      '/task/${Uri.encodeComponent(uid.value)}/subtasks',
    );
    return Page.fromJson(res.data, TaskDto.parse, itemsKey: 'subtasks').items;
  });

  /// `POST /task/:uid/skip-occurrence`. Returns the updated task when the
  /// server sends one.
  Future<TaskDto?> skipOccurrence(TaskUid uid) => guard(() async {
    final res = await _dio.post<Object?>(
      '/task/${Uri.encodeComponent(uid.value)}/skip-occurrence',
    );
    final data = res.data;
    if (data is! Map) return null;
    final m = _unwrap(Map<String, dynamic>.from(data));
    return m['uid'] == null && m['id'] == null ? null : TaskDto.parse(m);
  });

  /// `GET /tasks/metrics`, as the server sends it.
  Future<Map<String, Object?>> metrics() => guard(() async {
    final res = await _dio.get<Object?>('/tasks/metrics');
    final data = res.data;
    if (data is! Map) throw FormatException('Expected an object', data);
    return Map<String, Object?>.from(data);
  });

  /// Creates a subtask: `POST /task` with `parent_task_id`.
  Future<TaskDto> createSubtask(int parentId, String name) => guard(() async {
    final res = await _dio.post<Object?>(
      '/task',
      data: {'name': name.trim(), 'parent_task_id': parentId},
    );
    return _one(res.data);
  });

  static Map<String, dynamic> _unwrap(Map<String, dynamic> m) {
    final inner = m['task'];
    return inner is Map ? Map<String, dynamic>.from(inner) : m;
  }

  static TaskDto _one(Object? data) {
    if (data is! Map) throw FormatException('Expected a task object', data);
    return TaskDto.parse(_unwrap(Map<String, dynamic>.from(data)));
  }
}
