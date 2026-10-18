import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/areas/data/area_api.dart';
import 'package:tududa/core/api/patch.dart' as pt;
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/db/dirty_fields.dart';
import 'package:tududa/core/db/fts.dart';
import 'package:tududa/core/ids.dart';
import 'package:tududa/core/sync/id_resolver.dart';
import 'package:tududa/core/sync/merge.dart';
import 'package:tududa/projects/data/project_api.dart';
import 'package:tududa/projects/data/project_sync_handler.dart';

import '../support/fake_tududi/routes/projects_routes.dart';
import 'offline_harness.dart';

void main() {
  late OfflineHarness h;

  setUp(() async => h = await OfflineHarness.create());
  tearDown(() => h.dispose());

  Future<ProjectRow> row(String key) async => (await (h.db.select(
    h.db.projects,
  )..where((t) => t.uid.equals(key) | t.localId.equals(key))).getSingle());

  test('created offline: visible at once, uid filled after sync', () async {
    final seen = h.projects.watchAll();
    final first = expectLater(
      seen,
      emitsThrough(
        predicate<List<dynamic>>(
          (l) => l.length == 1 && l.single.name == 'Plan',
        ),
      ),
    );
    final p = await h.projects.create(
      const NewProject(name: 'Plan', priority: 2, pinToSidebar: true),
    );
    await first;
    expect(p.localId, isNotNull);
    expect(p.uid.value, p.localId); // no server uid yet
    var r = await row(p.localId!);
    expect(r.uid, isNull);
    expect(
      DirtyFields.decode(r.dirtyFields).fields,
      containsAll(['name', 'status', 'priority', 'pin_to_sidebar']),
    );
    expect((await h.db.outboxDao.all()).single.op, OutboxOp.create);

    await h.sync();

    r = await row(p.localId!);
    expect(r.uid, startsWith('proj'));
    expect(r.serverId, isNotNull);
    expect(r.dirtyFields, '{}');
    expect(r.baseJson, isNotNull);
    expect(await h.db.outboxDao.all(), isEmpty);
    final remote = projectStoreOf(h.remote.server).projects.values.single;
    expect(remote['name'], 'Plan');
    expect(remote['priority'], 2);
    expect(remote['pin_to_sidebar'], true);
    // The same project is reachable by its new uid.
    expect((await h.projects.get(ProjectUid(r.uid!))).name, 'Plan');
    expect((await h.projects.get(ProjectUid(p.localId!))).name, 'Plan');
  });

  test('edit offline: dirty fields, outbox, optimistic watch, PATCH', () async {
    final seeded = seedProject(h.remote.server, name: 'A', description: 'd');
    await h.sync();
    final uid = ProjectUid(seeded['uid'] as String);

    final updated = await h.projects.update(
      uid,
      const ProjectPatch(
        name: pt.Patch.set('B'),
        description: pt.Patch.clear(),
        status: pt.Patch.set('in_progress'),
      ),
    );
    expect(updated.name, 'B');
    expect(updated.description, isNull);
    var r = await row(uid.value);
    expect(DirtyFields.decode(r.dirtyFields).fields, {
      'name',
      'description',
      'status',
    });
    expect((await h.db.outboxDao.all()).single.op, OutboxOp.update);

    await h.sync();
    expect(seeded['name'], 'B');
    expect(seeded['description'], isNull);
    expect(seeded['status'], 'in_progress');
    final patch = h.remote.server.requests.lastWhere(
      (q) => q.method == 'PATCH',
    );
    expect(patch.path, '/project/${uid.value}');
    r = await row(uid.value);
    expect(r.dirtyFields, '{}');
    expect(r.name, 'B');
    expect(await h.db.outboxDao.all(), isEmpty);
  });

  test('an unchanged patch is not queued', () async {
    seedProject(h.remote.server, name: 'A', uid: 'p1');
    await h.sync();
    await h.projects.update(
      const ProjectUid('p1'),
      const ProjectPatch(name: pt.Patch.set('A')),
    );
    expect(await h.db.outboxDao.all(), isEmpty);
  });

  test(
    'server edited meanwhile: merged per field, server wins older',
    () async {
      final seeded = seedProject(h.remote.server, name: 'A', description: 'd');
      await h.sync();
      h.t = DateTime.now().toUtc().subtract(const Duration(hours: 1));
      await h.projects.update(
        ProjectUid(seeded['uid'] as String),
        const ProjectPatch(
          name: pt.Patch.set('Local'),
          priority: pt.Patch.set(1),
        ),
      );
      // Server: changes name (conflict) and description (no conflict).
      seeded
        ..['name'] = 'Server'
        ..['description'] = 'new desc'
        ..['updated_at'] = DateTime.now().toUtc().toIso8601String();

      h.t = DateTime.now().toUtc();
      await h.sync();

      final r = await row(seeded['uid'] as String);
      expect(r.name, 'Server');
      expect(r.description, 'new desc');
      expect(r.priority, 1); // only we changed it: pushed
      expect(seeded['priority'], 1);
      final n = h.engine.status.notices.where((n) => n.field == 'name');
      expect(n.single.winner, ConflictWinner.server);
      expect(n.single.localValue, 'Local');
      expect(r.dirtyFields, '{}');
    },
  );

  test(
    'server edited meanwhile: newer local edit wins and is pushed',
    () async {
      final seeded = seedProject(h.remote.server, name: 'A');
      await h.sync();
      seeded
        ..['name'] = 'Server'
        ..['updated_at'] = DateTime.now().toUtc().toIso8601String();
      h.t = DateTime.now().toUtc().add(const Duration(hours: 1));
      await h.projects.update(
        ProjectUid(seeded['uid'] as String),
        const ProjectPatch(name: pt.Patch.set('Local')),
      );
      await h.sync();
      expect((await row(seeded['uid'] as String)).name, 'Local');
      expect(seeded['name'], 'Local');
      expect(h.engine.status.notices.single.winner, ConflictWinner.local);
    },
  );

  test('pull keeps rows with local edits and overwrites clean ones', () async {
    final a = seedProject(h.remote.server, name: 'A');
    final b = seedProject(h.remote.server, name: 'B');
    await h.sync();
    h.t = DateTime.now().toUtc().add(const Duration(hours: 1));
    await h.projects.update(
      ProjectUid(a['uid'] as String),
      const ProjectPatch(name: pt.Patch.set('Mine')),
    );
    a['name'] = 'Theirs';
    b['name'] = 'B2';

    await ProjectSyncHandler().pull(h.ctx());

    expect((await row(a['uid'] as String)).name, 'Mine');
    expect(
      DirtyFields.decode((await row(a['uid'] as String)).dirtyFields).fields,
      {'name'},
    );
    expect((await row(b['uid'] as String)).name, 'B2');
    expect(await h.db.outboxDao.all(), hasLength(1));
  });

  test('pending delete wins over a server edit; delete is pushed', () async {
    final a = seedProject(h.remote.server, name: 'A', uid: 'pa');
    await h.sync();
    await h.projects.delete(const ProjectUid('pa'));
    expect(await h.projects.list(), isEmpty);
    a['name'] = 'Edited';
    await ProjectSyncHandler().pull(h.ctx());
    expect((await row('pa')).pendingDelete, isTrue);
    expect(await h.projects.list(), isEmpty);

    await h.sync();
    expect(projectStoreOf(h.remote.server).projects, isEmpty);
    expect(await h.db.select(h.db.projects).get(), isEmpty);
  });

  test('create then delete offline never reaches the server', () async {
    final p = await h.projects.create(const NewProject(name: 'Tmp'));
    await h.projects.delete(p.uid);
    expect(await h.db.outboxDao.all(), isEmpty);
    expect(await h.db.select(h.db.projects).get(), isEmpty);
    await h.sync();
    expect(
      h.remote.server.requests.where(
        (r) => r.method == 'POST' && r.path == '/project',
      ),
      isEmpty,
    );
  });

  test('fullReconcile removes clean rows the server lost only', () async {
    final keep = seedProject(h.remote.server, name: 'Keep', uid: 'k');
    seedProject(h.remote.server, name: 'Gone', uid: 'g');
    seedProject(h.remote.server, name: 'Edited', uid: 'e');
    seedProject(h.remote.server, name: 'Deleted', uid: 'd');
    await h.sync();
    h.t = DateTime.now().toUtc().add(const Duration(hours: 1));
    await h.projects.update(
      const ProjectUid('e'),
      const ProjectPatch(name: pt.Patch.set('E2')),
    );
    await h.projects.delete(const ProjectUid('d'));
    final local = await h.projects.create(const NewProject(name: 'Local'));
    final store = projectStoreOf(h.remote.server).projects;
    store
      ..remove('g')
      ..remove('e')
      ..remove('d');

    await ProjectSyncHandler().fullReconcile(h.ctx());

    final rows = {
      for (final r in await h.db.select(h.db.projects).get())
        r.uid ?? r.localId: r,
    };
    expect(rows.keys, unorderedEquals(['k', 'e', local.localId]));
    expect(keep['name'], 'Keep');
  });

  test('counts come from the pull and are never dirty', () async {
    final p = seedProject(h.remote.server, name: 'A', uid: 'pc');
    h.remote.server.seedTask(projectUid: 'pc', status: 2);
    h.remote.server.seedTask(projectUid: 'pc');
    await h.sync();
    var r = await row('pc');
    expect((r.taskCount, r.completedTaskCount), (2, 1));
    expect(r.dirtyFields, '{}');
    expect((await h.projects.get(const ProjectUid('pc'))).progress, 0.5);

    await h.projects.update(
      const ProjectUid('pc'),
      const ProjectPatch(name: pt.Patch.set('B')),
    );
    r = await row('pc');
    expect(DirtyFields.decode(r.dirtyFields).fields, {'name'});
    h.remote.server.seedTask(projectUid: 'pc');
    await h.sync();
    r = await row('pc');
    expect((r.taskCount, r.completedTaskCount), (3, 1));
    expect(r.dirtyFields, '{}');
    expect(p['name'], 'B');
  });

  test('400 on create rolls the row back with a notice', () async {
    final p = await h.projects.create(const NewProject(name: '  '));
    await h.sync();
    expect(await h.db.select(h.db.projects).get(), isEmpty);
    expect(await h.db.outboxDao.all(), isEmpty);
    final n = h.engine.status.notices.single;
    expect((n.entity, n.localId, n.field), ('project', p.localId, '*'));
  });

  test('400 on update restores the server state', () async {
    final seeded = seedProject(h.remote.server, name: 'A', uid: 'pu');
    await h.sync();
    await h.projects.update(
      const ProjectUid('pu'),
      const ProjectPatch(name: pt.Patch.set(' '), priority: pt.Patch.set(2)),
    );
    await h.sync();
    final r = await row('pu');
    expect(r.name, 'A');
    expect(r.priority, isNull);
    expect(r.dirtyFields, '{}');
    expect(h.engine.status.notices.single.field, '*');
    expect(seeded['name'], 'A');
  });

  test('404 on update removes the row (gone on the server)', () async {
    seedProject(h.remote.server, name: 'A', uid: 'pn');
    await h.sync();
    await h.projects.update(
      const ProjectUid('pn'),
      const ProjectPatch(name: pt.Patch.set('B')),
    );
    projectStoreOf(h.remote.server).projects.clear();
    await h.sync();
    expect(await h.db.select(h.db.projects).get(), isEmpty);
    expect(h.engine.status.notices, hasLength(1));
  });

  test('project under an offline-created area waits for the area', () async {
    final area = await h.areas.create(const NewArea(name: 'Work'));
    final p = await h.projects.create(NewProject(name: 'P', areaUid: area.uid));
    expect(p.areaUid, area.uid);
    expect(p.areaName, 'Work');

    // Pushed before its area: the handler asks the engine to wait.
    final projectEntry = (await h.db.outboxDao.all()).last;
    expect(projectEntry.entity, 'project');
    await expectLater(
      ProjectSyncHandler().push(h.ctx(), projectEntry),
      throwsA(isA<DependencyPendingException>()),
    );
    expect((await row(p.localId!)).uid, isNull);
    expect(
      h.remote.server.requests.where(
        (r) => r.path == '/project' && r.method == 'POST',
      ),
      isEmpty,
    );

    await h.sync();
    expect(await h.db.outboxDao.all(), isEmpty);
    final st = projectStoreOf(h.remote.server);
    final areaUid = st.areas.keys.single;
    expect(st.projects.values.single['area_uid'], areaUid);
    final after = await h.projects.get(ProjectUid(p.localId!));
    expect(after.areaUid, AreaUid(areaUid));
    expect(after.areaName, 'Work');
  });

  test(
    'moving a project to another area sends area_uid; clearing nulls it',
    () async {
      final a1 = seedArea(h.remote.server, name: 'A1', uid: 'a1');
      seedArea(h.remote.server, name: 'A2', uid: 'a2');
      final seeded = seedProject(
        h.remote.server,
        name: 'P',
        uid: 'p1',
        areaUid: 'a1',
      );
      await h.sync();
      expect(
        (await h.projects.get(const ProjectUid('p1'))).areaUid,
        const AreaUid('a1'),
      );

      await h.projects.update(
        const ProjectUid('p1'),
        const ProjectPatch(areaUid: pt.Patch.set(AreaUid('a2'))),
      );
      await h.sync();
      expect(seeded['area_uid'], 'a2');

      await h.projects.update(
        const ProjectUid('p1'),
        const ProjectPatch(areaUid: pt.Patch.clear()),
      );
      await h.sync();
      expect(seeded['area_uid'], isNull);
      expect((await h.projects.get(const ProjectUid('p1'))).areaUid, isNull);
      expect(a1['name'], 'A1');
    },
  );

  test('upsert never replaces rows', () async {
    // The search index is trigger driven; insertOnConflictUpdate keeps it
    // consistent when a pull overwrites a row.
    seedProject(h.remote.server, name: 'Searchable', uid: 'ps');
    await h.sync();
    final rows = await h.db.searchIndex(ftsQuery('Searchable'), 10).get();
    expect(rows, hasLength(1));
    projectStoreOf(h.remote.server).projects['ps']!['name'] = 'Renamed';
    await h.sync();
    expect(await h.db.searchIndex(ftsQuery('Searchable'), 10).get(), isEmpty);
    expect(await h.db.searchIndex(ftsQuery('Renamed'), 10).get(), hasLength(1));
  });
}
