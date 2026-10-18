import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/ids.dart';
import '../data/project_dto.dart';

part 'project_model.freezed.dart';

/// Domain project, identified by [uid] (slug-safe; never use [id] for routes).
@freezed
abstract class Project with _$Project {
  const Project._();

  const factory Project({
    required ProjectUid uid,
    int? id,
    required String name,
    String? description,
    @Default('not_started') String status,

    /// 0 low, 1 medium, 2 high; null when unset.
    int? priority,
    DateTime? dueDateAt,
    AreaUid? areaUid,
    String? areaName,
    @Default(false) bool pinToSidebar,
    @Default(false) bool taskShowCompleted,
    @Default('created_at:desc') String taskSortOrder,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? taskCount,
    int? completedTaskCount,

    /// Local primary key (offline store). [uid] holds this value until the
    /// server has assigned a real uid.
    String? localId,
  }) = _Project;

  factory Project.fromDto(ProjectDto d) => Project(
    uid: ProjectUid(d.uid),
    id: d.id,
    name: d.name,
    description: d.description,
    status: d.status,
    priority: d.priority,
    dueDateAt: d.dueDateAt == null ? null : DateTime.tryParse(d.dueDateAt!),
    areaUid: d.areaUid == null ? null : AreaUid(d.areaUid!),
    areaName: d.areaName,
    pinToSidebar: d.pinToSidebar,
    taskShowCompleted: d.taskShowCompleted,
    taskSortOrder: d.taskSortOrder,
    imageUrl: d.imageUrl,
    createdAt: d.createdAt == null ? null : DateTime.tryParse(d.createdAt!),
    updatedAt: d.updatedAt == null ? null : DateTime.tryParse(d.updatedAt!),
    taskCount: d.taskCount,
    completedTaskCount: d.completedTaskCount,
  );

  /// Fraction of tasks done, 0 when there are none.
  double get progress {
    final total = taskCount;
    if (total == null || total == 0) return 0;
    return ((completedTaskCount ?? 0) / total).clamp(0.0, 1.0);
  }

  /// `low` / `medium` / `high`, or null (used for colouring).
  String? get priorityName => projectPriorityName(priority);

  String get statusDisplay {
    switch (status) {
      case 'not_started':
        return 'Not Started';
      case 'in_progress':
        return 'In Progress';
      case 'done':
        return 'Done';
      case 'waiting':
        return 'Waiting';
      case 'cancelled':
        return 'Cancelled';
      case 'planned':
        return 'Planned';
      default:
        return status;
    }
  }
}

String? projectPriorityName(int? priority) => switch (priority) {
  0 => 'low',
  1 => 'medium',
  2 => 'high',
  _ => null,
};

int? projectPriorityFromName(String? name) => switch (name) {
  'low' => 0,
  'medium' => 1,
  'high' => 2,
  _ => null,
};
