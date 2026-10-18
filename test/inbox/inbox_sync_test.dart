import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/sync/sync_engine.dart';
import 'package:tududa/core/sync/sync_handler.dart';
import 'package:tududa/core/time/user_clock.dart';
import 'package:tududa/core/ids.dart';
import 'package:tududa/inbox/data/inbox_api.dart';
import 'package:tududa/inbox/data/inbox_dao.dart';
import 'package:tududa/inbox/data/inbox_sync_handler.dart';
import 'package:tududa/inbox/data/offline_inbox_repository.dart';
import 'package:tududa/inbox/domain/inbox_item.dart';

import '../support/api_stack.dart';
import '../support/fake_tududi/routes/inbox_routes.dart';
import 'inbox_support.dart';

class _NoTimer implements Timer {
  @override
  void cancel() {}
  @override
  bool get isActive => false;
  @override
  int get tick => 0;
}

class Harness {
  late final TestStack stack;
  late final AppDatabase db;
  late final SyncEngine engine;
  late final OfflineInboxRepository repo;
  late final InboxDao dao;
  final handler = InboxSyncHandler();
  bool online = true;

  static Future<Harness> create({int seed = 0}) async {
    final h = Harness();
    h.stack = await inboxStack(seed: seed);
    h.db = AppDatabase.forTesting(NativeDatabase.memory());
    h.dao = InboxDao(h.db);
    h.repo = OfflineInboxRepository(h.db, InboxApi(h.stack.dio));
    h.engine = SyncEngine(
      db: h.db,
      handlers: [h.handler],
      dio: () => h.stack.dio,
      clock: UserClock(zoneName: 'UTC'),
      reauthenticate: () async => false,
      isOnline: () => h.online,
      createTimer: (_, _) => _NoTimer(),
    );
    addTearDown(() async {
      await h.engine.dispose();
      await h.db.close();
    });
    return h;
  }

  FakeInboxStore get server => inboxStoreOf(stack.server);

  Future<void> sync([SyncReason r = SyncReason.connectivity]) =>
      engine.requestSync(r);

  SyncContext ctx() => SyncContext(
    db: db,
    dio: () => stack.dio,
    clock: UserClock(zoneName: 'UTC'),
    now: DateTime.now().toUtc(),
  );

  Future<List<InboxRow>> rows() => db.select(db.inboxItems).get();
  Future<List<OutboxEntry>> outbox() => db.outboxDao.all();
  Future<List<InboxItem>> visible() async => [
    for (final r in await dao.visible()) OfflineInboxRepository.toItem(r),
  ];
  int count(String method, String path) => stack.count(method, path);
}

void main() {
  test('capture offline is visible at once; sync fills the uid', () async {
    final h = await Harness.create();
    h.online = false;
    final item = await h.repo.capture('Buy milk');
    expect((await h.visible()).single.content, 'Buy milk');
    expect(item.uid.value, (await h.rows()).single.localId);
    await h.sync();
    expect(h.count('POST', '/inbox'), 0);
    expect(await h.outbox(), hasLength(1));

    h.online = true;
    await h.sync();
    final row = (await h.rows()).single;
    expect(row.uid, h.server.items.single['uid']);
    expect(row.dirtyFields, '{}');
    expect(await h.outbox(), isEmpty);
    expect(h.stack.server.requests.lastWhere((r) => r.method == 'POST').body, {
      'content': 'Buy milk',
      'source': 'mobile',
    });
    expect(await h.visible(), hasLength(1)); // not duplicated by the pull
  });

  test('ignore offline is sent as PATCH {status}', () async {
    final h = await Harness.create(seed: 1);
    await h.sync();
    h.online = false;
    await h.repo.ignore(const InboxUid('inbox-1'));
    expect((await h.visible()).single.status, InboxStatus.ignored);
    h.online = true;
    await h.sync();
    expect(h.server.items.single['status'], 'ignored');
    expect(h.stack.server.requests.lastWhere((r) => r.method == 'PATCH').body, {
      'status': 'ignored',
    });
    final row = (await h.rows()).single;
    expect(row.dirtyFields, '{}');
    expect(await h.outbox(), isEmpty);
  });

  test('capture then ignore offline: created, then ignored', () async {
    final h = await Harness.create();
    h.online = false;
    final item = await h.repo.capture('Later');
    await h.repo.ignore(item.uid);
    expect(await h.outbox(), hasLength(1)); // update absorbed into create
    h.online = true;
    await h.sync();
    expect(h.server.items.single['status'], 'ignored');
    expect((await h.rows()).single.dirtyFields, '{}');
  });

  test('delete offline hides the item, then soft-deletes', () async {
    final h = await Harness.create(seed: 2);
    await h.sync();
    h.online = false;
    await h.repo.delete(const InboxUid('inbox-1'));
    expect((await h.visible()).map((i) => i.uid.value), ['inbox-2']);
    h.online = true;
    await h.sync();
    expect(h.server.items.first['status'], 'deleted');
    expect((await h.rows()).map((r) => r.uid), ['inbox-2']);
    expect(await h.outbox(), isEmpty);
  });

  test('capture then delete offline cancels both', () async {
    final h = await Harness.create();
    h.online = false;
    final item = await h.repo.capture('Oops');
    await h.repo.delete(item.uid);
    expect(await h.rows(), isEmpty);
    expect(await h.outbox(), isEmpty);
    h.online = true;
    await h.sync();
    expect(h.count('POST', '/inbox'), 0);
  });

  test(
    'process to a task that is not synced yet waits, then succeeds',
    () async {
      final h = await Harness.create(seed: 1);
      await h.sync();
      await h.db
          .into(h.db.tasks)
          .insert(TasksCompanion.insert(localId: 'task-local'));
      await h.repo.process(
        const InboxUid('inbox-1'),
        target: const ProcessedAsTask('task-local'),
      );
      expect(await h.visible(), isEmpty);

      await h.sync();
      expect(h.count('PATCH', '/inbox/inbox-1/process'), 0);
      final entry = (await h.outbox()).single;
      expect(entry.op, OutboxOp.inboxProcess);
      expect(entry.attempts, 0);
      expect(entry.state, OutboxState.pending);

      // The task's create got pushed in the meantime.
      await (h.db.update(h.db.tasks)
            ..where((t) => t.localId.equals('task-local')))
          .write(const TasksCompanion(uid: Value('task-9')));
      await h.sync();
      final req = h.stack.server.requests.lastWhere(
        (r) => r.path == '/inbox/inbox-1/process',
      );
      expect(req.body, {'task_uid': 'task-9'});
      expect(await h.outbox(), isEmpty);
      expect(await h.rows(), isEmpty);
      expect(h.server.items.single['status'], 'processed');
    },
  );

  test(
    'capture then process offline: create first, then the process',
    () async {
      final h = await Harness.create();
      h.online = false;
      final item = await h.repo.capture('Plan trip');
      await h.repo.process(
        item.uid,
        target: const ProcessedAsNote('note-uid-1'),
      );
      h.online = true;
      await h.sync();
      final uid = h.server.items.single['uid'];
      expect(h.server.items.single['status'], 'processed');
      expect(
        h.stack.server.requests.lastWhere((r) => r.method == 'PATCH').body,
        {'note_uid': 'note-uid-1'},
      );
      expect(
        h.stack.server.requests.last.path == '/inbox/$uid/process' ||
            h.count('PATCH', '/inbox/$uid/process') == 1,
        isTrue,
      );
      expect(await h.outbox(), isEmpty);
    },
  );

  test('server 404 rolls back and reports a notice', () async {
    final h = await Harness.create();
    await h.repo.capture('Doomed');
    await h.sync();
    h.server.items.clear(); // deleted on the web meanwhile
    await h.repo.ignore(InboxUid((await h.rows()).single.uid!));
    await h.sync();
    expect(await h.rows(), isEmpty);
    expect(await h.outbox(), isEmpty);
    expect(h.engine.status.notices, hasLength(1));
    expect(h.engine.status.notices.single.field, '*');
  });

  test('server 422 restores the last server state', () async {
    final h = await Harness.create(seed: 1);
    await h.sync();
    await h.repo.ignore(const InboxUid('inbox-1'));
    h.stack.server.failNext('/inbox/inbox-1', 422);
    await h.sync();
    final row = (await h.rows()).single;
    expect(row.status, 'added');
    expect(row.dirtyFields, '{}');
    expect(await h.outbox(), isEmpty);
    expect(h.engine.status.notices, hasLength(1));
  });

  test('pull keeps rows with local edits (merged field by field)', () async {
    final h = await Harness.create(seed: 2);
    await h.sync();
    h.online = false;
    await h.repo.ignore(const InboxUid('inbox-1'));
    h.server.items[0]['content'] = 'Edited on the web';
    h.server.items[1]['content'] = 'Other edit';

    await h.handler.pull(h.ctx());
    final byUid = {for (final r in await h.rows()) r.uid: r};
    final dirty = byUid['inbox-1']!;
    expect(dirty.status, 'ignored'); // local edit kept
    expect(dirty.dirtyFields, contains('status'));
    expect(dirty.content, 'Edited on the web'); // server edit taken
    expect(byUid['inbox-2']!.content, 'Other edit'); // clean row replaced
    expect(await h.outbox(), hasLength(1));
  });

  test(
    'fullReconcile removes clean rows the server lost, keeps dirty',
    () async {
      final h = await Harness.create(seed: 3);
      await h.sync();
      await h.repo.ignore(const InboxUid('inbox-2'));
      final lost = h.server.items.where((r) => r['uid'] != 'inbox-3').toList();
      h.server.items.removeWhere((r) => lost.contains(r));
      await h.handler.fullReconcile(h.ctx());
      expect((await h.rows()).map((r) => r.uid).toSet(), {
        'inbox-2',
        'inbox-3',
      });
    },
  );

  test('processed items the server returns are not shown', () async {
    final h = await Harness.create();
    h.server.add('Gone', status: 'processed');
    h.server.add('Kept');
    await h.sync();
    expect((await h.visible()).map((i) => i.content), ['Kept']);
  });

  test('pull pages through more than one server page', () async {
    final h = await Harness.create(seed: 130);
    await h.sync();
    expect(await h.rows(), hasLength(130));
    final offsets = h.stack.server.requests
        .where((r) => r.method == 'GET' && r.path == '/inbox')
        .map((r) => r.query['offset']);
    expect(offsets, containsAll(['0', '100']));
  });
}
