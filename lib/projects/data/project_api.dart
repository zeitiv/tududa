import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/api/patch.dart' show Patch, putPatch;
import '../../core/ids.dart';
import 'project_dto.dart';

/// Body for `POST /project`.
class NewProject {
  const NewProject({
    required this.name,
    this.description,
    this.status = 'not_started',
    this.priority,
    this.areaUid,
    this.pinToSidebar = false,
    this.dueDateAt,
  });

  final String name;
  final String? description;
  final String status;
  final int? priority;
  final AreaUid? areaUid;
  final bool pinToSidebar;
  final DateTime? dueDateAt;

  Map<String, Object?> toJson() => {
    'name': name,
    if (description != null) 'description': description,
    'status': status,
    if (priority != null) 'priority': priority,
    if (areaUid != null) 'area_uid': areaUid!.value,
    'pin_to_sidebar': pinToSidebar,
    if (dueDateAt != null) 'due_date_at': dueDateAt!.toUtc().toIso8601String(),
  };
}

/// Body for `PATCH /project/:uid`. Unset fields are left out of the request;
/// a cleared field is sent as `null` (e.g. `areaUid: Patch.clear()`).
class ProjectPatch {
  const ProjectPatch({
    this.name = const Patch.unset(),
    this.description = const Patch.unset(),
    this.status = const Patch.unset(),
    this.priority = const Patch.unset(),
    this.areaUid = const Patch.unset(),
    this.pinToSidebar = const Patch.unset(),
    this.taskShowCompleted = const Patch.unset(),
    this.taskSortOrder = const Patch.unset(),
    this.dueDateAt = const Patch.unset(),
  });

  final Patch<String> name;
  final Patch<String> description;
  final Patch<String> status;
  final Patch<int> priority;
  final Patch<AreaUid> areaUid;
  final Patch<bool> pinToSidebar;
  final Patch<bool> taskShowCompleted;
  final Patch<String> taskSortOrder;
  final Patch<DateTime> dueDateAt;

  Map<String, Object?> toJson() {
    final json = <String, Object?>{};
    putPatch(json, 'name', name);
    putPatch(json, 'description', description);
    putPatch(json, 'status', status);
    putPatch(json, 'priority', priority);
    putPatch(json, 'area_uid', areaUid, (a) => a.value);
    putPatch(json, 'pin_to_sidebar', pinToSidebar);
    putPatch(json, 'task_show_completed', taskShowCompleted);
    putPatch(json, 'task_sort_order', taskSortOrder);
    putPatch(
      json,
      'due_date_at',
      dueDateAt,
      (d) => d.toUtc().toIso8601String(),
    );
    return json;
  }
}

/// Thin HTTP layer over `/projects` and `/project/:uid`.
class ProjectApi {
  ProjectApi(this._dio);
  final Dio _dio;

  static String _path(ProjectUid uid) =>
      '/project/${Uri.encodeComponent(uid.value)}';

  Future<List<ProjectDto>> list() => guard(() async {
    final res = await _dio.get<Object?>('/projects');
    final data = res.data;
    final raw = data is List
        ? data
        : (data is Map ? (data['projects'] as List? ?? const []) : const []);
    return [
      for (final e in raw)
        ProjectDto.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
  });

  Future<ProjectDto> get(ProjectUid uid) => guard(() async {
    final res = await _dio.get<Object?>(_path(uid));
    return _one(res.data);
  });

  Future<ProjectDto> create(NewProject project) => guard(() async {
    final res = await _dio.post<Object?>('/project', data: project.toJson());
    return _one(res.data);
  });

  Future<ProjectDto> update(ProjectUid uid, ProjectPatch patch) =>
      guard(() async {
        final res = await _dio.patch<Object?>(_path(uid), data: patch.toJson());
        return _one(res.data);
      });

  Future<void> delete(ProjectUid uid) => guard(() async {
    await _dio.delete<Object?>(_path(uid));
  });

  static ProjectDto _one(Object? data) {
    if (data is Map) {
      final inner = data['project'];
      return ProjectDto.fromJson(
        Map<String, dynamic>.from(inner is Map ? inner : data),
      );
    }
    throw FormatException('Expected a project object', data);
  }
}
