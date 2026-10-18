import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/sync/sync_actions.dart';

import 'sync_ui_harness.dart';

void main() {
  late SyncUiHarness h;
  late ProviderContainer c;

  setUp(() {
    h = SyncUiHarness();
    c = ProviderContainer(overrides: h.overrides);
  });
  tearDown(() async {
    c.dispose();
    await h.db.close();
  });

  test('retry makes a stuck entry due and syncs it', () async {
    await h.lane.createProject('p1', 'Alpha');
    final id = (await h.db.outboxDao.all()).single.id;
    await h.db.outboxDao.markStuck(id, error: 'boom');

    await c.read(syncActionsProvider).retry(id);

    expect(await h.db.outboxDao.all(), isEmpty);
    expect(h.handler.calls, contains('push create p1'));
    expect(h.remote.store['projects'], hasLength(1));
  });

  test('retryAll retries every failed entry', () async {
    await h.lane.createProject('p1', 'Alpha');
    await h.lane.createProject('p2', 'Beta');
    for (final e in await h.db.outboxDao.all()) {
      await h.db.outboxDao.markStuck(e.id, error: 'boom');
    }
    await c.read(syncActionsProvider).retryAll();
    expect(await h.db.outboxDao.all(), isEmpty);
    expect(h.remote.store['projects'], hasLength(2));
  });

  test('syncNow runs a cycle', () async {
    await h.lane.createProject('p1', 'Alpha');
    await c.read(syncActionsProvider).syncNow();
    expect(h.remote.store['projects'], hasLength(1));
  });

  test(
    'discard rolls back through the handler and removes the entry',
    () async {
      await h.lane.createProject('p1', 'Alpha');
      final e = (await h.db.outboxDao.all()).single;

      await c.read(syncActionsProvider).discard(e);

      expect(h.handler.calls, contains('rollback create p1'));
      expect(await h.db.outboxDao.all(), isEmpty);
      // Never on the server, so the local row is gone too.
      final rows = await h.db.customSelect('SELECT * FROM projects').get();
      expect(rows, isEmpty);
      expect(h.remote.store['projects'], isEmpty);
    },
  );

  test('discard without a handler still removes the entry', () async {
    await h.lane.createProject('p1', 'Alpha');
    final e = (await h.db.outboxDao.all()).single;
    await h.db.outboxDao.remove(e.id);
    await h.db.outboxDao.enqueue(entity: 'task', localId: 't1', op: 'create');
    final t = (await h.db.outboxDao.all()).single;
    await c.read(syncActionsProvider).discard(t);
    expect(await h.db.outboxDao.all(), isEmpty);
  });
}
