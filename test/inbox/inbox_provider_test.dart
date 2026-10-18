import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/api/api_providers.dart';
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/ids.dart';
import 'package:tududa/inbox/domain/inbox_item.dart';
import 'package:tududa/inbox/providers/inbox_provider.dart';

import '../support/api_stack.dart';
import 'inbox_support.dart';

Future<(ProviderContainer, TestStack, AppDatabase)> setup({
  int seed = 0,
}) async {
  final stack = await inboxStack(seed: seed);
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  final c = ProviderContainer(
    overrides: [
      dioProvider.overrideWithValue(stack.dio),
      appDatabaseProvider.overrideWithValue(db),
    ],
  );
  addTearDown(c.dispose);
  await c.read(inboxProvider.future);
  await c.read(inboxProvider.notifier).initialLoad;
  await pumpEventQueue();
  return (c, stack, db);
}

void main() {
  test('loads the first page, then loadMore pages the server', () async {
    final (c, stack, db) = await setup(seed: 25);
    var list = c.read(inboxProvider).requireValue;
    expect(list.items, hasLength(inboxPageSize));
    expect(list.total, 25);
    expect(list.hasMore, isTrue);

    await c.read(inboxProvider.notifier).loadMore();
    await pumpEventQueue();
    list = c.read(inboxProvider).requireValue;
    expect(list.items, hasLength(25));
    expect(list.hasMore, isFalse);
    expect(list.loadingMore, isFalse);
    expect(list.items.map((i) => i.uid).toSet(), hasLength(25));
    // Newest first, as the server orders it.
    expect(list.items.first.uid.value, 'inbox-25');

    await c.read(inboxProvider.notifier).loadMore(); // no-op
    expect(stack.count('GET', '/inbox'), 2);
    expect(await db.select(db.inboxItems).get(), hasLength(25));
  });

  test('offline: the local rows stay, loadMore fails quietly', () async {
    final (c, stack, _) = await setup(seed: 25);
    stack.server.failNextConnection('/inbox', times: 10);
    await c.read(inboxProvider.notifier).loadMore();
    final list = c.read(inboxProvider).requireValue;
    expect(list.items, hasLength(inboxPageSize));
    expect(list.loadingMore, isFalse);
  });

  test('capture works offline: first in the list, no request', () async {
    final (c, stack, _) = await setup(seed: 2);
    final posts = stack.count('POST', '/inbox');
    final ok = await c.read(inboxProvider.notifier).capture(' Walk dog ');
    expect(ok, isTrue);
    await pumpEventQueue();
    final list = c.read(inboxProvider).requireValue;
    expect(list.items.first.content, 'Walk dog');
    expect(list.items.first.source, 'mobile');
    expect(list.total, 3);
    expect(stack.count('POST', '/inbox'), posts);
    expect(await c.read(inboxProvider.notifier).capture('   '), isFalse);
  });

  test('process hides the item at once and queues inbox_process', () async {
    final (c, stack, db) = await setup(seed: 2);
    final n = c.read(inboxProvider.notifier);
    expect(await n.process(const InboxUid('inbox-1')), isTrue);
    await pumpEventQueue();
    expect(c.read(inboxProvider).requireValue.items.map((i) => i.uid.value), [
      'inbox-2',
    ]);
    expect(stack.count('PATCH', '/inbox/inbox-1/process'), 0);
    final entries = await db.outboxDao.all();
    expect(entries.single.op, OutboxOp.inboxProcess);
  });

  test('ignore keeps the item, marked ignored', () async {
    final (c, _, db) = await setup(seed: 1);
    expect(
      await c.read(inboxProvider.notifier).ignore(const InboxUid('inbox-1')),
      isTrue,
    );
    await pumpEventQueue();
    final item = c.read(inboxProvider).requireValue.items.single;
    expect(item.status, InboxStatus.ignored);
    expect((await db.outboxDao.all()).single.op, OutboxOp.update);
  });

  test('delete removes the item and queues the delete', () async {
    final (c, _, db) = await setup(seed: 2);
    final n = c.read(inboxProvider.notifier);
    expect(await n.delete(const InboxUid('inbox-1')), isTrue);
    await pumpEventQueue();
    expect(c.read(inboxProvider).requireValue.items, hasLength(1));
    expect((await db.outboxDao.all()).single.op, OutboxOp.delete);
  });
}
