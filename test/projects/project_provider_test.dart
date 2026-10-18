import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/api/api_error.dart';
import 'package:tududa/core/api/patch.dart' as pt;
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/ids.dart';
import 'package:tududa/projects/data/project_api.dart';
import 'package:tududa/projects/providers/project_provider.dart';

import '../support/fake_tududi/routes/projects_routes.dart';
import 'offline_harness.dart';

void main() {
  late OfflineHarness h;
  late ProviderContainer c;

  setUp(() async {
    h = await OfflineHarness.create();
    c = h.container();
  });
  tearDown(() async {
    c.dispose();
    await h.dispose();
  });

  List<String> names() =>
      c.read(projectListProvider).value!.map((p) => p.name).toList();

  test('list is stream backed; create appears without a request', () async {
    final sub = c.listen(projectListProvider, (_, _) {});
    addTearDown(sub.close);
    expect(await c.read(projectListProvider.future), isEmpty);
    final created = await c
        .read(projectListProvider.notifier)
        .create(const NewProject(name: 'B'));
    await pumpEventQueue();
    expect(names(), ['B']);
    expect(c.read(projectListProvider).value!.single.uid, created.uid);
    expect(
      h.remote.server.requests.where((r) => r.path == '/project'),
      isEmpty,
    );
    expect(await h.db.outboxDao.all(), hasLength(1));
  });

  test('list is sorted by name and hides pending deletes', () async {
    final sub = c.listen(projectListProvider, (_, _) {});
    addTearDown(sub.close);
    final n = c.read(projectListProvider.notifier);
    await n.create(const NewProject(name: 'beta'));
    final a = await n.create(const NewProject(name: 'Alpha'));
    final z = await n.create(const NewProject(name: 'Zed'));
    await pumpEventQueue();
    expect(names(), ['Alpha', 'beta', 'Zed']);
    await n.delete(z.uid);
    await pumpEventQueue();
    expect(names(), ['Alpha', 'beta']);
    expect(a.name, 'Alpha');
  });

  test('edit is optimistic and keeps the uid after sync', () async {
    final seeded = seedProject(h.remote.server, name: 'A');
    await h.sync();
    final uid = ProjectUid(seeded['uid'] as String);
    final sub = c.listen(projectListProvider, (_, _) {});
    addTearDown(sub.close);
    await c.read(projectListProvider.future);

    h.t = DateTime.now().toUtc().add(const Duration(seconds: 10));
    final f = c
        .read(projectListProvider.notifier)
        .edit(uid, const ProjectPatch(name: pt.Patch.set('Renamed')));
    await f;
    await pumpEventQueue();
    expect(names(), ['Renamed']);
    expect(seeded['name'], 'A'); // not sent yet
    await h.sync();
    await pumpEventQueue();
    expect(seeded['name'], 'Renamed');
    expect(names(), ['Renamed']);
  });

  test('edit of an unknown project is NotFoundError', () async {
    await expectLater(
      c
          .read(projectListProvider.notifier)
          .edit(const ProjectUid('zzz'), const ProjectPatch()),
      throwsA(isA<NotFoundError>()),
    );
  });

  test('detail follows edits; missing is NotFoundError', () async {
    final seeded = seedProject(h.remote.server, name: 'A');
    await h.sync();
    final uid = ProjectUid(seeded['uid'] as String);
    final sub = c.listen(projectDetailProvider(uid), (_, _) {});
    addTearDown(sub.close);
    expect((await c.read(projectDetailProvider(uid).future)).name, 'A');
    await c
        .read(projectDetailProvider(uid).notifier)
        .edit(const ProjectPatch(status: pt.Patch.set('done')));
    await pumpEventQueue();
    expect(c.read(projectDetailProvider(uid)).value!.status, 'done');

    final missing = projectDetailProvider(const ProjectUid('zzz'));
    final sub2 = c.listen(missing, (_, _) {});
    addTearDown(sub2.close);
    await expectLater(c.read(missing.future), throwsA(isA<NotFoundError>()));
  });

  test('detail by local id keeps working after the uid arrives', () async {
    final created = await c
        .read(projectListProvider.notifier)
        .create(const NewProject(name: 'New'));
    final sub = c.listen(projectDetailProvider(created.uid), (_, _) {});
    addTearDown(sub.close);
    expect(
      (await c.read(projectDetailProvider(created.uid).future)).name,
      'New',
    );
    h.t = DateTime.now().toUtc().add(const Duration(seconds: 10));
    await h.sync();
    await pumpEventQueue();
    final d = c.read(projectDetailProvider(created.uid)).value!;
    expect(d.uid.value, isNot(created.uid.value));
    expect(d.localId, created.localId);
  });

  test('project tasks read the tasks table and move status', () async {
    final p = seedProject(h.remote.server, name: 'A');
    final uid = ProjectUid(p['uid'] as String);
    await h.sync();
    final projectLocal = (await h.db.select(h.db.projects).getSingle()).localId;
    await h.db
        .into(h.db.tasks)
        .insert(
          TasksCompanion.insert(
            localId: 't1',
            projectLocalId: Value(projectLocal),
            name: const Value('t1'),
          ),
        );
    await h.db
        .into(h.db.tasks)
        .insert(
          TasksCompanion.insert(localId: 't2', name: const Value('other')),
        );

    final sub = c.listen(projectTasksProvider(uid), (_, _) {});
    addTearDown(sub.close);
    final tasks = await c.read(projectTasksProvider(uid).future);
    expect(tasks.map((t) => t.name), ['t1']);

    await c.read(projectTasksProvider(uid).notifier).setStatus(tasks.single, 2);
    await pumpEventQueue();
    expect(c.read(projectTasksProvider(uid)).value!.single.status, 2);
    expect((await h.db.outboxDao.all()).single.entity, 'task');
  });

  test('refresh runs a sync cycle', () async {
    seedProject(h.remote.server, name: 'Remote');
    final sub = c.listen(projectListProvider, (_, _) {});
    addTearDown(sub.close);
    await c.read(projectListProvider.future);
    await c.read(projectListProvider.notifier).refresh();
    await pumpEventQueue();
    expect(names(), ['Remote']);
  });
}
