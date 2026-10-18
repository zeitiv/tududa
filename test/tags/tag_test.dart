import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/api/api_error.dart';
import 'package:tududa/core/api/api_providers.dart';
import 'package:tududa/core/api/patch.dart' show Patch;
import 'package:tududa/core/ids.dart';
import 'package:tududa/tags/data/dto/tag_dto.dart';
import 'package:tududa/tags/data/remote_tag_repository.dart';
import 'package:tududa/tags/data/tag_mapper.dart';
import 'package:tududa/tags/data/tag_patch.dart';
import 'package:tududa/tags/data/tags_api.dart';
import 'package:tududa/tags/providers/tag_provider.dart';

import '../notes/note_test_env.dart';
import '../support/fake_tududi/routes/notes_routes.dart';

void main() {
  test('TagDto: full, name only, nulls', () {
    final full = TagDto.fromJson({
      'id': 1,
      'uid': 'tg1',
      'name': 'work',
      'color': '#123456',
      'pinned': true,
      'created_at': '2025-01-01T00:00:00.000Z',
      'updated_at': '2025-01-02T00:00:00.000Z',
    }).toDomain();
    expect(full.uid, const TagUid('tg1'));
    expect(full.pinned, isTrue);
    expect(full.identifier, 'tg1');

    final min = TagDto.fromJson({'name': 'x', 'color': null}).toDomain();
    expect(min.uid, isNull);
    expect(min.color, isNull);
    expect(min.identifier, 'x');
  });

  test('TagPatch semantics', () {
    expect(const TagPatch().toJson(), isEmpty);
    expect(
      const TagPatch(
        name: Patch.set('n'),
        pinned: Patch.set(false),
        color: Patch.clear(),
      ).toJson(),
      {'name': 'n', 'pinned': false, 'color': null},
    );
  });

  test('repository: CRUD, lookup, errors', () async {
    final stack = await signedInStack();
    final repo = RemoteTagRepository(TagsApi(stack.dio));
    seedTag(stack.server, 'home', color: '#fff');

    expect((await repo.list()).single.name, 'home');
    final created = await repo.create('work');
    expect(created.uid, isNotNull);
    expect((await repo.get(name: 'work')).uid, created.uid);
    expect((await repo.get(uid: created.uid)).name, 'work');

    final renamed = await repo.update(
      created.identifier,
      const TagPatch(name: Patch.set('job'), pinned: Patch.set(true)),
    );
    expect(renamed.name, 'job');
    expect(renamed.pinned, isTrue);
    expect(stack.server.requests.last.path, '/tag/${created.uid!.value}');

    expect(await errorOf(repo.create('  ')), isA<ValidationError>());
    expect(
      await errorOf(
        repo.update(created.identifier, const TagPatch(name: Patch.set(''))),
      ),
      isA<ValidationError>(),
    );
    expect(await errorOf(repo.delete('ghost')), isA<NotFoundError>());
    await repo.delete(created.identifier);
    expect(await repo.list(), hasLength(1));
  });

  test('tagListProvider create/rename/recolor/delete', () async {
    final stack = await signedInStack();
    seedTag(stack.server, 'a');
    final c = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(stack.dio)],
    );
    addTearDown(c.dispose);
    expect(await c.read(tagListProvider.future), hasLength(1));
    final n = c.read(tagListProvider.notifier);

    final b = await n.create('b');
    expect(c.read(tagListProvider).value!.map((t) => t.name), ['a', 'b']);

    final renamed = await n.rename(b, 'bb');
    expect(renamed.name, 'bb');
    final colored = await n.recolor(renamed, '#abcdef');
    expect(colored.color, '#abcdef');
    final cleared = await n.recolor(colored, null);
    expect(cleared.color, isNull);
    expect(c.read(tagListProvider).value!.map((t) => t.name), ['a', 'bb']);

    await n.delete(cleared);
    expect(c.read(tagListProvider).value!.map((t) => t.name), ['a']);
    await expectLater(n.delete(cleared), throwsA(isA<NotFoundError>()));
  });
}
