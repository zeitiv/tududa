import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/areas/data/area_api.dart';
import 'package:tududa/areas/data/area_sync_handler.dart';
import 'package:tududa/areas/providers/area_provider.dart';
import 'package:tududa/core/api/api_error.dart';
import 'package:tududa/core/api/patch.dart' as pt;
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/db/dirty_fields.dart';
import 'package:tududa/core/ids.dart';
import 'package:tududa/core/sync/merge.dart';
import 'package:tududa/projects/data/project_api.dart';

import '../projects/offline_harness.dart';
import '../support/fake_tududi/routes/projects_routes.dart';

void main() {
  late OfflineHarness h;

  setUp(() async => h = await OfflineHarness.create());
  tearDown(() => h.dispose());

  Future<AreaRow> row(String key) => (h.db.select(
    h.db.areas,
  )..where((t) => t.uid.equals(key) | t.localId.equals(key))).getSingle();

  Future<ProjectRow> project(String key) => (h.db.select(
    h.db.projects,
  )..where((t) => t.uid.equals(key) | t.localId.equals(key))).getSingle();

  test('created offline: visible at once, uid filled after sync', () async {
    final seen = h.areas.watchAll();
    final first = expectLater(
      seen,
      emitsThrough(
        predicate<List<dynamic>>(
          (l) => l.length == 1 && l.single.name == 'Home',
        ),
      ),
    );
    final a = await h.areas.create(
      const NewArea(name: 'Home', description: 'd'),
    );
    await first;
    expect(a.uid.value, a.localId);
    expect(DirtyFields.decode((await row(a.localId!)).dirtyFields).fields, {
      'name',
      'description',
    });

    await h.sync();
    final r = await row(a.localId!);
    expect(r.uid, startsWith('area'));
    expect(r.dirtyFields, '{}');
    expect(await h.db.outboxDao.all(), isEmpty);
    expect(projectStoreOf(h.remote.server).areas.values.single['name'], 'Home');
    expect((await h.areas.list()).single.uid, AreaUid(r.uid!));
  });

  test('edit offline merges with a newer server version', () async {
    final seeded = seedArea(h.remote.server, name: 'A', description: 'd');
    await h.sync();
    h.t = DateTime.now().toUtc().subtract(const Duration(hours: 1));
    await h.areas.update(
      AreaUid(seeded['uid'] as String),
      const AreaPatch(name: pt.Patch.set('Mine')),
    );
    seeded
      ..['name'] = 'Theirs'
      ..['description'] = 'theirs d'
      ..['updated_at'] = DateTime.now().toUtc().toIso8601String();
    h.t = DateTime.now().toUtc();
    await h.sync();
    final r = await row(seeded['uid'] as String);
    expect((r.name, r.description), ('Theirs', 'theirs d'));
    final n = h.engine.status.notices.single;
    expect((n.field, n.winner), ('name', ConflictWinner.server));
  });

  test('deleting an area unlinks its projects and pushes in order', () async {
    seedArea(h.remote.server, name: 'W', uid: 'a1');
    final p = seedProject(h.remote.server, name: 'P', uid: 'p1', areaUid: 'a1');
    await h.sync();
    expect((await h.projects.list()).single.areaUid, const AreaUid('a1'));

    final watched = h.areas.watchAll();
    await h.areas.delete(const AreaUid('a1'));
    expect(await watched.first, isEmpty);
    final unlinked = await h.projects.get(const ProjectUid('p1'));
    expect(unlinked.areaUid, isNull);
    expect(DirtyFields.decode((await project('p1')).dirtyFields).fields, {
      'area_uid',
    });
    expect((await h.db.outboxDao.all()).map((e) => '${e.entity} ${e.op}'), [
      'project update',
      'area delete',
    ]);

    h.remote.server.requests.clear();
    await h.sync();
    final writes = [
      for (final r in h.remote.server.requests)
        if (r.method != 'GET') '${r.method} ${r.path}',
    ];
    expect(writes, ['PATCH /project/p1', 'DELETE /areas/a1']);
    expect(p['area_uid'], isNull);
    expect(projectStoreOf(h.remote.server).areas, isEmpty);
    expect(await h.db.select(h.db.areas).get(), isEmpty);
    expect((await project('p1')).areaLocalId, isNull);
    expect(await h.db.outboxDao.all(), isEmpty);
  });

  test('deleting a never-synced area leaves projects creatable', () async {
    final a = await h.areas.create(const NewArea(name: 'Tmp'));
    final p = await h.projects.create(NewProject(name: 'P', areaUid: a.uid));
    await h.areas.delete(a.uid);
    expect(await h.db.select(h.db.areas).get(), isEmpty);
    await h.sync();
    final st = projectStoreOf(h.remote.server);
    expect(st.areas, isEmpty);
    expect(st.projects.values.single['area_uid'], isNull);
    expect((await project(p.localId!)).uid, isNotNull);
  });

  test('400 on create rolls back, unlinking waiting projects', () async {
    final a = await h.areas.create(const NewArea(name: ' '));
    final p = await h.projects.create(NewProject(name: 'P', areaUid: a.uid));
    await h.sync();
    expect(await h.db.select(h.db.areas).get(), isEmpty);
    expect(h.engine.status.notices.map((n) => (n.entity, n.field)), [
      ('area', '*'),
    ]);
    // The project survives, without an area, and is created.
    final r = await project(p.localId!);
    expect(r.areaLocalId, isNull);
    expect(r.uid, isNotNull);
    expect(await h.db.outboxDao.all(), isEmpty);
  });

  test('400 on update restores base; 404 on delete is success', () async {
    seedArea(h.remote.server, name: 'A', uid: 'a1');
    seedArea(h.remote.server, name: 'B', uid: 'a2');
    await h.sync();
    await h.areas.update(
      const AreaUid('a1'),
      const AreaPatch(name: pt.Patch.set(' ')),
    );
    await h.areas.delete(const AreaUid('a2'));
    projectStoreOf(h.remote.server).areas.remove('a2');
    await h.sync();
    expect((await row('a1')).name, 'A');
    expect((await row('a1')).dirtyFields, '{}');
    expect(h.engine.status.notices, hasLength(1));
    expect(await h.db.select(h.db.areas).get(), hasLength(1));
    expect(await h.db.outboxDao.all(), isEmpty);
  });

  test('pull keeps dirty rows; fullReconcile removes clean-missing', () async {
    final a = seedArea(h.remote.server, name: 'A', uid: 'a1');
    seedArea(h.remote.server, name: 'B', uid: 'a2');
    seedArea(h.remote.server, name: 'C', uid: 'a3');
    await h.sync();
    h.t = DateTime.now().toUtc().add(const Duration(hours: 1));
    await h.areas.update(
      const AreaUid('a1'),
      const AreaPatch(name: pt.Patch.set('Mine')),
    );
    a['name'] = 'Theirs';
    await AreaSyncHandler().pull(h.ctx());
    expect((await row('a1')).name, 'Mine');

    final store = projectStoreOf(h.remote.server).areas;
    store
      ..remove('a1')
      ..remove('a2');
    await AreaSyncHandler().fullReconcile(h.ctx());
    final uids = [for (final r in await h.db.select(h.db.areas).get()) r.uid];
    expect(uids, unorderedEquals(['a1', 'a3']));
  });

  test('project_count refreshes from the pull and is never dirty', () async {
    seedArea(h.remote.server, name: 'A', uid: 'a1');
    await h.sync();
    expect((await row('a1')).projectCount, 0);
    seedProject(h.remote.server, name: 'P', areaUid: 'a1');
    await h.areas.update(
      const AreaUid('a1'),
      const AreaPatch(description: pt.Patch.set('x')),
    );
    expect(DirtyFields.decode((await row('a1')).dirtyFields).fields, {
      'description',
    });
    await h.sync();
    final r = await row('a1');
    expect(r.projectCount, 1);
    expect(r.dirtyFields, '{}');
  });

  test('unknown area: NotFoundError', () async {
    await expectLater(
      h.areas.update(const AreaUid('nope'), const AreaPatch()),
      throwsA(isA<NotFoundError>()),
    );
    await expectLater(
      h.areas.delete(const AreaUid('nope')),
      throwsA(isA<NotFoundError>()),
    );
  });

  group('provider', () {
    late ProviderContainer c;
    setUp(() {
      c = h.container();
      addTearDown(c.dispose);
    });

    test('create, edit, delete show at once', () async {
      final sub = c.listen(areaListProvider, (_, _) {});
      addTearDown(sub.close);
      expect(await c.read(areaListProvider.future), isEmpty);
      final n = c.read(areaListProvider.notifier);

      final a = await n.create(const NewArea(name: 'Home'));
      await pumpEventQueue();
      expect(c.read(areaListProvider).value!.single.name, 'Home');

      await n.edit(a.uid, const AreaPatch(name: pt.Patch.set('House')));
      await pumpEventQueue();
      expect(c.read(areaListProvider).value!.single.name, 'House');

      await n.delete(a.uid);
      await pumpEventQueue();
      expect(c.read(areaListProvider).value, isEmpty);
    });

    test('refresh runs a sync cycle', () async {
      seedArea(h.remote.server, name: 'Remote');
      final sub = c.listen(areaListProvider, (_, _) {});
      addTearDown(sub.close);
      await c.read(areaListProvider.future);
      await c.read(areaListProvider.notifier).refresh();
      await pumpEventQueue();
      expect(c.read(areaListProvider).value!.single.name, 'Remote');
      expect(
        h.remote.server.requests.where((r) => r.path == '/areas'),
        isNotEmpty,
      );
    });
  });
}
