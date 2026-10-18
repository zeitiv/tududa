import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/api/api_error.dart';
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/sync/sync_engine.dart';
import 'package:tududa/tags/providers/tag_provider.dart';

import '../notes/note_test_env.dart';
import '../support/fake_tududi/routes/notes_routes.dart';

void main() {
  late OfflineEnv env;
  late ProviderContainer c;

  // Stream providers only run while somebody listens.
  Future<T> live<T>(ProviderListenable<AsyncValue<T>> p) {
    final done = Completer<T>();
    c.listen(p, (_, next) {
      if (done.isCompleted) return;
      if (next.hasError) {
        done.completeError(next.error!, next.stackTrace);
      } else if (next.hasValue) {
        done.complete(next.value as T);
      }
    }, fireImmediately: true);
    return done.future;
  }

  setUp(() async {
    env = await OfflineEnv.create();
    c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(env.db),
        syncEngineProvider.overrideWithValue(env.engine),
        tagRepositoryProvider.overrideWithValue(env.tags),
      ],
    );
  });
  tearDown(() async {
    c.dispose();
    await env.dispose();
  });

  test(
    'tagListProvider create/rename/recolor/pin/delete are reactive',
    () async {
      seedTag(env.server, 'a');
      await env.sync();
      expect(await live(tagListProvider), hasLength(1));
      final n = c.read(tagListProvider.notifier);
      List<String> names() =>
          c.read(tagListProvider).value!.map((t) => t.name).toList();

      final b = await n.create('b');
      await pumpEventQueue();
      expect(names(), ['a', 'b']);

      final renamed = await n.rename(b, 'bb');
      expect(renamed.name, 'bb');
      final colored = await n.recolor(renamed, '#abcdef');
      expect(colored.color, '#abcdef');
      final pinned = await n.setPinned(colored, true);
      expect(pinned.pinned, isTrue);
      final cleared = await n.recolor(pinned, null);
      expect(cleared.color, isNull);
      await pumpEventQueue();
      expect(names(), ['a', 'bb']);

      // Everything reaches the server.
      await env.sync();
      expect(
        env.remote.tags.values.map((t) => t['name']),
        containsAll(['a', 'bb']),
      );
      final server = env.remote.tags.values.firstWhere(
        (t) => t['name'] == 'bb',
      );
      expect(server['pinned'], isTrue);
      expect(server['color'], isNull);

      await n.delete(cleared);
      await pumpEventQueue();
      expect(names(), ['a']);
      await expectLater(n.delete(cleared), throwsA(isA<NotFoundError>()));
      await env.sync();
      expect(env.remote.tags.values.map((t) => t['name']), ['a']);
    },
  );

  test('refresh runs a manual sync', () async {
    await live(tagListProvider);
    seedTag(env.server, 'late');
    await c.read(tagListProvider.notifier).refresh();
    await pumpEventQueue();
    expect(c.read(tagListProvider).value!.single.name, 'late');
  });
}
