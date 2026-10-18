import 'dart:convert';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/session/session_providers.dart';
import '../../core/api/api_error.dart';
import '../../core/api/page.dart';
import '../../core/api/patch.dart' as p;
import '../../core/db/app_database.dart';
import '../../core/db/dirty_fields.dart';
import '../../core/sync/outbox_dao.dart';
import '../../core/ids.dart';
import '../../core/time/calendar_date.dart';
import '../domain/new_task.dart';
import '../domain/task.dart';
import '../domain/task_views.dart';
import 'task_dao.dart';
import 'task_fields.dart';
import 'task_patch.dart';
import 'task_query.dart';
import 'task_repository.dart';
import 'undo_token.dart';

/// [TaskRepository] over the local database.
///
/// Every write is ONE `db.transaction`: the row update, the dirty-field marks
/// and the outbox entry (see `lib/core/sync/README.md`). The UI therefore sees
/// the change immediately (through [TaskDao.watchView]), and `SyncEngine`
/// sends it later. Outbox entries wait [undoWindow] before they are due, so
/// the `...Tracked` methods can hand out an [UndoToken].
///
/// A task's `uid` in the app is its server uid once it has one and its local
/// id before that; every method accepts either.
class OfflineTaskRepository extends TaskRepository {
  OfflineTaskRepository(
    this.db, {
    DateTime Function()? now,
    this.day,
    this.undoWindow = kUndoWindow,
  }) : dao = TaskDao(db),
       _now = now ?? (() => DateTime.now().toUtc());

  final AppDatabase db;
  final TaskDao dao;
  final Duration undoWindow;
  final DateTime Function() _now;

  /// The user's "today" (zone aware); UTC when not given.
  final TaskDay Function()? day;

  OutboxDao get _outbox => db.outboxDao;

  TaskDay get _today {
    final d = day;
    if (d != null) return d();
    final now = _now();
    return TaskDay.utc(CalendarDate.fromDateTime(now), now: now);
  }

  // ---- reads ----

  @override
  Future<Page<Task>> fetch(TaskQuery query) async {
    final rows =
        await (db.select(db.tasks)..where(
              (t) => t.pendingDelete.equals(false) & t.parentLocalId.isNull(),
            ))
            .get();
    var tasks = await dao.hydrate(rows);
    final day = _today;
    final all = tasks;
    final hidden = TaskViews.templatesWithInstanceToday(all, day);

    bool byType(Task t) {
      switch (query.type) {
        case 'today':
          return TaskViews.matches(
            TaskView.today,
            t,
            day,
            hiddenTemplates: hidden,
          );
        case 'upcoming':
          return TaskViews.matches(TaskView.upcoming, t, day);
        case 'someday':
          return TaskViews.matches(TaskView.someday, t, day);
        case 'next':
          return t.dueDate == null && t.projectUid == null && !t.isCompleted;
        case 'inbox':
          return (t.dueDate == null || t.projectUid == null) && !t.isCompleted;
        case 'waiting':
          return t.status == TaskStatus.waiting;
        default:
          return true;
      }
    }

    bool byStatus(Task t) {
      switch (query.status) {
        case 'completed' || 'done':
          return t.isCompleted;
        case 'active':
          return !t.isCompleted && t.status != TaskStatus.cancelled;
        case 'all':
          return true;
        case null:
          return query.type == 'waiting' || !t.isCompleted;
        default:
          final code = int.tryParse(query.status!);
          return code != null ? t.status.code == code : true;
      }
    }

    final search = query.search?.toLowerCase();
    tasks = [
      for (final t in tasks)
        if (byType(t) &&
            byStatus(t) &&
            (query.projectUid == null || t.projectUid == query.projectUid) &&
            (query.areaUid == null || t.areaUid == query.areaUid) &&
            (query.tag == null || t.tags.any((g) => g.name == query.tag)) &&
            (search == null ||
                search.isEmpty ||
                t.name.toLowerCase().contains(search) ||
                (t.note ?? '').toLowerCase().contains(search)))
          t,
    ];
    _sort(tasks, query.orderBy);

    final offset = query.offset ?? 0;
    final limit = query.limit ?? tasks.length;
    final total = tasks.length;
    final items = tasks.skip(offset).take(limit).toList();
    return Page(
      items: items,
      total: total,
      limit: limit,
      offset: offset,
      hasMore: false,
    );
  }

  static void _sort(List<Task> tasks, String? orderBy) {
    if (orderBy == null) return;
    final bits = orderBy.split(':');
    final desc = bits.length > 1 && bits[1] == 'desc';
    Comparable<Object>? key(Task t) => switch (bits.first) {
      'due_date' => t.dueDate,
      'name' => t.name,
      'priority' => t.priority.code,
      'status' => t.status.code,
      'created_at' => t.createdAt,
      'updated_at' => t.updatedAt,
      'completed_at' => t.completedAt,
      _ => null,
    };
    tasks.sort((a, b) {
      final x = key(a), y = key(b);
      if (x == null && y == null) return 0;
      if (x == null) return 1;
      if (y == null) return -1;
      return desc ? y.compareTo(x) : x.compareTo(y);
    });
  }

  @override
  Future<Task> get(TaskUid uid) async {
    final t = await dao.taskByAnyId(uid.value);
    if (t == null) throw const NotFoundError('Task not found');
    return t;
  }

  @override
  Future<List<Task>> subtasks(TaskUid uid) async {
    final row = await _requireRow(uid);
    final kids = [
      for (final k in await dao.childRows(row.localId))
        if (!k.pendingDelete) k,
    ];
    return dao.hydrate(kids, withSubtasks: false);
  }

  /// The status the task had before it was completed (restored by
  /// [uncomplete]); null when unknown.
  Future<TaskStatus?> statusBeforeDone(TaskUid uid) async {
    final row = await dao.byAnyId(uid.value);
    final s = row?.statusBeforeDone;
    return s == null ? null : TaskStatus.fromCode(s);
  }

  // ---- plain writes (see the ...Tracked variants for undo) ----

  @override
  Future<Task> create(NewTask task) async => (await createTracked(task)).value;

  @override
  Future<Task> update(TaskUid uid, TaskPatch patch) async =>
      (await updateTracked(uid, patch)).value;

  @override
  Future<Task> complete(TaskUid uid) async =>
      (await completeTracked(uid)).value;

  @override
  Future<Task> uncomplete(
    TaskUid uid, {
    TaskStatus restoreTo = TaskStatus.notStarted,
  }) async => (await uncompleteTracked(uid, restoreTo: restoreTo)).value;

  @override
  Future<void> delete(TaskUid uid) async => deleteTracked(uid);

  @override
  Future<Task> postpone(
    TaskUid uid,
    CalendarDate to, {
    LocalTime? keepTime,
  }) async => (await postponeTracked(uid, to, keepTime: keepTime)).value;

  @override
  Future<Task?> skipOccurrence(TaskUid uid) async =>
      (await skipOccurrenceTracked(uid)).value;

  @override
  Future<Task> createSubtask({
    required int parentId,
    required String name,
  }) async {
    final parent = await dao.byServerId(parentId);
    if (parent == null) throw const NotFoundError('Parent task not found');
    return createSubtaskOf(TaskUid(parent.uid ?? parent.localId), name);
  }

  @override
  Future<Task> createSubtaskOf(TaskUid parent, String name) async {
    final row = await _requireRow(parent);
    return (await createTracked(
      NewTask(name: name),
      parentLocalId: row.localId,
    )).value;
  }

  // ---- tracked writes ----

  /// Creates a task (all fields dirty, a `create` entry queued). Subtasks
  /// name their parent by [parentLocalId] (or `NewTask.parentTaskId`, the
  /// server id).
  Future<Change<Task>> createTracked(NewTask n, {String? parentLocalId}) async {
    final name = n.name.trim();
    if (name.isEmpty) throw const ValidationError('Task name is required');
    _checkMinutes(n.estimatedMinutes);
    final now = _now();
    final ms = now.millisecondsSinceEpoch;
    final localId = LocalId.generate().value;

    return db.transaction(() async {
      var parent = parentLocalId;
      if (parent == null && n.parentTaskId != null) {
        final row = await dao.byServerId(n.parentTaskId!);
        if (row == null) throw const NotFoundError('Parent task not found');
        parent = row.localId;
      }
      final projectId = n.projectUid == null
          ? null
          : await ensureProject(n.projectUid!.value);
      final areaId = n.areaUid == null
          ? null
          : await ensureArea(n.areaUid!.value);
      final status = n.status ?? TaskStatus.notStarted;
      final finished = status.isFinished;
      final dirty = const DirtyFields().markAll(
        TaskField.all.where((f) => f != TaskField.completedAt),
        ms,
      );
      await dao.insertRow(
        TasksCompanion.insert(
          localId: localId,
          name: Value(name),
          originalName: Value(name),
          note: Value(n.note),
          status: Value(status.code),
          priority: Value((n.priority ?? Priority.low).code),
          dueDate: Value(n.dueDate?.toIso()),
          dueTime: Value(n.dueTime?.format()),
          deferUntil: Value(n.deferUntil?.toUtc()),
          reminderAt: Value(n.reminderAt?.toUtc()),
          completedAt: Value(finished ? now : null),
          estimatedMinutes: Value(n.estimatedMinutes),
          projectLocalId: Value(projectId),
          areaLocalId: Value(areaId),
          parentLocalId: Value(parent),
          recurrenceType: Value(n.recurrenceType ?? 'none'),
          recurrenceInterval: Value(n.recurrenceInterval),
          recurrenceEndDate: Value(n.recurrenceEndDate?.toIso()),
          recurrenceWeekday: Value(n.recurrenceWeekday),
          recurrenceWeekdays: Value(
            n.recurrenceWeekdays == null
                ? null
                : jsonEncode(n.recurrenceWeekdays),
          ),
          recurrenceMonthDay: Value(n.recurrenceMonthDay),
          recurrenceWeekOfMonth: Value(n.recurrenceWeekOfMonth),
          completionBased: Value(n.completionBased ?? false),
          localUpdatedAt: Value(now),
          dirtyFields: Value(dirty.encode()),
        ),
      );
      await dao.setTagNames(localId, n.tags);
      final snap = TaskSnapshot(
        localId: localId,
        row: null,
        tagLocalIds: const [],
        outbox: const [],
      );
      snap.outboxId = await _enqueue(localId, OutboxOp.create, now);
      return Change(
        await get(TaskUid(localId)),
        UndoToken(
          kind: UndoKind.create,
          sendAfter: now.add(undoWindow),
          snapshots: [snap],
        ),
      );
    });
  }

  @override
  Future<Change<Task>> updateTracked(TaskUid uid, TaskPatch patch) async {
    final now = _now();
    return db.transaction(() async {
      final row = await _requireRow(uid);
      final snap = await _applyPatch(row, patch, now);
      final task = await get(TaskUid(row.uid ?? row.localId));
      if (snap == null) return Change(task);
      return Change(
        task,
        UndoToken(
          kind: UndoKind.update,
          sendAfter: now.add(undoWindow),
          snapshots: [snap],
        ),
      );
    });
  }

  @override
  Future<Change<List<Task>>> bulk(List<TaskUid> uids, TaskPatch patch) async {
    final now = _now();
    return db.transaction(() async {
      final snaps = <TaskSnapshot>[];
      final tasks = <Task>[];
      for (final uid in uids) {
        final row = await _requireRow(uid);
        final snap = await _applyPatch(row, patch, now);
        if (snap != null) snaps.add(snap);
        tasks.add(await get(TaskUid(row.uid ?? row.localId)));
      }
      return Change(
        tasks,
        snaps.isEmpty
            ? null
            : UndoToken(
                kind: UndoKind.update,
                sendAfter: now.add(undoWindow),
                snapshots: snaps,
              ),
      );
    });
  }

  @override
  Future<Change<Task>> postponeTracked(
    TaskUid uid,
    CalendarDate to, {
    LocalTime? keepTime,
  }) => updateTracked(uid, TaskPatch.moveTo(to, time: keepTime));

  @override
  Future<Change<Task>> completeTracked(TaskUid uid) async {
    final now = _now();
    return db.transaction(() async {
      final row = await _requireRow(uid);
      if (TaskStatus.fromCode(row.status).isFinished) {
        return Change(await get(uid));
      }
      final snap = await _snapshot(row, {
        TaskField.status,
        TaskField.completedAt,
      });
      final dirty = DirtyFields.decode(row.dirtyFields)
          .markAll(snap.fields, now.millisecondsSinceEpoch);
      await dao.updateRow(
        row.localId,
        TasksCompanion(
          status: Value(TaskStatus.done.code),
          statusBeforeDone: Value(row.status),
          completedAt: Value(now),
          dirtyFields: Value(dirty.encode()),
          localUpdatedAt: Value(now),
        ),
      );
      snap.outboxId = await _enqueue(
        row.localId,
        OutboxOp.complete,
        now,
        extra: _completedExtra(true),
      );
      return Change(
        await get(TaskUid(row.uid ?? row.localId)),
        UndoToken(
          kind: UndoKind.complete,
          sendAfter: now.add(undoWindow),
          snapshots: [snap],
        ),
      );
    });
  }

  @override
  Future<Change<Task>> uncompleteTracked(
    TaskUid uid, {
    TaskStatus restoreTo = TaskStatus.notStarted,
  }) async {
    final now = _now();
    return db.transaction(() async {
      final row = await _requireRow(uid);
      if (!TaskStatus.fromCode(row.status).isFinished) {
        return Change(await get(uid));
      }
      // Remembered status wins unless the caller names another one; never
      // "reopen" into a finished or unknown state.
      var target = restoreTo != TaskStatus.notStarted
          ? restoreTo
          : (row.statusBeforeDone == null
                ? TaskStatus.notStarted
                : TaskStatus.fromCode(row.statusBeforeDone));
      if (target.isFinished || target == TaskStatus.unknown) {
        target = TaskStatus.notStarted;
      }
      final snap = await _snapshot(row, {
        TaskField.status,
        TaskField.completedAt,
      });
      final dirty = DirtyFields.decode(row.dirtyFields)
          .markAll(snap.fields, now.millisecondsSinceEpoch);
      await dao.updateRow(
        row.localId,
        TasksCompanion(
          status: Value(target.code),
          statusBeforeDone: const Value(null),
          completedAt: const Value(null),
          dirtyFields: Value(dirty.encode()),
          localUpdatedAt: Value(now),
        ),
      );
      snap.outboxId = await _enqueue(
        row.localId,
        OutboxOp.complete,
        now,
        extra: _completedExtra(false),
      );
      return Change(
        await get(TaskUid(row.uid ?? row.localId)),
        UndoToken(
          kind: UndoKind.uncomplete,
          sendAfter: now.add(undoWindow),
          snapshots: [snap],
        ),
      );
    });
  }

  @override
  Future<Change<void>> deleteTracked(TaskUid uid) async {
    final now = _now();
    return db.transaction(() async {
      final row = await _requireRow(uid);
      final kids = await dao.childRows(row.localId);
      final snaps = <TaskSnapshot>[await _snapshot(row, const {})];
      for (final k in kids) {
        snaps.add(await _snapshot(k, const {}));
      }
      // Subtasks go with their parent. Those the server never saw vanish;
      // the others are hidden until the parent's delete is confirmed.
      for (final k in kids) {
        if (k.uid == null) {
          await _dropEntries(k.localId);
          await dao.deleteRow(k.localId);
        } else {
          await dao.updateRow(
            k.localId,
            const TasksCompanion(pendingDelete: Value(true)),
          );
        }
      }
      await dao.updateRow(
        row.localId,
        TasksCompanion(
          pendingDelete: const Value(true),
          localUpdatedAt: Value(now),
        ),
      );
      snaps.first.outboxId = await _enqueue(row.localId, OutboxOp.delete, now);
      return Change(
        null,
        UndoToken(
          kind: UndoKind.delete,
          sendAfter: now.add(undoWindow),
          snapshots: snaps,
        ),
      );
    });
  }

  @override
  Future<Change<Task?>> skipOccurrenceTracked(TaskUid uid) async {
    final now = _now();
    return db.transaction(() async {
      final row = await _requireRow(uid);
      if ((row.recurrenceType ?? 'none') == 'none') {
        throw const ValidationError('Task is not recurring');
      }
      final snap = await _snapshot(row, const {});
      snap.outboxId = await _enqueue(row.localId, OutboxOp.skipOccurrence, now);
      return Change(
        await get(TaskUid(row.uid ?? row.localId)),
        UndoToken(
          kind: UndoKind.skipOccurrence,
          sendAfter: now.add(undoWindow),
          snapshots: [snap],
        ),
      );
    });
  }

  // ---- undo ----

  @override
  Future<bool> undo(UndoToken token) async {
    if (token.used) return false;
    token.used = true;
    final now = _now();
    return db.transaction(() async {
      var ok = true;
      for (final s in token.snapshots) {
        if (await _wasSent(s)) {
          ok = await _inverse(token.kind, s, now) && ok;
        } else {
          await _restore(s);
        }
      }
      return ok;
    });
  }

  /// Whether the outbox already took (or is taking) the change behind [s].
  Future<bool> _wasSent(TaskSnapshot s) async {
    final inflight =
        await (db.select(db.outbox)..where(
              (t) =>
                  t.entity.equals(SyncEntity.task) &
                  t.localId.equals(s.localId) &
                  t.state.equals(OutboxState.inflight),
            ))
            .get();
    if (inflight.isNotEmpty) return true;
    final id = s.outboxId;
    if (id == null) return false;
    return await _outbox.byId(id) == null;
  }

  /// Within the window: the entry is cancelled and the row restored.
  Future<void> _restore(TaskSnapshot s) async {
    await (db.delete(db.outbox)..where(
          (t) =>
              t.entity.equals(SyncEntity.task) &
              t.localId.equals(s.localId) &
              t.state.equals(OutboxState.inflight).not(),
        ))
        .go();
    final present = {for (final e in await _entries(s.localId)) e.id};
    for (final e in s.outbox) {
      if (present.contains(e.id)) continue;
      await db
          .into(db.outbox)
          .insert(
            OutboxCompanion.insert(
              id: Value(e.id),
              entity: e.entity,
              localId: e.localId,
              op: e.op,
              extraJson: Value(e.extraJson),
              createdAt: e.createdAt,
              notBefore: e.notBefore,
              attempts: Value(e.attempts),
              nextAttemptAt: Value(e.nextAttemptAt),
              state: Value(e.state),
              lastError: Value(e.lastError),
            ),
          );
    }
    final row = s.row;
    if (row == null) {
      await dao.deleteRow(s.localId);
    } else {
      await dao.upsertRow(row.toCompanion(true));
      await dao.setTagLinks(s.localId, s.tagLocalIds);
    }
  }

  /// After the change was sent: queue the opposite change.
  Future<bool> _inverse(UndoKind kind, TaskSnapshot s, DateTime now) async {
    final ms = now.millisecondsSinceEpoch;
    final current = await dao.byLocalId(s.localId);
    switch (kind) {
      case UndoKind.skipOccurrence:
        return false;
      case UndoKind.create:
        if (current == null || current.pendingDelete) return false;
        await dao.updateRow(
          s.localId,
          TasksCompanion(
            pendingDelete: const Value(true),
            localUpdatedAt: Value(now),
          ),
        );
        await _enqueue(s.localId, OutboxOp.delete, now);
        return true;
      case UndoKind.delete:
        final old = s.row;
        if (old == null) return false;
        // The server no longer has it: create it again under a new identity.
        await dao.upsertRow(
          old
              .toCompanion(false)
              .copyWith(
                uid: const Value(null),
                serverId: const Value(null),
                serverCreatedAt: const Value(null),
                serverUpdatedAt: const Value(null),
                baseJson: const Value(null),
                pendingDelete: const Value(false),
                localUpdatedAt: Value(now),
                dirtyFields: Value(
                  const DirtyFields()
                      .markAll(
                        TaskField.all.where((f) => f != TaskField.completedAt),
                        ms,
                      )
                      .encode(),
                ),
              ),
        );
        await dao.setTagLinks(s.localId, s.tagLocalIds);
        await _enqueue(s.localId, OutboxOp.create, now);
        return true;
      case UndoKind.update:
      case UndoKind.complete:
      case UndoKind.uncomplete:
        final old = s.row;
        if (old == null || current == null || current.pendingDelete) {
          return false;
        }
        final dirty = DirtyFields.decode(current.dirtyFields)
            .markAll(s.fields, ms);
        await dao.updateRow(
          s.localId,
          companionForFields(old, s.fields).copyWith(
            statusBeforeDone: kind == UndoKind.update
                ? const Value.absent()
                : Value(old.statusBeforeDone),
            dirtyFields: Value(dirty.encode()),
            localUpdatedAt: Value(now),
          ),
        );
        if (s.fields.contains(TaskField.tags)) {
          await dao.setTagLinks(s.localId, s.tagLocalIds);
        }
        if (kind == UndoKind.update) {
          await _enqueue(s.localId, OutboxOp.update, now);
        } else {
          await _enqueue(
            s.localId,
            OutboxOp.complete,
            now,
            extra: _completedExtra(kind == UndoKind.uncomplete),
          );
        }
        return true;
    }
  }

  // ---- internals ----

  static String _completedExtra(bool completed) =>
      jsonEncode({'completed': completed});

  Future<int?> _enqueue(
    String localId,
    String op,
    DateTime now, {
    String? extra,
  }) => _outbox.enqueue(
    entity: SyncEntity.task,
    localId: localId,
    op: op,
    extraJson: extra,
    notBefore: now.add(undoWindow),
    now: now,
  );

  Future<List<OutboxEntry>> _entries(String localId) =>
      (db.select(db.outbox)
            ..where(
              (t) =>
                  t.entity.equals(SyncEntity.task) & t.localId.equals(localId),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();

  Future<void> _dropEntries(String localId) =>
      (db.delete(db.outbox)..where(
            (t) => t.entity.equals(SyncEntity.task) & t.localId.equals(localId),
          ))
          .go();

  Future<TaskRow> _requireRow(TaskUid uid) async {
    final row = await dao.byAnyId(uid.value);
    if (row == null || row.pendingDelete) {
      throw const NotFoundError('Task not found');
    }
    return row;
  }

  Future<TaskSnapshot> _snapshot(TaskRow row, Set<String> fields) async =>
      TaskSnapshot(
        localId: row.localId,
        row: row,
        tagLocalIds: await dao.tagLocalIds(row.localId),
        outbox: await _entries(row.localId),
        fields: fields,
      );

  static void _checkMinutes(int? m) {
    if (m != null && (m < 5 || m > 720)) {
      throw const ValidationError(
        'estimated_minutes must be between 5 and 720',
      );
    }
  }

  /// The local id of the project with [uidOrLocalId]; a stub row is made when
  /// it is unknown so the reference is never dangling (the projects pull
  /// fills it in).
  Future<String> ensureProject(String uidOrLocalId) async {
    final byLocal = await (db.select(
      db.projects,
    )..where((t) => t.localId.equals(uidOrLocalId))).getSingleOrNull();
    if (byLocal != null) return byLocal.localId;
    final byUid = await (db.select(
      db.projects,
    )..where((t) => t.uid.equals(uidOrLocalId))).getSingleOrNull();
    if (byUid != null) return byUid.localId;
    final id = LocalId.generate().value;
    await db
        .into(db.projects)
        .insert(
          ProjectsCompanion.insert(localId: id, uid: Value(uidOrLocalId)),
        );
    return id;
  }

  /// Like [ensureProject] for areas.
  Future<String> ensureArea(String uidOrLocalId) async {
    final byLocal = await (db.select(
      db.areas,
    )..where((t) => t.localId.equals(uidOrLocalId))).getSingleOrNull();
    if (byLocal != null) return byLocal.localId;
    final byUid = await (db.select(
      db.areas,
    )..where((t) => t.uid.equals(uidOrLocalId))).getSingleOrNull();
    if (byUid != null) return byUid.localId;
    final id = LocalId.generate().value;
    await db
        .into(db.areas)
        .insert(AreasCompanion.insert(localId: id, uid: Value(uidOrLocalId)));
    return id;
  }

  /// Applies [patch] to [row] (inside the caller's transaction): changed
  /// columns, dirty marks, tag links and an `update` entry. Returns the
  /// snapshot taken before, or null when the patch changes nothing.
  Future<TaskSnapshot?> _applyPatch(
    TaskRow row,
    TaskPatch patch,
    DateTime now,
  ) async {
    final changed = <String>{};
    var c = const TasksCompanion();

    (bool, T?) read<T>(p.Patch<T> x) => switch (x) {
      p.Set<T>(:final value) => (true, value),
      p.Unset<T>() => (false, null),
    };

    // name
    final (nameSet, nameValue) = read(patch.name);
    if (nameSet) {
      final name = nameValue?.trim() ?? '';
      if (name.isEmpty) throw const ValidationError('Task name is required');
      if (name != row.name) {
        changed.add(TaskField.name);
        c = c.copyWith(name: Value(name), originalName: Value(name));
      }
    }
    // note
    final (noteSet, noteValue) = read(patch.note);
    if (noteSet && noteValue != row.note) {
      changed.add(TaskField.note);
      c = c.copyWith(note: Value(noteValue));
    }
    // status
    final (statusSet, statusValue) = read(patch.status);
    if (statusSet &&
        statusValue != null &&
        statusValue != TaskStatus.unknown &&
        statusValue.code != row.status) {
      changed.add(TaskField.status);
      final wasFinished = TaskStatus.fromCode(row.status).isFinished;
      if (statusValue.isFinished && !wasFinished) {
        changed.add(TaskField.completedAt);
        c = c.copyWith(
          statusBeforeDone: Value(row.status),
          completedAt: Value(now),
        );
      } else if (!statusValue.isFinished && wasFinished) {
        changed.add(TaskField.completedAt);
        c = c.copyWith(
          statusBeforeDone: const Value(null),
          completedAt: const Value(null),
        );
      }
      c = c.copyWith(status: Value(statusValue.code));
    }
    // priority
    final (prioSet, prioValue) = read(patch.priority);
    if (prioSet && prioValue != null && prioValue.code != row.priority) {
      changed.add(TaskField.priority);
      c = c.copyWith(priority: Value(prioValue.code));
    }
    // due date / time
    final (dateSet, dateValue) = read(patch.dueDate);
    if (dateSet && dateValue?.toIso() != row.dueDate) {
      changed.add(TaskField.dueDate);
      c = c.copyWith(dueDate: Value(dateValue?.toIso()));
    }
    final (timeSet, timeValue) = read(patch.dueTime);
    if (timeSet && timeValue?.format() != row.dueTime) {
      changed.add(TaskField.dueTime);
      c = c.copyWith(dueTime: Value(timeValue?.format()));
    }
    final (deferSet, deferValue) = read(patch.deferUntil);
    if (deferSet && isoSeconds(deferValue) != isoSeconds(row.deferUntil)) {
      changed.add(TaskField.deferUntil);
      c = c.copyWith(deferUntil: Value(deferValue?.toUtc()));
    }
    final (remindSet, remindValue) = read(patch.reminderAt);
    if (remindSet && isoSeconds(remindValue) != isoSeconds(row.reminderAt)) {
      changed.add(TaskField.reminderAt);
      c = c.copyWith(reminderAt: Value(remindValue?.toUtc()));
    }
    final (minSet, minValue) = read(patch.estimatedMinutes);
    if (minSet && minValue != row.estimatedMinutes) {
      _checkMinutes(minValue);
      changed.add(TaskField.estimatedMinutes);
      c = c.copyWith(estimatedMinutes: Value(minValue));
    }
    // references
    final (projSet, projValue) = read(patch.projectUid);
    if (projSet) {
      final id = projValue == null
          ? null
          : await ensureProject(projValue.value);
      if (id != row.projectLocalId) {
        changed.add(TaskField.projectUid);
        c = c.copyWith(projectLocalId: Value(id));
      }
    }
    final (areaSet, areaValue) = read(patch.areaUid);
    if (areaSet) {
      final id = areaValue == null ? null : await ensureArea(areaValue.value);
      if (id != row.areaLocalId) {
        changed.add(TaskField.areaUid);
        c = c.copyWith(areaLocalId: Value(id));
      }
    }
    // tags
    List<String>? newTags;
    final (tagsSet, tagsValue) = read(patch.tags);
    if (tagsSet) {
      final wanted = <String>{
        for (final n in tagsValue ?? const <String>[])
          if (n.trim().isNotEmpty) n.trim(),
      };
      final have = (await dao.tagNames(row.localId)).toSet();
      if (wanted.length != have.length || !wanted.containsAll(have)) {
        changed.add(TaskField.tags);
        newTags = wanted.toList();
      }
    }
    // recurrence
    final (rtSet, rtValue) = read(patch.recurrenceType);
    final currentRt = row.recurrenceType ?? 'none';
    if (rtSet && (rtValue ?? 'none') != currentRt) {
      changed.add(TaskField.recurrenceType);
      c = c.copyWith(recurrenceType: Value(rtValue ?? 'none'));
    }
    final (riSet, riValue) = read(patch.recurrenceInterval);
    if (riSet && riValue != row.recurrenceInterval) {
      changed.add(TaskField.recurrenceInterval);
      c = c.copyWith(recurrenceInterval: Value(riValue));
    }
    final (reSet, reValue) = read(patch.recurrenceEndDate);
    if (reSet && reValue?.toIso() != row.recurrenceEndDate) {
      changed.add(TaskField.recurrenceEndDate);
      c = c.copyWith(recurrenceEndDate: Value(reValue?.toIso()));
    }
    final (rwSet, rwValue) = read(patch.recurrenceWeekday);
    if (rwSet && rwValue != row.recurrenceWeekday) {
      changed.add(TaskField.recurrenceWeekday);
      c = c.copyWith(recurrenceWeekday: Value(rwValue));
    }
    final (rwsSet, rwsValue) = read(patch.recurrenceWeekdays);
    if (rwsSet) {
      final text = rwsValue == null ? null : jsonEncode(rwsValue);
      if (text != row.recurrenceWeekdays) {
        changed.add(TaskField.recurrenceWeekdays);
        c = c.copyWith(recurrenceWeekdays: Value(text));
      }
    }
    final (rmSet, rmValue) = read(patch.recurrenceMonthDay);
    if (rmSet && rmValue != row.recurrenceMonthDay) {
      changed.add(TaskField.recurrenceMonthDay);
      c = c.copyWith(recurrenceMonthDay: Value(rmValue));
    }
    final (rwmSet, rwmValue) = read(patch.recurrenceWeekOfMonth);
    if (rwmSet && rwmValue != row.recurrenceWeekOfMonth) {
      changed.add(TaskField.recurrenceWeekOfMonth);
      c = c.copyWith(recurrenceWeekOfMonth: Value(rwmValue));
    }
    final (cbSet, cbValue) = read(patch.completionBased);
    if (cbSet && (cbValue ?? false) != row.completionBased) {
      changed.add(TaskField.completionBased);
      c = c.copyWith(completionBased: Value(cbValue ?? false));
    }

    if (changed.isEmpty) return null;

    final snap = await _snapshot(row, changed);
    final dirty = DirtyFields.decode(row.dirtyFields)
        .markAll(changed, now.millisecondsSinceEpoch);
    await dao.updateRow(
      row.localId,
      c.copyWith(
        dirtyFields: Value(dirty.encode()),
        localUpdatedAt: Value(now),
      ),
    );
    if (newTags != null) await dao.setTagNames(row.localId, newTags);
    snap.outboxId = await _enqueue(row.localId, OutboxOp.update, now);
    return snap;
  }
}

/// The repository the app uses: tasks come from and go to the local
/// database; `SyncEngine` (with `TaskSyncHandler`) talks to the server.
final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => ref.watch(offlineTaskRepositoryProvider),
);

/// The concrete offline repository (for `statusBeforeDone`, `ensureProject`).
final offlineTaskRepositoryProvider = Provider<OfflineTaskRepository>((ref) {
  final clock = ref.watch(userClockProvider);
  return OfflineTaskRepository(
    ref.watch(appDatabaseProvider),
    day: () => TaskDay.fromClock(clock),
  );
});
