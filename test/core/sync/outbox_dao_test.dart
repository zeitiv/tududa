import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/sync/outbox_dao.dart';

void main() {
  late AppDatabase db;
  late OutboxDao dao;
  final t0 = DateTime.utc(2025, 1, 1, 12);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = db.outboxDao;
  });
  tearDown(() => db.close());

  // name -> (op, extra)
  const kinds = <String, (String, String?)>{
    'C': (OutboxOp.create, null),
    'U': (OutboxOp.update, null),
    'D': (OutboxOp.delete, null),
    'K': (OutboxOp.complete, '{"completed":true}'),
    'N': (OutboxOp.complete, '{"completed":false}'),
    'R': (OutboxOp.reorder, '{"order":1}'),
    'S': (OutboxOp.skipOccurrence, null),
    'I': (OutboxOp.inboxProcess, null),
  };

  String label(OutboxEntry e) => switch (e.op) {
    OutboxOp.create => 'C',
    OutboxOp.update => 'U',
    OutboxOp.delete => 'D',
    OutboxOp.complete => e.extraJson!.contains('false') ? 'N' : 'K',
    OutboxOp.reorder => 'R',
    OutboxOp.skipOccurrence => 'S',
    _ => 'I',
  };

  Future<int?> enq(String k, {String localId = 'x', DateTime? notBefore}) {
    final (op, extra) = kinds[k]!;
    return dao.enqueue(
      entity: SyncEntity.task,
      localId: localId,
      op: op,
      extraJson: extra,
      now: t0,
      notBefore: notBefore,
    );
  }

  Future<List<String>> queued() async => [
    for (final e in await dao.all()) label(e),
  ];

  // Expected outcome of "first then second"; anything not listed is "both
  // queued in order".
  final overrides = <String, List<String>>{
    for (final f in kinds.keys) '${f}D': ['D'],
    for (final s in kinds.keys) 'D$s': ['D'],
    'CU': ['C'],
    'CD': [],
    'UU': ['U'],
    'KK': ['K'],
    'KN': [],
    'NK': [],
    'NN': ['N'],
    'RR': ['R'],
    'SS': ['S'],
    'II': ['I'],
  };

  for (final f in kinds.keys) {
    for (final s in kinds.keys) {
      final expected = overrides['$f$s'] ?? [f, s];
      test(
        '$f then $s -> ${expected.isEmpty ? 'nothing' : expected}',
        () async {
          // The row exists so create+delete can be seen removing it.
          await db.into(db.tasks).insert(TasksCompanion.insert(localId: 'x'));
          await enq(f);
          await enq(s);
          expect(await queued(), expected);
          if ('$f$s' == 'CD') {
            expect(await db.select(db.tasks).get(), isEmpty);
          }
        },
      );
    }
  }

  test('create+update keeps the create and returns its id', () async {
    final id = await enq('C');
    expect(await enq('U'), id);
  });

  test('delete removes every earlier entry of that row, not others', () async {
    await enq('U');
    await enq('R');
    await enq('U', localId: 'other');
    await enq('D');
    final all = await dao.all();
    expect(
      [for (final e in all) '${e.localId}:${label(e)}'],
      ['other:U', 'x:D'],
    );
  });

  test(
    'update+update keeps one entry and moves not_before (debounce)',
    () async {
      await enq('U', notBefore: t0.add(const Duration(seconds: 5)));
      await enq('U', notBefore: t0.add(const Duration(seconds: 9)));
      final e = (await dao.all()).single;
      expect(e.notBefore, t0.add(const Duration(seconds: 9)));
    },
  );

  test('reorder keeps the newest extra_json', () async {
    await dao.enqueue(
      entity: 'task',
      localId: 'x',
      op: OutboxOp.reorder,
      extraJson: '{"order":1}',
      now: t0,
    );
    await dao.enqueue(
      entity: 'task',
      localId: 'x',
      op: OutboxOp.reorder,
      extraJson: '{"order":2}',
      now: t0,
    );
    expect((await dao.all()).single.extraJson, '{"order":2}');
  });

  test('an in-flight entry is never merged into', () async {
    final id = (await enq('C'))!;
    await dao.markInflight(id);
    await enq('U');
    expect(await queued(), ['C', 'U']);
    await enq('D');
    // The in-flight create stays; the new update is replaced by the delete.
    expect(await queued(), ['C', 'D']);
  });

  test('different rows and entities never coalesce', () async {
    await enq('C', localId: 'a');
    await enq('D', localId: 'b');
    await dao.enqueue(
      entity: 'note',
      localId: 'a',
      op: OutboxOp.delete,
      now: t0,
    );
    expect((await dao.all()).length, 3);
  });

  group('scheduling', () {
    test('due honours not_before and next_attempt_at, oldest first', () async {
      await enq(
        'C',
        localId: 'late',
        notBefore: t0.add(const Duration(seconds: 5)),
      );
      await enq('C', localId: 'now');
      expect([for (final e in await dao.due(t0)) e.localId], ['now']);
      expect(
        [
          for (final e in await dao.due(t0.add(const Duration(seconds: 5))))
            e.localId,
        ],
        ['late', 'now'],
      );
    });

    test('markFailed schedules a retry and counts the attempt', () async {
      final id = (await enq('C'))!;
      final at = t0.add(const Duration(seconds: 2));
      await dao.markFailed(id, error: 'boom', nextAttemptAt: at);
      expect(await dao.due(t0), isEmpty);
      expect(await dao.due(at), hasLength(1));
      final e = (await dao.byId(id))!;
      expect(
        (e.state, e.attempts, e.lastError),
        (OutboxState.failed, 1, 'boom'),
      );
      expect(await dao.nextDueAfter(t0), at);
      expect(await dao.nextDueAfter(at), isNull);
    });

    test('stuck entries are not due until retryNow', () async {
      final id = (await enq('C'))!;
      await dao.markStuck(id, error: 'x');
      expect(await dao.due(t0), isEmpty);
      expect(await dao.due(t0, includeStuck: true), hasLength(1));
      expect(await dao.pending(), isEmpty);
      await dao.retryNow();
      final e = (await dao.byId(id))!;
      expect((e.state, e.attempts), (OutboxState.pending, 0));
      expect(await dao.due(t0), hasLength(1));
    });

    test('recoverInflight and counts', () async {
      final a = (await enq('C', localId: 'a'))!;
      final b = (await enq('C', localId: 'b'))!;
      final c = (await enq('C', localId: 'c'))!;
      await dao.markInflight(a);
      await dao.markFailed(b, error: 'e', nextAttemptAt: t0);
      await dao.markStuck(c, error: 'e');
      expect(
        await dao.countsNow(),
        const OutboxCounts(pending: 1, failed: 1, stuck: 1),
      );
      await dao.recoverInflight();
      expect((await dao.byId(a))!.state, OutboxState.pending);
    });

    test('counts() streams changes; cancel removes', () async {
      final seen = <OutboxCounts>[];
      final sub = dao.counts().listen(seen.add);
      await pumpEventQueue();
      final id = (await enq('C'))!;
      await pumpEventQueue();
      await dao.cancel(id);
      await pumpEventQueue();
      await sub.cancel();
      expect(seen.map((c) => c.pending), [0, 1, 0]);
    });
  });
}
