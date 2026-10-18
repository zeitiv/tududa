import 'dart:async';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';
import '../../core/db/entity_access.dart';
import '../../core/ids.dart';
import '../../core/time/calendar_date.dart';
import '../domain/task.dart';
import '../domain/task_views.dart';
import 'task_fields.dart';

/// A stream that re-runs [load] whenever one of [tables] is written, starting
/// with an initial run. Unlike drift's own query streams it can combine
/// several queries (a task with its tags, project, subtasks...). A result
/// equal to the previous one is not emitted, so writes that do not change what
/// a screen shows do not rebuild it. Updates that
/// arrive while a load runs cause exactly one more load.
Stream<T> reactiveLoad<T>(
  AppDatabase db,
  Set<TableInfo> tables,
  Future<T> Function() load,
) {
  late StreamController<T> controller;
  StreamSubscription<Set<TableUpdate>>? sub;
  var loading = false;
  var again = false;
  var hasLast = false;
  T? last;

  Future<void> run() async {
    if (loading) {
      again = true;
      return;
    }
    loading = true;
    try {
      do {
        again = false;
        final value = await load();
        // Equal result: the tables changed but this view did not.
        final same =
            hasLast && const DeepCollectionEquality().equals(last, value);
        if (!same && !controller.isClosed) {
          hasLast = true;
          last = value;
          controller.add(value);
        }
      } while (again && !controller.isClosed);
    } catch (e, st) {
      if (!controller.isClosed) controller.addError(e, st);
    } finally {
      loading = false;
    }
  }

  controller = StreamController<T>(
    onListen: () {
      hasLast = false;
      last = null;
      sub = db
          .tableUpdates(TableUpdateQuery.onAllTables(tables))
          .listen((_) => unawaited(run()));
      unawaited(run());
    },
    onCancel: () async {
      await sub?.cancel();
      sub = null;
    },
  );
  return controller.stream;
}

/// Reads and writes task rows (and their tag links) in the offline store.
///
/// Writes here are plain row operations; the repository wraps them with the
/// dirty-field marks and the outbox entry in ONE transaction (see
/// `lib/core/sync/README.md`). Rows are inserted with `INSERT` /
/// `insertOnConflictUpdate`, never `INSERT OR REPLACE` (search triggers).
///
/// Every read hides `pending_delete` rows.
class TaskDao {
  TaskDao(this.db);

  final AppDatabase db;

  $TasksTable get _t => db.tasks;

  Set<TableInfo> get _tables => {
    db.tasks,
    db.taskTags,
    db.tags,
    db.projects,
    db.areas,
  };

  // ---- rows ----

  Future<TaskRow?> byLocalId(String localId) => (db.select(
    _t,
  )..where((t) => t.localId.equals(localId))).getSingleOrNull();

  Future<TaskRow?> byUid(String uid) =>
      (db.select(_t)..where((t) => t.uid.equals(uid))).getSingleOrNull();

  Future<TaskRow?> byServerId(int id) =>
      (db.select(_t)..where((t) => t.serverId.equals(id))).getSingleOrNull();

  /// The row whose server uid or local id is [id] (a `TaskUid` value is the
  /// uid once synced and the local id before).
  Future<TaskRow?> byAnyId(String id) async {
    final rows = await (db.select(
      _t,
    )..where((t) => t.uid.equals(id) | t.localId.equals(id))).get();
    if (rows.isEmpty) return null;
    return rows.firstWhere((r) => r.uid == id, orElse: () => rows.first);
  }

  /// Direct children (subtasks), including pending-delete ones.
  Future<List<TaskRow>> childRows(String parentLocalId) => (db.select(
    _t,
  )..where((t) => t.parentLocalId.equals(parentLocalId))).get();

  Future<List<TaskRow>> allRows() => db.select(_t).get();

  Future<void> insertRow(TasksCompanion c) => db.into(_t).insert(c);

  Future<void> upsertRow(TasksCompanion c) =>
      db.into(_t).insertOnConflictUpdate(c);

  Future<void> updateRow(String localId, TasksCompanion c) =>
      (db.update(_t)..where((t) => t.localId.equals(localId))).write(c);

  /// Removes the row, its tag links and (via the search triggers) its index
  /// entry. Subtasks are removed as well.
  Future<void> deleteRow(String localId) => db.transaction(() async {
    for (final c in await childRows(localId)) {
      await db.deleteEntityRow(SyncEntity.task, c.localId);
    }
    await db.deleteEntityRow(SyncEntity.task, localId);
  });

  // ---- tags ----

  /// Tag names of a task, sorted.
  Future<List<String>> tagNames(String taskLocalId) async => [
    for (final t in await tagRows(taskLocalId)) t.name,
  ];

  Future<List<TagRow>> tagRows(String taskLocalId) async {
    final q =
        db.select(db.taskTags).join([
            innerJoin(
              db.tags,
              db.tags.localId.equalsExp(db.taskTags.tagLocalId),
            ),
          ])
          ..where(db.taskTags.taskLocalId.equals(taskLocalId))
          ..orderBy([OrderingTerm.asc(db.tags.name)]);
    return [for (final r in await q.get()) r.readTable(db.tags)];
  }

  Future<List<String>> tagLocalIds(String taskLocalId) async => [
    for (final r in await (db.select(
      db.taskTags,
    )..where((t) => t.taskLocalId.equals(taskLocalId))).get())
      r.tagLocalId,
  ];

  /// The local tag with [uid], else the one called [name], created when
  /// missing. Tududi creates tags implicitly when a task carries tag names,
  /// so no outbox entry is made for a new tag; it gets its uid from the next
  /// task pull.
  Future<String> tagLocalIdFor(
    String name, {
    String? uid,
    String? color,
  }) async {
    if (uid != null) {
      final byUid =
          await (db.select(db.tags)..where(
                (t) => t.uid.equals(uid) & t.pendingDelete.equals(false),
              ))
              .getSingleOrNull();
      if (byUid != null) return byUid.localId;
    }
    final byName =
        await (db.select(db.tags)
              ..where(
                (t) => t.name.equals(name) & t.pendingDelete.equals(false),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.uid.isNotNull())])
              ..limit(1))
            .getSingleOrNull();
    if (byName != null) {
      if (uid != null && byName.uid == null) {
        // A tag created offline meets its server twin: adopt the uid.
        await (db.update(
          db.tags,
        )..where((t) => t.localId.equals(byName.localId))).write(
          TagsCompanion(uid: Value(uid), color: Value(color ?? byName.color)),
        );
      }
      return byName.localId;
    }
    final id = LocalId.generate().value;
    await db
        .into(db.tags)
        .insert(
          TagsCompanion.insert(
            localId: id,
            uid: Value(uid),
            name: Value(name),
            color: Value(color),
          ),
        );
    return id;
  }

  /// Replaces the tag links of a task with the tags called [names] (created
  /// when missing). Returns the linked local tag ids.
  Future<List<String>> setTagNames(
    String taskLocalId,
    Iterable<String> names,
  ) async {
    final ids = <String>[];
    for (final n in names) {
      final name = n.trim();
      if (name.isEmpty) continue;
      final id = await tagLocalIdFor(name);
      if (!ids.contains(id)) ids.add(id);
    }
    await setTagLinks(taskLocalId, ids);
    return ids;
  }

  /// Replaces the tag links of a task with exactly [tagLocalIds].
  Future<void> setTagLinks(
    String taskLocalId,
    Iterable<String> tagLocalIds,
  ) async {
    await (db.delete(
      db.taskTags,
    )..where((t) => t.taskLocalId.equals(taskLocalId))).go();
    for (final id in tagLocalIds.toSet()) {
      await db
          .into(db.taskTags)
          .insert(
            TaskTagsCompanion.insert(taskLocalId: taskLocalId, tagLocalId: id),
          );
    }
  }

  // ---- views ----

  OrderingTerm _dueFirst($TasksTable t) => OrderingTerm(
    expression: t.dueDate,
    mode: OrderingMode.asc,
    nulls: NullsOrder.last,
  );

  List<OrderingTerm Function($TasksTable)> _order(TaskView view) {
    switch (view) {
      case TaskView.completed:
      case TaskView.completedToday:
        return [(t) => OrderingTerm.desc(t.completedAt)];
      default:
        return [
          _dueFirst,
          (t) => OrderingTerm.desc(t.priority),
          (t) => OrderingTerm.desc(t.localUpdatedAt),
        ];
    }
  }

  /// The tasks of [view] right now.
  Future<List<Task>> fetchView(TaskView view, TaskDay day) async {
    final rows =
        await (db.select(_t)
              ..where((t) => taskViewWhere(t, view, day))
              ..orderBy(_order(view)))
            .get();
    return hydrate(rows);
  }

  /// The tasks of [view]; emits again whenever a task, tag, project or area
  /// changes. [today] is a date in UTC terms unless [day] carries the user's
  /// zone (use `TaskDay.fromClock`).
  Stream<List<Task>> watchView(
    TaskView view, {
    required CalendarDate today,
    TaskDay? day,
  }) {
    final d = day ?? TaskDay.utc(today);
    return reactiveLoad(db, _tables, () => fetchView(view, d));
  }

  /// One task by local id.
  Stream<Task?> watchByLocalId(String localId) =>
      reactiveLoad(db, _tables, () async => _one(await byLocalId(localId)));

  /// One task by uid or local id.
  Stream<Task?> watchByAnyId(String id) =>
      reactiveLoad(db, _tables, () async => _one(await byAnyId(id)));

  Future<Task?> taskByAnyId(String id) async => _one(await byAnyId(id));

  Future<Task?> _one(TaskRow? row) async {
    if (row == null || row.pendingDelete) return null;
    return (await hydrate([row])).single;
  }

  /// The subtasks of a task, in their order.
  Stream<List<Task>> watchSubtasks(String parentLocalId) => reactiveLoad(
    db,
    _tables,
    () async => hydrate(await _children(parentLocalId), withSubtasks: false),
  );

  Future<List<TaskRow>> _children(String parentLocalId) =>
      (db.select(_t)
            ..where(
              (t) =>
                  t.parentLocalId.equals(parentLocalId) &
                  t.pendingDelete.equals(false),
            )
            ..orderBy([
              (t) => OrderingTerm(
                expression: t.sortOrder,
                nulls: NullsOrder.first,
              ),
              (t) => OrderingTerm.asc(t.serverCreatedAt),
              (t) => OrderingTerm.asc(t.localUpdatedAt),
            ]))
          .get();

  // ---- mapping ----

  /// Builds the domain tasks for [rows], with tags, project / area uids,
  /// parent ids and (optionally) their subtasks.
  Future<List<Task>> hydrate(
    List<TaskRow> rows, {
    bool withSubtasks = true,
  }) async {
    if (rows.isEmpty) return const [];
    final ids = [for (final r in rows) r.localId];

    final tagsByTask = <String, List<TagRow>>{};
    final tagQuery =
        db.select(db.taskTags).join([
            innerJoin(
              db.tags,
              db.tags.localId.equalsExp(db.taskTags.tagLocalId),
            ),
          ])
          ..where(db.taskTags.taskLocalId.isIn(ids))
          ..orderBy([OrderingTerm.asc(db.tags.name)]);
    for (final r in await tagQuery.get()) {
      tagsByTask
          .putIfAbsent(r.readTable(db.taskTags).taskLocalId, () => [])
          .add(r.readTable(db.tags));
    }

    final projectIds = {
      for (final r in rows)
        if (r.projectLocalId != null) r.projectLocalId!,
    };
    final projects = {
      if (projectIds.isNotEmpty)
        for (final p in await (db.select(
          db.projects,
        )..where((t) => t.localId.isIn(projectIds))).get())
          p.localId: p,
    };
    final areaIds = {
      for (final r in rows)
        if (r.areaLocalId != null) r.areaLocalId!,
    };
    final areas = {
      if (areaIds.isNotEmpty)
        for (final a in await (db.select(
          db.areas,
        )..where((t) => t.localId.isIn(areaIds))).get())
          a.localId: a,
    };
    final parentIds = {
      for (final r in rows)
        if (r.parentLocalId != null) r.parentLocalId!,
    };
    final parents = {
      if (parentIds.isNotEmpty)
        for (final p in await (db.select(
          db.tasks,
        )..where((t) => t.localId.isIn(parentIds))).get())
          p.localId: p,
    };

    final subtasks = <String, List<Task>>{};
    if (withSubtasks) {
      final kids =
          await (db.select(db.tasks)
                ..where(
                  (t) =>
                      t.parentLocalId.isIn(ids) & t.pendingDelete.equals(false),
                )
                ..orderBy([
                  (t) => OrderingTerm(
                    expression: t.sortOrder,
                    nulls: NullsOrder.first,
                  ),
                  (t) => OrderingTerm.asc(t.serverCreatedAt),
                  (t) => OrderingTerm.asc(t.localUpdatedAt),
                ]))
              .get();
      final hydrated = await hydrate(kids, withSubtasks: false);
      for (final k in hydrated) {
        subtasks.putIfAbsent(k.parentLocalId!, () => []).add(k);
      }
    }

    return [
      for (final r in rows)
        taskFromRow(
          r,
          tags: tagsByTask[r.localId] ?? const [],
          project: projects[r.projectLocalId],
          area: areas[r.areaLocalId],
          parent: parents[r.parentLocalId],
          subtasks: subtasks[r.localId] ?? const [],
        ),
    ];
  }

  /// `local:<id>` stand-in used in field maps for a project / area that has
  /// no uid yet.
  static String localRef(String localId) => 'local:$localId';

  /// The uid the field maps use for the project / area row [localId], or null.
  Future<String?> refOf(String entity, String? localId) async {
    if (localId == null) return null;
    final uid = await db
        .customSelect(
          'SELECT uid FROM ${db.tableNameOf(entity)} WHERE local_id = ?',
          variables: [Variable<String>(localId)],
        )
        .get();
    if (uid.isEmpty) return null;
    return uid.first.read<String?>('uid') ?? localRef(localId);
  }

  /// The tracked fields of [row] as the merge map (see `taskFieldMap`).
  Future<Map<String, dynamic>> fieldMapOf(TaskRow row) async => taskFieldMap(
    row,
    projectUid: await refOf(SyncEntity.project, row.projectLocalId),
    areaUid: await refOf(SyncEntity.area, row.areaLocalId),
    tags: await tagNames(row.localId),
  );
}

/// A row as the app shows it. `uid` carries the local id until the server
/// has assigned one.
Task taskFromRow(
  TaskRow r, {
  List<TagRow> tags = const [],
  ProjectRow? project,
  AreaRow? area,
  TaskRow? parent,
  List<Task> subtasks = const [],
}) {
  final dirty = r.dirtyFields != '{}' && r.dirtyFields.isNotEmpty;
  return Task(
    uid: TaskUid(r.uid ?? r.localId),
    serverId: r.serverId,
    name: r.name,
    note: r.note,
    status: TaskStatus.fromCode(r.status),
    priority: Priority.fromCode(r.priority),
    dueDate: CalendarDate.tryParse(r.dueDate),
    dueTime: LocalTime.tryParse(r.dueTime),
    deferUntil: r.deferUntil,
    reminderAt: r.reminderAt,
    completedAt: r.completedAt,
    estimatedMinutes: r.estimatedMinutes,
    projectUid: project == null
        ? null
        : ProjectUid(project.uid ?? project.localId),
    projectName: project?.name,
    areaUid: area == null ? null : AreaUid(area.uid ?? area.localId),
    parentTaskId: parent?.serverId,
    recurringParentUid: r.recurringParentUid == null
        ? null
        : TaskUid(r.recurringParentUid!),
    order: r.sortOrder,
    recurrenceType: r.recurrenceType ?? 'none',
    recurrenceInterval: r.recurrenceInterval,
    recurrenceEndDate: CalendarDate.tryParse(r.recurrenceEndDate),
    recurrenceWeekday: r.recurrenceWeekday,
    recurrenceWeekdays: decodeIntList(r.recurrenceWeekdays),
    recurrenceMonthDay: r.recurrenceMonthDay,
    recurrenceWeekOfMonth: r.recurrenceWeekOfMonth,
    completionBased: r.completionBased,
    todayMoveCount: r.todayMoveCount,
    isBlocked: r.isBlocked,
    tags: [
      for (final t in tags)
        TaskTag(
          uid: t.uid == null ? null : TagUid(t.uid!),
          name: t.name,
          color: t.color,
        ),
    ],
    subtasks: subtasks,
    createdAt: r.serverCreatedAt ?? r.localUpdatedAt,
    updatedAt: r.serverUpdatedAt ?? r.localUpdatedAt,
    localId: r.localId,
    parentLocalId: r.parentLocalId,
    hasPendingSync: dirty || r.uid == null,
  );
}
