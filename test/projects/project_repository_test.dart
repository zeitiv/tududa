import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/api/api_error.dart';
import 'package:tududa/core/api/patch.dart' as pt;
import 'package:tududa/core/ids.dart';
import 'package:tududa/projects/data/project_api.dart';
import 'package:tududa/projects/data/project_repository.dart';

import '../support/fake_tududi/routes/projects_routes.dart';
import 'harness.dart';

void main() {
  late ProjectsHarness h;
  late RemoteProjectRepository repo;

  setUp(() async {
    h = await ProjectsHarness.create();
    repo = RemoteProjectRepository(ProjectApi(h.dio));
  });

  test('list reads the wrapped response with task progress', () async {
    final p = seedProject(h.server, name: 'Alpha');
    h.server.seedTask(projectUid: p['uid'] as String, status: 2);
    h.server.seedTask(projectUid: p['uid'] as String);
    final list = await repo.list();
    expect(list.single.name, 'Alpha');
    expect(list.single.progress, 0.5);
  });

  test('create, get, patch, delete by uid', () async {
    final created = await repo.create(
      const NewProject(name: ' Beta ', priority: 1),
    );
    expect(created.name, 'Beta');
    expect(created.priority, 1);

    final got = await repo.get(created.uid);
    expect(got.uid, created.uid);

    final patched = await repo.update(
      created.uid,
      const ProjectPatch(
        status: pt.Patch.set('done'),
        priority: pt.Patch.clear(),
      ),
    );
    expect(patched.status, 'done');
    expect(patched.priority, isNull);
    expect(patched.name, 'Beta');

    await repo.delete(created.uid);
    expect(h.server.requests.last.path, '/project/${created.uid.value}');
    expect(await repo.list(), isEmpty);
  });

  test('unknown uid is NotFoundError', () async {
    await expectLater(
      repo.get(const ProjectUid('nope')),
      throwsA(isA<NotFoundError>()),
    );
    await expectLater(
      repo.delete(const ProjectUid('nope')),
      throwsA(isA<NotFoundError>()),
    );
  });

  test('empty name is a 400 ApiError', () async {
    await expectLater(
      repo.create(const NewProject(name: '  ')),
      throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 400)),
    );
  });

  test('401 triggers re-auth and the call succeeds', () async {
    seedProject(h.server, name: 'Alpha');
    h.server.expireAllSessions();
    expect(await repo.list(), hasLength(1));
    expect(h.stack.callbacks.calls, 1);
  });

  test('offline surfaces a transient ApiError', () async {
    h.server.offline = true;
    await expectLater(
      repo.list(),
      throwsA(
        isA<ApiError>().having((e) => e.isTransient, 'isTransient', true),
      ),
    );
  });
}
