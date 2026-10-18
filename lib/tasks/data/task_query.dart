import '../../core/ids.dart';

/// Parameters of `GET /tasks`. Null / false fields are not sent.
class TaskQuery {
  const TaskQuery({
    this.type,
    this.status,
    this.priority,
    this.tag,
    this.projectUid,
    this.areaUid,
    this.search,
    this.orderBy,
    this.includeSubtasks = false,
    this.includeLists = false,
    this.limit,
    this.offset,
  });

  /// `today`, `upcoming`, `next`, `inbox`, `someday`, `waiting` or `all`.
  final String? type;

  /// A status name or number (`completed`, `active`, `2`, ...).
  final String? status;
  final String? priority;
  final String? tag;
  final ProjectUid? projectUid;
  final AreaUid? areaUid;
  final String? search;

  /// `field:dir`, e.g. `due_date:asc`.
  final String? orderBy;
  final bool includeSubtasks;

  /// Adds the `tasks_*` extra lists (only meaningful with `type=today`).
  final bool includeLists;
  final int? limit;
  final int? offset;

  Map<String, Object> toQueryParameters() => {
    'type': ?type,
    'status': ?status,
    'priority': ?priority,
    'tag': ?tag,
    'project_uid': ?projectUid?.value,
    'area_uid': ?areaUid?.value,
    if (search != null && search!.isNotEmpty) 'search': search!,
    'order_by': ?orderBy,
    if (includeSubtasks) 'include_subtasks': 'true',
    if (includeLists) 'include_lists': 'true',
    'limit': ?limit,
    'offset': ?offset,
  };

  TaskQuery copyWith({int? limit, int? offset}) => TaskQuery(
    type: type,
    status: status,
    priority: priority,
    tag: tag,
    projectUid: projectUid,
    areaUid: areaUid,
    search: search,
    orderBy: orderBy,
    includeSubtasks: includeSubtasks,
    includeLists: includeLists,
    limit: limit ?? this.limit,
    offset: offset ?? this.offset,
  );
}
