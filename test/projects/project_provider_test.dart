import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/api/api_error.dart';
import 'package:tududa/core/api/patch.dart' as pt;
import 'package:tududa/core/ids.dart';
import 'package:tududa/projects/data/project_api.dart';
import 'package:tududa/projects/providers/project_provider.dart';

import '../support/fake_tududi/routes/projects_routes.dart';
import 'harness.dart';

void main() {
  late ProjectsHarness h;
  late ProviderContainer c;

  setUp(() async {
    h = await ProjectsHarness.create();
    c = h.container();
    addTearDown(c.dispose);
  });

  test('list loads and create appends', () async {
    seedProject(h.server, name: 'A');
    expect((await c.read(projectListProvider.future)).map((p) => p.name), [
      'A',
    ]);
    final created = await c
        .read(projectListProvider.notifier)
        .create(const NewProject(name: 'B'));
    expect(
      c.read(projectListProvider).value!.map((p) => p.uid),
      contains(created.uid),
    );
    expect(
      h.server.requests.where((r) => r.method == 'POST'),
      hasLength(2),
    ); // login + create
  });

  test('edit is optimistic and settles on the server value', () async {
    final seeded = seedProject(h.server, name: 'A');
    final uid = ProjectUid(seeded['uid'] as String);
    await c.read(projectListProvider.future);
    final f = c
        .read(projectListProvider.notifier)
        .edit(uid, const ProjectPatch(name: pt.Patch.set('Renamed')));
    expect(c.read(projectListProvider).value!.single.name, 'Renamed');
    await f;
    expect(c.read(projectListProvider).value!.single.name, 'Renamed');
    expect(seeded['name'], 'Renamed');
  });

  test('failed edit rolls back and rethrows ApiError', () async {
    final seeded = seedProject(h.server, name: 'A');
    final uid = ProjectUid(seeded['uid'] as String);
    await c.read(projectListProvider.future);
    h.server.failNext('/project/${uid.value}', 500);
    await expectLater(
      c
          .read(projectListProvider.notifier)
          .edit(uid, const ProjectPatch(name: pt.Patch.set('X'))),
      throwsA(isA<ApiError>()),
    );
    expect(c.read(projectListProvider).value!.single.name, 'A');
  });

  test('delete removes; failed delete restores', () async {
    final a = seedProject(h.server, name: 'A');
    final b = seedProject(h.server, name: 'B');
    await c.read(projectListProvider.future);
    final notifier = c.read(projectListProvider.notifier);

    h.server.failNext('/project/${a['uid']}', 500);
    await expectLater(
      notifier.delete(ProjectUid(a['uid'] as String)),
      throwsA(isA<ApiError>()),
    );
    expect(c.read(projectListProvider).value, hasLength(2));

    await notifier.delete(ProjectUid(b['uid'] as String));
    expect(c.read(projectListProvider).value!.single.name, 'A');
  });

  test('detail loads and edits; missing is NotFoundError', () async {
    final seeded = seedProject(h.server, name: 'A');
    final uid = ProjectUid(seeded['uid'] as String);
    expect((await c.read(projectDetailProvider(uid).future)).name, 'A');
    await c
        .read(projectDetailProvider(uid).notifier)
        .edit(const ProjectPatch(status: pt.Patch.set('done')));
    expect(c.read(projectDetailProvider(uid)).value!.status, 'done');

    await expectLater(
      c.read(projectDetailProvider(const ProjectUid('zzz')).future),
      throwsA(isA<NotFoundError>()),
    );
  });

  test('project tasks load by project_uid and move status', () async {
    final p = seedProject(h.server, name: 'A');
    final uid = ProjectUid(p['uid'] as String);
    final mine = h.server.seedTask(name: 't1', projectUid: uid.value);
    h.server.seedTask(name: 'other', projectUid: 'someone-else');

    final tasks = await c.read(projectTasksProvider(uid).future);
    expect(tasks.map((t) => t.name), ['t1']);
    expect(h.server.requests.firstWhere((r) => r.path == '/tasks').query, {
      'project_uid': uid.value,
      'status': 'all',
    });

    await c.read(projectTasksProvider(uid).notifier).setStatus(tasks.single, 2);
    expect(c.read(projectTasksProvider(uid)).value!.single.status, 2);
    expect(mine['status'], 2);
  });
}
