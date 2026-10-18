import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/areas/data/area_api.dart';
import 'package:tududa/areas/data/area_dto.dart';
import 'package:tududa/areas/data/area_repository.dart';
import 'package:tududa/areas/models/area_model.dart';
import 'package:tududa/core/api/api_error.dart';
import 'package:tududa/core/api/patch.dart' as pt;
import 'package:tududa/core/ids.dart';

import '../projects/harness.dart';
import '../support/fake_tududi/routes/projects_routes.dart';

void main() {
  late ProjectsHarness h;

  setUp(() async => h = await ProjectsHarness.create());

  test('DTO parses snake and camel project counts', () {
    expect(
      Area.fromDto(
        AreaDto.fromJson({'uid': 'a', 'name': 'W', 'project_count': 3}),
      ).projectCount,
      3,
    );
    expect(
      Area.fromDto(
        AreaDto.fromJson({'uid': 'a', 'name': 'W', 'projectCount': 2}),
      ).projectCount,
      2,
    );
    expect(
      Area.fromDto(AreaDto.fromJson({'uid': 'a', 'name': 'W'})).projectCount,
      isNull,
    );
  });

  test('AreaPatch semantics', () {
    expect(const AreaPatch().toJson(), isEmpty);
    expect(
      const AreaPatch(
        name: pt.Patch.set('N'),
        description: pt.Patch.clear(),
      ).toJson(),
      {'name': 'N', 'description': null},
    );
  });

  test('API hits the plural /areas paths', () async {
    final repo = RemoteAreaRepository(AreaApi(h.dio));
    final a = await repo.create(const NewArea(name: 'Work'));
    seedProject(h.server, name: 'P', areaUid: a.uid.value);
    expect((await repo.list()).single.projectCount, 1);
    final edited = await repo.update(
      a.uid,
      const AreaPatch(description: pt.Patch.set('d')),
    );
    expect(edited.description, 'd');
    await repo.delete(a.uid);

    final paths = [
      for (final r in h.server.requests)
        if (r.path.startsWith('/area')) '${r.method} ${r.path}',
    ];
    expect(paths, [
      'POST /areas',
      'GET /areas',
      'PATCH /areas/${a.uid.value}',
      'DELETE /areas/${a.uid.value}',
    ]);
  });

  test('errors: 404, 400, 401 re-auth', () async {
    final repo = RemoteAreaRepository(AreaApi(h.dio));
    await expectLater(
      repo.update(const AreaUid('nope'), const AreaPatch()),
      throwsA(isA<NotFoundError>()),
    );
    await expectLater(
      repo.create(const NewArea(name: ' ')),
      throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 400)),
    );
    h.server.expireAllSessions();
    expect(await repo.list(), isEmpty);
    expect(h.stack.callbacks.calls, 1);
  });
}
