import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/time/calendar_date.dart';
import 'package:tududa/tasks/domain/task_views.dart';

/// EXPLAIN QUERY PLAN checks for the hot queries on a 5,000-task database.
///
/// A plan row `SCAN <table>` (without `USING INDEX`) is a full-table scan.
/// Each test lists the scans it tolerates, with the reason; everything else
/// must be a SEARCH (or a covering-index scan).
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await _seed(db);
  });
  tearDown(() => db.close());

  Future<List<String>> plan(String sql, [List<Object?> vars = const []]) async {
    final rows = await db
        .customSelect(
          'EXPLAIN QUERY PLAN $sql',
          variables: [for (final v in vars) _variable(v)],
        )
        .get();
    final lines = [for (final r in rows) r.read<String>('detail')];
    // ignore: avoid_print
    print('PLAN $sql\n  ${lines.join('\n  ')}');
    return lines;
  }

  /// Plan lines that read a whole table: `SCAN tasks` but not
  /// `SCAN tasks USING INDEX/COVERING INDEX`.
  List<String> fullScans(List<String> plan) => [
    for (final l in plan)
      if (l.startsWith('SCAN') &&
          !l.contains('USING INDEX') &&
          !l.contains('USING COVERING INDEX') &&
          !l.contains('VIRTUAL TABLE'))
        l,
  ];

  Future<List<String>> viewPlan(TaskView view) {
    final q = db.select(db.tasks)
      ..where((t) => taskViewWhere(t, view, _day))
      ..orderBy([
        (t) => OrderingTerm(expression: t.dueDate, nulls: NullsOrder.last),
      ]);
    final ctx = q.constructQuery();
    return plan(ctx.sql, ctx.boundVariables);
  }

  group('task views', () {
    // The `today`/`upcoming`/`all`/`someday`/`completed` filters are
    // low-selectivity (most rows match or the predicate is an OR over several
    // columns), so SQLite may legitimately scan `tasks`. What must never
    // happen is the correlated recurring-instance lookup scanning `tasks`
    // once per row: idx_tasks_recurring_parent (recurring_parent_uid,
    // due_date) must serve it.
    for (final view in TaskView.values) {
      test('${view.name}: instance lookup uses an index', () async {
        final p = await viewPlan(view);
        final nested = p.where(
          (l) => l.contains('tasks AS i') || l.contains('tasks i'),
        );
        for (final l in nested) {
          expect(
            l,
            contains('idx_tasks_recurring_parent'),
            reason: 'correlated subquery: $l',
          );
        }
      });
    }

    for (final view in [
      TaskView.overdue,
      TaskView.dueToday,
      TaskView.todayPlan,
      TaskView.today,
      TaskView.completedToday,
    ]) {
      test('${view.name}: no full scan of tasks', () async {
        expect(fullScans(await viewPlan(view)), isEmpty);
      });
    }

    // Documented exceptions: these lists are, by definition, "most of the
    // table" (all / someday: every open task; completed: status NOT IN) or an
    // OR of an index-unfriendly template predicate (upcoming).
    test('all/someday/completed/upcoming may scan but stay bounded', () async {
      for (final v in [
        TaskView.all,
        TaskView.someday,
        TaskView.completed,
        TaskView.upcoming,
      ]) {
        final sw = Stopwatch()..start();
        final rows = await (db.select(
          db.tasks,
        )..where((t) => taskViewWhere(t, v, _day))).get();
        sw.stop();
        // ignore: avoid_print
        print(
          'VIEW ${v.name}: ${rows.length} rows in ${sw.elapsedMilliseconds} ms',
        );
        expect(sw.elapsedMilliseconds, lessThan(2000));
      }
    });
  });

  test('outbox due entries use the state index', () async {
    final q = db.select(db.outbox)
      ..where(
        (t) =>
            t.state.isIn(['pending', 'failed']) &
            t.notBefore.isSmallerOrEqualValue(DateTime.utc(2030)),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    final ctx = q.constructQuery();
    final p = await plan(ctx.sql, ctx.boundVariables);
    expect(fullScans(p), isEmpty);
  });

  test('outbox target lookup uses idx_outbox_target', () async {
    final p = await plan(
      'SELECT * FROM outbox WHERE entity = ? AND local_id = ? AND state <> ?',
      ['task', 'x', 'inflight'],
    );
    expect(fullScans(p), isEmpty);
  });

  test('tag joins use indexes', () async {
    final byTask = await plan(
      'SELECT tags.* FROM task_tags INNER JOIN tags '
      'ON tags.local_id = task_tags.tag_local_id '
      'WHERE task_tags.task_local_id IN (?, ?) ORDER BY tags.name',
      ['t1', 't2'],
    );
    expect(fullScans(byTask), isEmpty);
    final byTag = await plan(
      'SELECT task_local_id FROM task_tags WHERE tag_local_id = ?',
      ['g1'],
    );
    expect(fullScans(byTag), isEmpty);
  });

  test('project / area lists', () async {
    final tasksOfProject = await plan(
      'SELECT * FROM tasks WHERE project_local_id = ? AND pending_delete = 0 '
      'AND parent_local_id IS NULL',
      ['p1'],
    );
    expect(fullScans(tasksOfProject), isEmpty);
    final tasksOfArea = await plan(
      'SELECT * FROM tasks WHERE area_local_id = ? AND pending_delete = 0',
      ['a1'],
    );
    expect(fullScans(tasksOfArea), isEmpty);
    final subtasks = await plan(
      'SELECT * FROM tasks WHERE parent_local_id IN (?, ?)',
      ['t1', 't2'],
    );
    expect(fullScans(subtasks), isEmpty);
    final projectsOfArea = await plan(
      'SELECT * FROM projects WHERE area_local_id = ?',
      ['a1'],
    );
    expect(fullScans(projectsOfArea), isEmpty);
    final byUid = await plan('SELECT * FROM tasks WHERE uid = ?', ['u1']);
    expect(fullScans(byUid), isEmpty);
    final byServer = await plan('SELECT * FROM tasks WHERE server_id = ?', [1]);
    expect(fullScans(byServer), isEmpty);
  });

  test('local search', () async {
    // LocalSearch loads every visible task and matches substrings in Dart
    // (SQLite LIKE/lower only fold ASCII, FTS5 matches word prefixes only),
    // so a scan of tasks/notes/projects/areas/tags is by design: documented
    // exception. The FTS index query itself must not touch the entity tables.
    final scan = await plan('SELECT * FROM tasks WHERE pending_delete = 0');
    expect(scan, hasLength(1)); // a single pass over tasks, via idx_tasks_list

    final fts = await plan(
      'SELECT entity, local_id, title, bm25(search_fts) AS score '
      'FROM search_fts WHERE search_fts MATCH ? ORDER BY score LIMIT 20',
      ['task*'],
    );
    expect(fts.any((l) => l.contains('tasks')), isFalse);

    final sw = Stopwatch()..start();
    final rows = await (db.select(
      db.tasks,
    )..where((t) => t.pendingDelete.equals(false))).get();
    sw.stop();
    // ignore: avoid_print
    print('SEARCH load ${rows.length} tasks in ${sw.elapsedMilliseconds} ms');
    expect(sw.elapsedMilliseconds, lessThan(2000));
  });
}

Variable _variable(Object? v) => switch (v) {
  int() => Variable<int>(v),
  String() => Variable<String>(v),
  double() => Variable<double>(v),
  bool() => Variable<bool>(v),
  DateTime() => Variable<int>(v.millisecondsSinceEpoch ~/ 1000),
  _ => const Variable<String>(null),
};

final _day = TaskDay.utc(CalendarDate(2026, 6, 15));

Future<void> _seed(AppDatabase db) async {
  final base = DateTime.utc(2026, 6, 15);
  await db.batch((b) {
    b.insertAll(db.areas, [
      for (var i = 0; i < 5; i++)
        AreasCompanion.insert(localId: 'a$i', name: Value('Area $i')),
    ]);
    b.insertAll(db.projects, [
      for (var i = 0; i < 50; i++)
        ProjectsCompanion.insert(
          localId: 'p$i',
          name: Value('Project $i'),
          areaLocalId: Value('a${i % 5}'),
        ),
    ]);
    b.insertAll(db.tags, [
      for (var i = 0; i < 30; i++)
        TagsCompanion.insert(localId: 'g$i', name: Value('tag$i')),
    ]);
    b.insertAll(db.tasks, [
      for (var i = 0; i < 5000; i++)
        TasksCompanion.insert(
          localId: 't$i',
          uid: Value('u$i'),
          serverId: Value(i + 1),
          name: Value('Task number $i'),
          status: Value(i % 10 == 0 ? 2 : (i % 7 == 0 ? 1 : 0)),
          priority: Value(i % 3),
          dueDate: Value(
            i % 5 == 0
                ? null
                : CalendarDate.fromDateTime(
                    base.add(Duration(days: (i % 40) - 20)),
                  ).toIso(),
          ),
          completedAt: Value(
            i % 10 == 0 ? base.add(Duration(hours: i % 30)) : null,
          ),
          projectLocalId: Value(i % 4 == 0 ? 'p${i % 50}' : null),
          areaLocalId: Value(i % 9 == 0 ? 'a${i % 5}' : null),
          parentLocalId: Value(i % 25 == 1 ? 't${i - 1}' : null),
          recurringParentUid: Value(i % 50 == 2 ? 'u${i - 2}' : null),
          recurrenceType: Value(i % 50 == 0 ? 'daily' : null),
        ),
    ]);
    b.insertAll(db.taskTags, [
      for (var i = 0; i < 5000; i += 2)
        TaskTagsCompanion.insert(taskLocalId: 't$i', tagLocalId: 'g${i % 30}'),
    ]);
    b.insertAll(db.outbox, [
      for (var i = 0; i < 200; i++)
        OutboxCompanion.insert(
          entity: 'task',
          localId: 't$i',
          op: 'update',
          createdAt: base,
          notBefore: base,
        ),
    ]);
  });
}
