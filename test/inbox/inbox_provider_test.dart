import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/api/api_providers.dart';
import 'package:tududa/core/ids.dart';
import 'package:tududa/inbox/domain/inbox_item.dart';
import 'package:tududa/inbox/providers/inbox_provider.dart';

import '../support/api_stack.dart';
import 'inbox_support.dart';

Future<(ProviderContainer, TestStack)> setup({int seed = 0}) async {
  final stack = await inboxStack(seed: seed);
  final c = ProviderContainer(
    overrides: [dioProvider.overrideWithValue(stack.dio)],
  );
  addTearDown(c.dispose);
  await c.read(inboxProvider.future);
  return (c, stack);
}

void main() {
  test('loads the first page, then loadMore appends the next', () async {
    final (c, stack) = await setup(seed: 25);
    var list = c.read(inboxProvider).requireValue;
    expect(list.items, hasLength(inboxPageSize));
    expect(list.total, 25);
    expect(list.hasMore, isTrue);

    await c.read(inboxProvider.notifier).loadMore();
    list = c.read(inboxProvider).requireValue;
    expect(list.items, hasLength(25));
    expect(list.hasMore, isFalse);
    expect(list.items.map((i) => i.uid).toSet(), hasLength(25));

    await c.read(inboxProvider.notifier).loadMore(); // no-op
    expect(stack.count('GET', '/inbox'), 2);
  });

  test('capture puts the new item first', () async {
    final (c, stack) = await setup(seed: 2);
    final ok = await c.read(inboxProvider.notifier).capture(' Walk dog ');
    expect(ok, isTrue);
    final list = c.read(inboxProvider).requireValue;
    expect(list.items.first.content, 'Walk dog');
    expect(list.total, 3);
    expect(stack.server.requests.lastWhere((r) => r.method == 'POST').body, {
      'content': 'Walk dog',
      'source': 'mobile',
    });
    expect(await c.read(inboxProvider.notifier).capture('   '), isFalse);
  });

  test('process removes the item and hits /process', () async {
    final (c, stack) = await setup(seed: 2);
    final n = c.read(inboxProvider.notifier);
    expect(await n.process(const InboxUid('inbox-1')), isTrue);
    expect(c.read(inboxProvider).requireValue.items.map((i) => i.uid.value), [
      'inbox-2',
    ]);
    expect(stack.count('PATCH', '/inbox/inbox-1/process'), 1);
  });

  test('ignore keeps the item, marked ignored', () async {
    final (c, stack) = await setup(seed: 1);
    expect(
      await c.read(inboxProvider.notifier).ignore(const InboxUid('inbox-1')),
      isTrue,
    );
    final item = c.read(inboxProvider).requireValue.items.single;
    expect(item.status, InboxStatus.ignored);
    expect(stack.server.requests.last.body, {'status': 'ignored'});
  });

  test('delete removes; a failure reloads and reports false', () async {
    final (c, stack) = await setup(seed: 2);
    final n = c.read(inboxProvider.notifier);
    expect(await n.delete(const InboxUid('inbox-1')), isTrue);
    expect(c.read(inboxProvider).requireValue.items, hasLength(1));

    stack.server.failNext('/inbox/inbox-2', 404);
    expect(await n.delete(const InboxUid('inbox-2')), isFalse);
    // refresh restored the server truth (item 2 still exists server-side).
    expect(
      c.read(inboxProvider).requireValue.items.single.uid.value,
      'inbox-2',
    );
  });
}
