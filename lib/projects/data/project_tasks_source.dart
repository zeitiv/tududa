import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_providers.dart';
import '../../core/ids.dart';

const _statusByName = <String, int>{
  'not_started': 0,
  'in_progress': 1,
  'done': 2,
  'archived': 3,
  'waiting': 4,
  'cancelled': 5,
  'planned': 6,
};
const _priorityByName = <String, int>{'low': 0, 'medium': 1, 'high': 2};

/// Minimal task view for the project board (id, uid, name, status, priority,
/// due date). Status ints follow Tududi: 0 todo, 1 in progress, 2 done,
/// 3 archived, 4 waiting, 5 cancelled, 6 planned.
class ProjectTaskRef {
  const ProjectTaskRef({
    this.id,
    required this.uid,
    required this.name,
    this.status = 0,
    this.priority = 0,
    this.dueDate,
    this.order,
  });

  final int? id;
  final TaskUid uid;
  final String name;
  final int status;
  final int priority;
  final DateTime? dueDate;
  final int? order;

  bool get isCompleted => status == 2 || status == 3;

  ProjectTaskRef copyWith({int? status}) => ProjectTaskRef(
    id: id,
    uid: uid,
    name: name,
    status: status ?? this.status,
    priority: priority,
    dueDate: dueDate,
    order: order,
  );

  factory ProjectTaskRef.fromJson(Map<String, dynamic> json) {
    final status = json['status'];
    final priority = json['priority'];
    final due = json['due_date'];
    final order = json['order'];
    return ProjectTaskRef(
      id: (json['id'] as num?)?.toInt(),
      uid: TaskUid((json['uid'] ?? json['id']).toString()),
      name: json['name'] as String? ?? '',
      status: status is num
          ? status.toInt()
          : _statusByName['$status'] ?? int.tryParse('$status') ?? 0,
      priority: priority is num
          ? priority.toInt()
          : _priorityByName['$priority'] ?? 0,
      dueDate: due == null ? null : DateTime.tryParse('$due'),
      order: order is num ? order.toInt() : null,
    );
  }
}

/// Where the project screen gets its tasks. T2.Z swaps the default
/// implementation for the tasks repository.
abstract class ProjectTasksSource {
  Future<List<ProjectTaskRef>> tasksFor(ProjectUid project);
  Future<void> setStatus(TaskUid task, int status);
}

/// `GET /tasks?project_uid=<uid>&status=all` and `PATCH /task/:uid {status}`.
class DioProjectTasksSource implements ProjectTasksSource {
  DioProjectTasksSource(this._dio);
  final Dio _dio;

  @override
  Future<List<ProjectTaskRef>> tasksFor(ProjectUid project) => guard(() async {
    final res = await _dio.get<Object?>(
      '/tasks',
      queryParameters: {'project_uid': project.value, 'status': 'all'},
    );
    final data = res.data;
    final raw = data is List
        ? data
        : (data is Map ? (data['tasks'] as List? ?? const []) : const []);
    return [
      for (final e in raw)
        ProjectTaskRef.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
  });

  @override
  Future<void> setStatus(TaskUid task, int status) => guard(() async {
    await _dio.patch<Object?>(
      '/task/${Uri.encodeComponent(task.value)}',
      data: {'status': status},
    );
  });
}

final projectTasksSourceProvider = Provider<ProjectTasksSource>(
  (ref) => DioProjectTasksSource(ref.watch(dioProvider)),
);
