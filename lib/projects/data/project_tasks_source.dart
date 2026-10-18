import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/db/app_database.dart';
import '../../core/db/dirty_fields.dart';
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

  factory ProjectTaskRef.fromRow(TaskRow t) => ProjectTaskRef(
    id: t.serverId,
    uid: TaskUid(t.uid ?? t.localId),
    name: t.name,
    status: t.status,
    priority: t.priority,
    dueDate: t.dueDate == null ? null : DateTime.tryParse(t.dueDate!),
    order: t.sortOrder,
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

/// Where the project screen gets its tasks.
abstract class ProjectTasksSource {
  Future<List<ProjectTaskRef>> tasksFor(ProjectUid project);

  /// Live version of [tasksFor].
  Stream<List<ProjectTaskRef>> watchTasksFor(ProjectUid project);

  Future<void> setStatus(TaskUid task, int status);
}

/// Reads a project's tasks straight from the `tasks` table and writes status
/// changes as a task row update + dirty mark + outbox `update` in one
/// transaction (the tasks lane's handler sends it). Projects and tasks are
/// addressed by uid, or by local id while they have none yet.
class DbProjectTasksSource implements ProjectTasksSource {
  DbProjectTasksSource(this._db, {DateTime Function()? now})
    : _now = now ?? (() => DateTime.now().toUtc());

  final AppDatabase _db;
  final DateTime Function() _now;

  JoinedSelectStatement _query(ProjectUid project) {
    final p = _db.projects;
    final t = _db.tasks;
    return (_db.select(t)..where((t) => t.pendingDelete.equals(false))).join([
        innerJoin(p, p.localId.equalsExp(t.projectLocalId)),
      ])
      ..where(p.uid.equals(project.value) | p.localId.equals(project.value))
      ..orderBy([OrderingTerm.asc(t.sortOrder), OrderingTerm.asc(t.name)]);
  }

  @override
  Future<List<ProjectTaskRef>> tasksFor(ProjectUid project) async => [
    for (final r in await _query(project).get())
      ProjectTaskRef.fromRow(r.readTable(_db.tasks)),
  ];

  @override
  Stream<List<ProjectTaskRef>> watchTasksFor(ProjectUid project) =>
      _query(project).watch().map(
        (rs) => [
          for (final r in rs) ProjectTaskRef.fromRow(r.readTable(_db.tasks)),
        ],
      );

  @override
  Future<void> setStatus(TaskUid task, int status) {
    final now = _now();
    return _db.transaction(() async {
      final t = _db.tasks;
      final row =
          await (_db.select(t)..where(
                (x) =>
                    x.pendingDelete.equals(false) &
                    (x.uid.equals(task.value) | x.localId.equals(task.value)),
              ))
              .getSingleOrNull();
      if (row == null) throw const NotFoundError('Task not found');
      if (row.status == status) return;
      final done = status == 2;
      final dirty = DirtyFields.decode(row.dirtyFields)
          .mark('status', now.millisecondsSinceEpoch);
      await (_db.update(t)..where((x) => x.localId.equals(row.localId))).write(
        TasksCompanion(
          status: Value(status),
          completedAt: Value(done ? now : null),
          statusBeforeDone: done && row.status != 2
              ? Value(row.status)
              : const Value.absent(),
          dirtyFields: Value(dirty.encode()),
          localUpdatedAt: Value(now),
        ),
      );
      await _db.outboxDao.enqueue(
        entity: SyncEntity.task,
        localId: row.localId,
        op: OutboxOp.update,
        now: now,
      );
    });
  }
}

final projectTasksSourceProvider = Provider<ProjectTasksSource>(
  (ref) => DbProjectTasksSource(ref.watch(appDatabaseProvider)),
);
