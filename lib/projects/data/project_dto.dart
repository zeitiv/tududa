import 'package:freezed_annotation/freezed_annotation.dart';

part 'project_dto.freezed.dart';
part 'project_dto.g.dart';

const _statusNames = <int, String>{
  0: 'not_started',
  1: 'in_progress',
  2: 'done',
  3: 'waiting',
  4: 'cancelled',
  5: 'planned',
};

const _priorityNames = <String, int>{'low': 0, 'medium': 1, 'high': 2};

int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');

/// Wire shape of a Tududi project. [ProjectDto.fromJson] first folds the
/// server's alternative spellings into the canonical keys below:
/// `task_status{total,done}` and `taskCount`/`completedTaskCount` become
/// `task_count`/`completed_task_count`; `Area{uid,name}` becomes `area_uid`/
/// `area_name`; numeric statuses become names; textual priorities become ints.
@freezed
abstract class ProjectDto with _$ProjectDto {
  const factory ProjectDto({
    int? id,
    required String uid,
    @Default('') String name,
    String? description,
    @Default('not_started') String status,
    int? priority,
    @JsonKey(name: 'due_date_at') String? dueDateAt,
    @JsonKey(name: 'area_uid') String? areaUid,
    @JsonKey(name: 'area_name') String? areaName,
    @JsonKey(name: 'pin_to_sidebar') @Default(false) bool pinToSidebar,
    @JsonKey(name: 'task_show_completed')
    @Default(false)
    bool taskShowCompleted,
    @JsonKey(name: 'task_sort_order')
    @Default('created_at:desc')
    String taskSortOrder,
    @JsonKey(name: 'image_url') String? imageUrl,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'updated_at') String? updatedAt,
    @JsonKey(name: 'task_count') int? taskCount,
    @JsonKey(name: 'completed_task_count') int? completedTaskCount,
  }) = _ProjectDto;

  factory ProjectDto.fromJson(Map<String, dynamic> json) =>
      _$ProjectDtoFromJson(_normalize(json));

  static Map<String, dynamic> _normalize(Map<String, dynamic> json) {
    final area = json['Area'] ?? json['area'];
    final areaMap = area is Map ? area : null;
    final ts = json['task_status'];
    final tsMap = ts is Map ? ts : null;

    final status = json['status'];
    final priority = json['priority'];
    final bool? pin = json['pin_to_sidebar'] as bool?;
    return {
      ...json,
      'uid': json['uid'] ?? '${json['id']}',
      'status': status is int
          ? (_statusNames[status] ?? 'not_started')
          : (status as String?) ?? 'not_started',
      'priority': priority is String
          ? _priorityNames[priority.toLowerCase()]
          : _int(priority),
      'area_uid': json['area_uid'] ?? areaMap?['uid'],
      'area_name': areaMap?['name'] ?? json['area_name'],
      'pin_to_sidebar': pin ?? false,
      'created_at': json['created_at'] ?? json['createdAt'],
      'updated_at': json['updated_at'] ?? json['updatedAt'],
      'task_count': _int(
        tsMap?['total'] ?? json['task_count'] ?? json['taskCount'],
      ),
      'completed_task_count': _int(
        tsMap?['done'] ??
            json['completed_task_count'] ??
            json['completedTaskCount'],
      ),
    };
  }
}
