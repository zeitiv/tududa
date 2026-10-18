import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/api/page.dart';
import '../../core/db/app_database.dart';
import '../../core/db/dirty_fields.dart';
import '../../core/db/entity_access.dart';
import '../../core/ids.dart';
import '../../core/sync/merge.dart';
import '../../core/sync/pull_paged.dart';
import '../../core/sync/sync_handler.dart';
import '../domain/task.dart' show TaskStatus;
import 'dto/task_dto.dart';
import 'task_dao.dart';
import 'task_fields.dart';
import 'task_query.dart';
import 'tasks_api.dart';

/// Teaches `SyncEngine` about tasks: pulls them into the local store, merges
/// them with local edits per field, and sends queued changes.
///
/// Register it in `syncHandlersProvider` (see [taskSyncHandlerProvider]).
class TaskSyncHandler implements SyncHandler {
  TaskSyncHandler({
    this.pageSize = 100,
    this.keepCompleted = const Duration(days: 30),
  });

  /// Page size of the task lists (the server caps it at 100 in practice).
  final int pageSize;

  /// Completed tasks older than this are not stored (and are pruned by the
  /// full reconcile); they can be paged in on demand.
  final Duration keepCompleted;

  @override
  String get entity => SyncEntity.task;

  // ---- pull ----

  /// `GET /tasks?type=all&status=all&order_by=updated_at:desc&limit=100
  /// &include_subtasks=true`: `type=all` + `status=all` means no status
  /// filter on the server (query-builders.js), so done tasks come along and
  /// `include_subtasks` lifts the "top level only" restriction.
  TaskQuery _query(int offset) => TaskQuery(
    type: 'all',
    status: 'all',
    orderBy: 'updated_at:desc',
    includeSubtasks: true,
    limit: pageSize,
    offset: offset,
  );

  @override
  Future<void> pull(SyncContext ctx) async {
    final api = TasksApi(ctx.dio);
    await pullPaged<TaskDto>(
      fetch: (offset) async => (await api.list(_query(offset))).page,
      updatedAt: (d) => d.updatedAt,
      cursor: ctx.pullCursor,
      onPage: (items) => _applyAll(ctx, items),
    );
  }

  @override
  Future<void> fullReconcile(SyncContext ctx) async {
    final api = TasksApi(ctx.dio);
    final seen = <String>{};
    await for (final Page<TaskDto> page in pageThrough<TaskDto>(
      (offset) async => (await api.list(_query(offset))).page,
    )) {
      for (final (dto, _) in _flatten(page.items)) {
        if (dto.uid != null) seen.add(dto.uid!);
      }
      await _applyAll(ctx, page.items);
    }
    await ctx.db.removeCleanMissing(entity, seen);
    await _pruneOldCompleted(ctx);
  }

  Future<void> _pruneOldCompleted(SyncContext ctx) async {
    final dao = TaskDao(ctx.db);
    final cutoff = ctx.now.subtract(keepCompleted);
    final old =
        await (ctx.db.select(ctx.db.tasks)..where(
              (t) =>
                  t.status.isIn([2, 3]) &
                  t.uid.isNotNull() &
                  t.pendingDelete.equals(false) &
                  t.dirtyFields.equals('{}') &
                  t.completedAt.isSmallerThanValue(cutoff) &
                  CustomExpression<bool>(
                    "NOT EXISTS (SELECT 1 FROM outbox o WHERE o.entity = 'task' "
                    'AND o.local_id = tasks.local_id)',
                  ),
            ))
            .get();
    for (final row in old) {
      await dao.deleteRow(row.localId);
    }
  }

  /// Top-level tasks first, then subtasks (nested or listed on their own),
  /// each with the server id of its parent.
  static List<(TaskDto, int?)> _flatten(List<TaskDto> items) {
    final top = <(TaskDto, int?)>[];
    final children = <(TaskDto, int?)>[];
    void visit(TaskDto d, int? parentId) {
      final pid = d.parentTaskId ?? parentId;
      (pid == null ? top : children).add((d, pid));
      for (final s in d.subtasks) {
        visit(s, d.id);
      }
    }

    for (final d in items) {
      visit(d, null);
    }
    return [...top, ...children];
  }

  Future<void> _applyAll(SyncContext ctx, List<TaskDto> items) =>
      ctx.db.transaction(() async {
        for (final (dto, parentId) in _flatten(items)) {
          await _apply(ctx, dto, parentServerId: parentId);
        }
      });

  /// Merges one server task into the store. Returns the local id, or null if
  /// the task was skipped.
  Future<String?> _apply(
    SyncContext ctx,
    TaskDto d, {
    int? parentServerId,
  }) async {
    final uid = d.uid;
    if (uid == null || uid.isEmpty) return null;
    final db = ctx.db;
    final dao = TaskDao(db);
    final existing = await dao.byUid(uid);
    final snapshot = taskFieldMapFromDto(d);
    final base = BaseJson.encode(snapshot);
    final serverUpdated = d.updatedAt?.toUtc() ?? ctx.serverNow;

    String? parentLocal;
    if (parentServerId != null) {
      parentLocal = await ctx.ids.localIdOfServerId(
        SyncEntity.task,
        parentServerId,
      );
      if (parentLocal == null) return null; // orphan: wait for its parent
    }

    final status = TaskStatus.fromCode(d.status);
    if (existing == null) {
      final at = d.completedAt ?? d.updatedAt;
      if (status.isFinished &&
          at != null &&
          at.isBefore(ctx.now.subtract(keepCompleted))) {
        return null;
      }
    }

    // References arrive as uids; unknown ones become stub rows.
    final projectLocal = await _localRef(
      ctx,
      SyncEntity.project,
      snapshot[TaskField.projectUid] as String?,
      name: d.projectName,
    );
    final areaLocal = await _localRef(
      ctx,
      SyncEntity.area,
      snapshot[TaskField.areaUid] as String?,
    );

    Map<String, dynamic> merged = snapshot;
    DirtyFields dirty = const DirtyFields();
    String? localId = existing?.localId;

    if (existing != null) {
      final current = DirtyFields.decode(existing.dirtyFields);
      final resolution = resolveRow(
        pendingDelete: existing.pendingDelete,
        serverDeleted: false,
        hasDirtyFields: current.isNotEmpty,
      );
      if (resolution == RowResolution.keepPendingDelete) {
        await dao.updateRow(
          existing.localId,
          TasksCompanion(
            serverUpdatedAt: Value(serverUpdated),
            baseJson: Value(base),
          ),
        );
        return existing.localId;
      }
      if (current.isEmpty) {
        final same =
            existing.serverUpdatedAt != null &&
            existing.baseJson == base &&
            isoSeconds(existing.serverUpdatedAt) == isoSeconds(serverUpdated);
        if (same) return existing.localId; // nothing changed
      } else {
        final result = mergeFields(
          BaseJson.decode(existing.baseJson),
          await dao.fieldMapOf(existing),
          snapshot,
          current.toMap(),
          entity: entity,
          localId: existing.localId,
          serverUpdatedAt: serverUpdated,
          skew: ctx.skew,
        );
        result.notices.forEach(ctx.notice);
        merged = result.value;
        dirty = DirtyFields(result.dirtyFields);
      }
    }

    // The merged references may still be the local choice.
    final mergedProject = merged[TaskField.projectUid] as String?;
    final mergedArea = merged[TaskField.areaUid] as String?;
    final projectId = mergedProject == snapshot[TaskField.projectUid]
        ? projectLocal
        : await _localRef(ctx, SyncEntity.project, mergedProject);
    final areaId = mergedArea == snapshot[TaskField.areaUid]
        ? areaLocal
        : await _localRef(ctx, SyncEntity.area, mergedArea);

    // statusBeforeDone follows server-side completions.
    int? statusBeforeDone = existing?.statusBeforeDone;
    final mergedStatus = TaskStatus.fromCode(merged[TaskField.status] as int?);
    if (!mergedStatus.isFinished) {
      statusBeforeDone = null;
    } else if (existing != null &&
        !TaskStatus.fromCode(existing.status).isFinished) {
      statusBeforeDone = existing.status;
    }

    final fields = companionFromFieldMap(
      merged,
      projectLocalId: projectId,
      areaLocalId: areaId,
    );
    final server = TasksCompanion(
      uid: Value(uid),
      serverId: Value(d.id),
      serverCreatedAt: Value(d.createdAt?.toUtc()),
      serverUpdatedAt: Value(serverUpdated),
      baseJson: Value(base),
      dirtyFields: Value(dirty.encode()),
      originalName: Value(d.originalName ?? d.name),
      recurringParentUid: Value(d.recurringParentUid),
      sortOrder: Value(d.order),
      todayMoveCount: Value(d.todayMoveCount ?? 0),
      isBlocked: Value(d.isBlocked ?? false),
      statusBeforeDone: Value(statusBeforeDone),
      parentLocalId: parentLocal != null
          ? Value(parentLocal)
          : const Value.absent(),
    );

    if (existing == null) {
      localId = LocalId.generate().value;
      await dao.insertRow(
        fields
            .copyWith(localId: Value(localId), localUpdatedAt: Value(ctx.now))
            .copyWith(
              uid: server.uid,
              serverId: server.serverId,
              serverCreatedAt: server.serverCreatedAt,
              serverUpdatedAt: server.serverUpdatedAt,
              baseJson: server.baseJson,
              dirtyFields: server.dirtyFields,
              originalName: server.originalName,
              recurringParentUid: server.recurringParentUid,
              sortOrder: server.sortOrder,
              todayMoveCount: server.todayMoveCount,
              isBlocked: server.isBlocked,
              statusBeforeDone: server.statusBeforeDone,
              parentLocalId: server.parentLocalId,
            ),
      );
    } else {
      await dao.updateRow(
        existing.localId,
        fields.copyWith(
          uid: server.uid,
          serverId: server.serverId,
          serverCreatedAt: server.serverCreatedAt,
          serverUpdatedAt: server.serverUpdatedAt,
          baseJson: server.baseJson,
          dirtyFields: server.dirtyFields,
          originalName: server.originalName,
          recurringParentUid: server.recurringParentUid,
          sortOrder: server.sortOrder,
          todayMoveCount: server.todayMoveCount,
          isBlocked: server.isBlocked,
          statusBeforeDone: server.statusBeforeDone,
          parentLocalId: server.parentLocalId,
        ),
      );
    }

    // Tags: names are the identity; uids and colours are adopted.
    final byName = {for (final t in d.tags) t.name: t};
    final names = [
      for (final n in (merged[TaskField.tags] as List? ?? const []))
        n as String,
    ];
    final ids = <String>[];
    for (final n in names) {
      final t = byName[n];
      final id = await dao.tagLocalIdFor(n, uid: t?.uid, color: t?.color);
      if (!ids.contains(id)) ids.add(id);
    }
    final have = (await dao.tagLocalIds(localId!)).toSet();
    if (have.length != ids.length || !have.containsAll(ids)) {
      await dao.setTagLinks(localId, ids);
    }
    return localId;
  }

  /// Local id of the project / area behind a field-map reference: `local:<id>`
  /// (made offline), a uid (stub row created when unknown), or null.
  Future<String?> _localRef(
    SyncContext ctx,
    String entity,
    String? ref, {
    String? name,
  }) async {
    if (ref == null) return null;
    if (ref.startsWith('local:')) return ref.substring('local:'.length);
    final existing = await ctx.ids.localIdOfUid(entity, ref);
    if (existing != null) {
      if (entity == SyncEntity.project && name != null && name.isNotEmpty) {
        await (ctx.db.update(ctx.db.projects)
              ..where((t) => t.localId.equals(existing) & t.name.equals('')))
            .write(ProjectsCompanion(name: Value(name)));
      }
      return existing;
    }
    final id = LocalId.generate().value;
    if (entity == SyncEntity.project) {
      await ctx.db
          .into(ctx.db.projects)
          .insert(
            ProjectsCompanion.insert(
              localId: id,
              uid: Value(ref),
              name: Value(name ?? ''),
            ),
          );
    } else {
      await ctx.db
          .into(ctx.db.areas)
          .insert(AreasCompanion.insert(localId: id, uid: Value(ref)));
    }
    return id;
  }

  // ---- push ----

  @override
  Future<PushResult> push(SyncContext ctx, OutboxEntry e) async {
    final dao = TaskDao(ctx.db);
    final api = TasksApi(ctx.dio);
    final row = await dao.byLocalId(e.localId);

    switch (e.op) {
      case OutboxOp.delete:
        if (row == null) return PushResult.dropped;
        final uid = row.uid;
        if (uid != null) {
          try {
            await api.delete(TaskUid(uid));
          } on NotFoundError {
            // Already gone: the goal is reached.
          }
        }
        await dao.deleteRow(row.localId);
        return uid == null ? PushResult.dropped : PushResult.ok;

      case OutboxOp.create:
        if (row == null || row.pendingDelete) return PushResult.dropped;
        if (row.uid != null) return _pushUpdate(ctx, api, dao, row);
        final dirty = DirtyFields.decode(row.dirtyFields);
        final body = await _createBody(ctx, dao, row);
        final dto = await api.createJson(body);
        await _afterPush(ctx, dao, row.localId, dto, dirty.toMap());
        return PushResult.ok;

      case OutboxOp.update:
        if (row == null || row.pendingDelete) return PushResult.dropped;
        return _pushUpdate(ctx, api, dao, row);

      case OutboxOp.complete:
        if (row == null || row.pendingDelete) return PushResult.dropped;
        return _pushUpdate(ctx, api, dao, row, only: {TaskField.status});

      case OutboxOp.skipOccurrence:
        if (row == null || row.pendingDelete) return PushResult.dropped;
        final uid = row.uid;
        if (uid == null) return PushResult.waitForDependency;
        final dto = await api.skipOccurrence(TaskUid(uid));
        if (dto != null) {
          await ctx.db.transaction(() => _apply(ctx, dto));
        }
        return PushResult.ok;

      default:
        return PushResult.dropped;
    }
  }

  /// PATCH with the dirty fields (all of them, or those in [only]).
  Future<PushResult> _pushUpdate(
    SyncContext ctx,
    TasksApi api,
    TaskDao dao,
    TaskRow row, {
    Set<String>? only,
  }) async {
    final uid = row.uid;
    if (uid == null) return PushResult.waitForDependency;
    final dirty = DirtyFields.decode(row.dirtyFields);
    final fields = {
      for (final f in dirty.fields)
        if (!TaskField.readOnly.contains(f) &&
            (only == null || only.contains(f)))
          f,
    };
    // A completion also settles the server-set completed_at.
    final sent = {
      for (final f in dirty.fields)
        if (fields.contains(f) ||
            (only != null &&
                only.contains(TaskField.status) &&
                f == TaskField.completedAt &&
                fields.contains(TaskField.status)))
          f: dirty.editedAt(f)!,
    };
    if (fields.isEmpty) {
      // Nothing to send; forget stale read-only marks.
      if (only == null && dirty.isNotEmpty) {
        await dao.updateRow(
          row.localId,
          TasksCompanion(
            dirtyFields: Value(dirty.clearSent(dirty.toMap()).encode()),
          ),
        );
      }
      return PushResult.dropped;
    }
    final body = await _patchBody(ctx, dao, row, fields);
    final dto = await api.updateJson(TaskUid(uid), body);
    await _afterPush(ctx, dao, row.localId, dto, sent);
    return PushResult.ok;
  }

  /// `POST /task`: every non-empty field of the row; references resolved to
  /// server ids now (throws `DependencyPendingException` while a project or
  /// parent has none yet).
  Future<Map<String, Object?>> _createBody(
    SyncContext ctx,
    TaskDao dao,
    TaskRow row,
  ) async {
    final tags = await dao.tagNames(row.localId);
    final weekdays = decodeIntList(row.recurrenceWeekdays);
    final recurring = (row.recurrenceType ?? 'none') != 'none';
    return {
      'name': row.name,
      if (row.note != null) 'note': row.note,
      'status': row.status,
      'priority': row.priority,
      if (row.dueDate != null) 'due_date': row.dueDate,
      if (row.dueTime != null) 'due_time': row.dueTime,
      if (row.deferUntil != null)
        'defer_until': row.deferUntil!.toUtc().toIso8601String(),
      if (row.reminderAt != null)
        'reminder_at': row.reminderAt!.toUtc().toIso8601String(),
      if (row.estimatedMinutes != null)
        'estimated_minutes': row.estimatedMinutes,
      if (row.projectLocalId != null)
        'project_uid': await ctx.ids.requireUid(
          SyncEntity.project,
          row.projectLocalId!,
        ),
      if (row.areaLocalId != null)
        'area_uid': await ctx.ids.requireUid(SyncEntity.area, row.areaLocalId!),
      if (tags.isNotEmpty)
        'tags': [
          for (final n in tags) {'name': n},
        ],
      if (row.parentLocalId != null)
        'parent_task_id': await ctx.ids.requireServerId(
          SyncEntity.task,
          row.parentLocalId!,
        ),
      if (recurring) 'recurrence_type': row.recurrenceType,
      if (recurring && row.recurrenceInterval != null)
        'recurrence_interval': row.recurrenceInterval,
      if (row.recurrenceEndDate != null)
        'recurrence_end_date': row.recurrenceEndDate,
      if (row.recurrenceWeekday != null)
        'recurrence_weekday': row.recurrenceWeekday,
      'recurrence_weekdays': ?weekdays,
      if (row.recurrenceMonthDay != null)
        'recurrence_month_day': row.recurrenceMonthDay,
      if (row.recurrenceWeekOfMonth != null)
        'recurrence_week_of_month': row.recurrenceWeekOfMonth,
      if (row.completionBased) 'completion_based': true,
    };
  }

  /// `PATCH /task/:uid` body from the dirty [fields], values read from the
  /// row now. Tududi drops the due time when only `due_date` is sent, so a
  /// dirty date with an existing time sends both.
  Future<Map<String, Object?>> _patchBody(
    SyncContext ctx,
    TaskDao dao,
    TaskRow row,
    Set<String> fields,
  ) async {
    final body = <String, Object?>{};
    for (final f in fields) {
      switch (f) {
        case TaskField.name:
          body['name'] = row.name;
        case TaskField.note:
          body['note'] = row.note;
        case TaskField.status:
          body['status'] = row.status;
        case TaskField.priority:
          body['priority'] = row.priority;
        case TaskField.dueDate:
          body['due_date'] = row.dueDate;
        case TaskField.dueTime:
          body['due_time'] = row.dueTime;
        case TaskField.deferUntil:
          body['defer_until'] = row.deferUntil?.toUtc().toIso8601String();
        case TaskField.reminderAt:
          body['reminder_at'] = row.reminderAt?.toUtc().toIso8601String();
        case TaskField.estimatedMinutes:
          body['estimated_minutes'] = row.estimatedMinutes;
        case TaskField.projectUid:
          body['project_uid'] = row.projectLocalId == null
              ? null
              : await ctx.ids.requireUid(
                  SyncEntity.project,
                  row.projectLocalId!,
                );
        case TaskField.areaUid:
          body['area_uid'] = row.areaLocalId == null
              ? null
              : await ctx.ids.requireUid(SyncEntity.area, row.areaLocalId!);
        case TaskField.tags:
          body['tags'] = [
            for (final n in await dao.tagNames(row.localId)) {'name': n},
          ];
        case TaskField.recurrenceType:
          body['recurrence_type'] = row.recurrenceType ?? 'none';
        case TaskField.recurrenceInterval:
          body['recurrence_interval'] = row.recurrenceInterval;
        case TaskField.recurrenceEndDate:
          body['recurrence_end_date'] = row.recurrenceEndDate;
        case TaskField.recurrenceWeekday:
          body['recurrence_weekday'] = row.recurrenceWeekday;
        case TaskField.recurrenceWeekdays:
          body['recurrence_weekdays'] = decodeIntList(row.recurrenceWeekdays);
        case TaskField.recurrenceMonthDay:
          body['recurrence_month_day'] = row.recurrenceMonthDay;
        case TaskField.recurrenceWeekOfMonth:
          body['recurrence_week_of_month'] = row.recurrenceWeekOfMonth;
        case TaskField.completionBased:
          body['completion_based'] = row.completionBased;
      }
    }
    if (body.containsKey('due_date') &&
        !body.containsKey('due_time') &&
        row.dueTime != null) {
      body['due_time'] = row.dueTime;
    }
    return body;
  }

  /// Records a successful create / update: uid and ids, the new merge base,
  /// the dirty marks that were sent are cleared (a field edited meanwhile
  /// stays dirty), then the server's version is merged in like a pull.
  Future<void> _afterPush(
    SyncContext ctx,
    TaskDao dao,
    String localId,
    TaskDto dto,
    Map<String, int> sent,
  ) => ctx.db.transaction(() async {
    final row = await dao.byLocalId(localId);
    if (row == null) return;
    final dirty = DirtyFields.decode(row.dirtyFields).clearSent(sent);
    await dao.updateRow(
      localId,
      TasksCompanion(
        uid: Value(dto.uid ?? row.uid),
        serverId: Value(dto.id ?? row.serverId),
        baseJson: Value(BaseJson.encode(taskFieldMapFromDto(dto))),
        dirtyFields: Value(dirty.encode()),
      ),
    );
    await _apply(ctx, dto);
  });

  // ---- rollback ----

  @override
  Future<void> rollback(SyncContext ctx, OutboxEntry e, ApiError error) async {
    final dao = TaskDao(ctx.db);
    final row = await dao.byLocalId(e.localId);
    if (row == null) return;
    await ctx.db.transaction(() async {
      if (e.op == OutboxOp.delete) {
        // The server refused to delete it: bring it back.
        await dao.updateRow(
          row.localId,
          const TasksCompanion(pendingDelete: Value(false)),
        );
        for (final k in await dao.childRows(row.localId)) {
          await dao.updateRow(
            k.localId,
            const TasksCompanion(pendingDelete: Value(false)),
          );
        }
        return;
      }
      final base = BaseJson.decode(row.baseJson);
      if (row.uid == null || base == null || error is NotFoundError) {
        // Never reached the server (or is gone from it): drop it and its
        // subtasks' queued creates.
        for (final k in await dao.childRows(row.localId)) {
          await (ctx.db.delete(ctx.db.outbox)..where(
                (t) =>
                    t.entity.equals(SyncEntity.task) &
                    t.localId.equals(k.localId),
              ))
              .go();
        }
        await dao.deleteRow(row.localId);
        return;
      }
      final projectId = await _localRef(
        ctx,
        SyncEntity.project,
        base[TaskField.projectUid] as String?,
      );
      final areaId = await _localRef(
        ctx,
        SyncEntity.area,
        base[TaskField.areaUid] as String?,
      );
      await dao.updateRow(
        row.localId,
        companionFromFieldMap(
          base,
          projectLocalId: projectId,
          areaLocalId: areaId,
        ).copyWith(
          dirtyFields: const Value('{}'),
          pendingDelete: const Value(false),
        ),
      );
      final names = [
        for (final n in (base[TaskField.tags] as List? ?? const [])) '$n',
      ];
      await dao.setTagNames(row.localId, names);
    });
    ctx.notice(
      ConflictNotice.rolledBack(
        entity: entity,
        localId: e.localId,
        message: error.message,
      ),
    );
  }
}

/// The handler instance for `syncHandlersProvider`:
/// `ref.watch(taskSyncHandlerProvider)`.
final taskSyncHandlerProvider = Provider<TaskSyncHandler>(
  (ref) => TaskSyncHandler(),
);
