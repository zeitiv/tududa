import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/sync/retry_policy.dart';
import 'package:tududa/core/sync/sync_engine.dart';
import 'package:tududa/core/sync/sync_handler.dart';
import 'package:tududa/core/sync/sync_status.dart';
import 'package:tududa/core/time/user_clock.dart';

import '../../support/api_stack.dart';
import '../../support/fake_tududi/fake_tududi.dart';
import 'support/fake_entity_handler.dart';
import 'support/fake_lane.dart';

class _NoTimer implements Timer {
  _NoTimer(this.delay);
  final Duration delay;
  @override
  void cancel() {}
  @override
  bool get isActive => false;
  @override
  int get tick => 0;
}

class Harness {
  Harness() {
    server = FakeTududi();
    remote = FakeEntityServer(server)..now = () => t;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    lane = FakeLane(db, () => t);
    final dio = plainDio(server);
    engine = SyncEngine(
      db: db,
      // Deliberately in the wrong order: the engine sorts them.
      handlers: [notes, projects],
      dio: () => dio,
      clock: UserClock(now: () => t, zoneName: 'UTC'),
      reauthenticate: () async {
        reauthCalls++;
        return reauthResult;
      },
      isOnline: () => online,
      now: () => t,
      retryPolicy: RetryPolicy(random: FixedRandom()),
      createTimer: (d, cb) {
        final timer = _NoTimer(d);
        timers.add(timer);
        return timer;
      },
    );
  }

  late final FakeTududi server;
  late final FakeEntityServer remote;
  late final AppDatabase db;
  late final FakeLane lane;
  late final SyncEngine engine;
  final projects = FakeEntityHandler(SyncEntity.project);
  final notes = FakeEntityHandler(SyncEntity.note);
  final timers = <_NoTimer>[];
  DateTime t = DateTime.utc(2025, 1, 1, 12);
  bool online = true;
  bool reauthResult = true;
  int reauthCalls = 0;

  Future<void> start() => engine.start();
  void advance(Duration d) => t = t.add(d);

  int posts(String path) => remote.requests('POST', '/fake/$path/new');
  int gets(String path) => remote.requests('GET', '/fake/$path');

  Future<List<OutboxEntry>> outbox() => db.outboxDao.all();

  void seed(String path, String uid, String name, {DateTime? updatedAt}) {
    remote.store[path]![uid] = {
      'id': server.nextId(),
      'uid': uid,
      'name': name,
      'updated_at': (updatedAt ?? t).toIso8601String(),
    };
  }

  Future<void> dispose() async {
    await engine.dispose();
    await db.close();
  }
}

void main() {
  late Harness h;
  setUp(() async {
    h = Harness();
    await h.start();
  });
  tearDown(() => h.dispose());

  test(
    'create offline -> online push fills uid and clears the queue',
    () async {
      h.online = false;
      await h.lane.createProject('p1', 'Home');
      await h.engine.requestSync(SyncReason.write);
      expect(h.server.requests, isEmpty);
      expect(h.engine.status.phase, SyncPhase.offline);
      await pumpEventQueue();
      expect(h.engine.status.pendingCount, 1);

      h.online = true;
      await h.engine.requestSync(SyncReason.connectivity);
      final p = (await h.lane.project('p1'))!;
      expect(p.uid, startsWith('projects-'));
      expect(p.serverId, isNotNull);
      expect(p.dirtyFields, '{}');
      expect(p.baseJson, contains('Home'));
      expect(await h.outbox(), isEmpty);
      expect(h.remote.store['projects']!.values.single['name'], 'Home');
      expect(h.engine.status.phase, SyncPhase.idle);
      expect(h.engine.status.lastSyncAt, h.t);
    },
  );

  test('offline cycles make no request, manual sync does', () async {
    h.online = false;
    await h.engine.requestSync(SyncReason.timer);
    expect(h.server.requests, isEmpty);
    expect(h.engine.status.phase, SyncPhase.offline);
    await h.engine.requestSync(SyncReason.manual);
    expect(h.gets('projects'), 1);
  });

  test('status stream: syncing then idle', () async {
    final phases = <SyncPhase>[];
    h.engine.statuses.map((s) => s.phase).listen((p) {
      if (phases.isEmpty || phases.last != p) phases.add(p);
    });
    await h.lane.createProject('p1', 'Home');
    await h.engine.requestSync(SyncReason.write);
    expect(phases, [SyncPhase.syncing, SyncPhase.idle]);

    h.online = false;
    await h.engine.requestSync(SyncReason.timer);
    expect(phases.last, SyncPhase.offline);
  });

  test(
    'a child created before its parent has a uid waits for a later cycle',
    () async {
      await h.lane.createProject(
        'p1',
        'Parent',
        undo: const Duration(seconds: 5),
      );
      await h.lane.createNote('n1', 'Child', projectLocalId: 'p1');
      await h.engine.requestSync(SyncReason.write);

      expect(h.posts('notes'), 0);
      expect(h.posts('projects'), 0);
      final waiting = (await h.outbox()).singleWhere((e) => e.localId == 'n1');
      expect((waiting.state, waiting.attempts), (OutboxState.pending, 0));
      expect(h.timers.last.delay, const Duration(seconds: 5));

      h.advance(const Duration(seconds: 6));
      await h.engine.requestSync(SyncReason.scheduled);
      expect(await h.outbox(), isEmpty);
      final parentUid = (await h.lane.project('p1'))!.uid;
      expect((await h.lane.note('n1'))!.uid, startsWith('notes-'));
      expect(h.remote.store['notes']!.values.single['parent_uid'], parentUid);
    },
  );

  test(
    'a dependency created later in the queue is resolved in the same cycle',
    () async {
      await h.lane.createNote('n1', 'Child', projectLocalId: 'p1');
      await h.lane.createProject('p1', 'Parent');
      await h.engine.requestSync(SyncReason.write);
      expect(await h.outbox(), isEmpty);
      expect(h.posts('projects'), 1);
      expect(h.posts('notes'), 1);
      expect(h.notes.calls.where((c) => c == 'push create n1'), hasLength(2));
    },
  );

  test('transient 5xx is retried with backoff', () async {
    await h.lane.createProject('p1', 'Home');
    h.server.failNext('/fake/projects/new', 503);
    await h.engine.requestSync(SyncReason.write);

    var e = (await h.outbox()).single;
    expect((e.state, e.attempts), (OutboxState.failed, 1));
    expect(e.nextAttemptAt, h.t.add(const Duration(seconds: 2)));
    expect(h.engine.status.phase, SyncPhase.error);
    expect(h.engine.status.failedCount, 1);
    expect(h.timers.last.delay, const Duration(seconds: 2));

    h.advance(const Duration(seconds: 1));
    await h.engine.requestSync(SyncReason.timer);
    expect(h.posts('projects'), 1);

    h.advance(const Duration(seconds: 2));
    await h.engine.requestSync(SyncReason.scheduled);
    expect(h.posts('projects'), 2);
    expect(await h.outbox(), isEmpty);
    expect(h.engine.status.phase, SyncPhase.idle);
  });

  test(
    'ten failed attempts make the entry stuck; manual sync revives it',
    () async {
      await h.lane.createProject('p1', 'Home');
      for (var i = 0; i < 10; i++) {
        h.server.failNext('/fake/projects/new', 503);
        await h.engine.requestSync(SyncReason.scheduled);
        h.advance(const Duration(minutes: 6));
      }
      final e = (await h.outbox()).single;
      expect((e.state, e.attempts), (OutboxState.stuck, 10));
      await pumpEventQueue();
      expect(h.engine.status.stuckCount, 1);

      await h.engine.requestSync(SyncReason.timer);
      expect(h.posts('projects'), 10);

      await h.engine.requestSync(SyncReason.manual);
      expect(h.posts('projects'), 11);
      expect(await h.outbox(), isEmpty);
    },
  );

  test(
    '400 on create rolls back, removes the entry and reports a notice',
    () async {
      await h.lane.createProject('p1', 'bad');
      await h.engine.requestSync(SyncReason.write);
      expect(await h.lane.project('p1'), isNull);
      expect(await h.outbox(), isEmpty);
      expect(h.projects.calls, contains('rollback create p1'));
      final n = h.engine.status.notices.single;
      expect((n.entity, n.localId, n.field), ('project', 'p1', '*'));
      expect(h.engine.status.phase, SyncPhase.idle);
    },
  );

  test(
    '422 on update restores base_json; 404 on update drops the row',
    () async {
      await h.lane.createProject('p1', 'Home');
      await h.engine.requestSync(SyncReason.write);
      await h.lane.renameProject('p1', 'bad');
      await h.engine.requestSync(SyncReason.write);
      var p = (await h.lane.project('p1'))!;
      expect((p.name, p.dirtyFields), ('Home', '{}'));
      expect(await h.outbox(), isEmpty);

      await h.lane.renameProject('p1', 'Other');
      h.remote.store['projects']!.clear();
      await h.engine.requestSync(SyncReason.write);
      // The pull's reconcile left the dirty row; the PATCH hit 404.
      expect(await h.lane.project('p1'), isNull);
      expect(await h.outbox(), isEmpty);
    },
  );

  test('401 triggers one re-authentication and the push succeeds', () async {
    await h.lane.createProject('p1', 'Home');
    h.server.failNext('/fake/projects/new', 401);
    await h.engine.requestSync(SyncReason.write);
    expect(h.reauthCalls, 1);
    expect(await h.outbox(), isEmpty);
    expect(h.posts('projects'), 2);
    expect(h.engine.status.phase, SyncPhase.idle);
  });

  test(
    'failed re-authentication pauses the queue and keeps every entry',
    () async {
      h.reauthResult = false;
      await h.lane.createProject('p1', 'Home');
      await h.lane.createNote('n1', 'Note');
      h.server.failNext('/fake/projects/new', 401);
      await h.engine.requestSync(SyncReason.write);

      expect(h.engine.status.phase, SyncPhase.signedOut);
      expect(h.reauthCalls, 1);
      final entries = await h.outbox();
      expect(entries, hasLength(2));
      expect(entries.every((e) => e.state == OutboxState.pending), isTrue);
      expect(entries.every((e) => e.attempts == 0), isTrue);

      final before = h.server.requests.length;
      await h.engine.requestSync(SyncReason.timer);
      await h.engine.requestSync(SyncReason.write);
      expect(h.server.requests.length, before);
      expect(h.reauthCalls, 1);

      h.reauthResult = true;
      await h.engine.requestSync(SyncReason.manual);
      expect(await h.outbox(), isEmpty);
      expect(h.engine.status.phase, SyncPhase.idle);
    },
  );

  test('401 while pulling pauses as signed out and keeps the queue', () async {
    h.reauthResult = false;
    await h.lane.createProject('p1', 'Home');
    h.server.failNext('/fake/projects', 401);
    await h.engine.requestSync(SyncReason.write);
    expect(h.engine.status.phase, SyncPhase.signedOut);
    expect(await h.outbox(), hasLength(1));
    expect(h.posts('projects'), 0);
  });

  test('overlapping requests coalesce into one follow-up cycle', () async {
    h.server.latency = const Duration(milliseconds: 10);
    final all = Future.wait([
      h.engine.requestSync(SyncReason.write),
      h.engine.requestSync(SyncReason.timer),
      h.engine.requestSync(SyncReason.resume),
    ]);
    await all;
    expect(h.gets('projects'), 2);
    expect(h.gets('notes'), 2);
  });

  test('pulls run in dependency order: projects before notes', () async {
    await h.engine.requestSync(SyncReason.write);
    final gets = h.server.requests
        .where((r) => r.method == 'GET')
        .map((r) => r.path)
        .toList();
    expect(gets, ['/fake/projects', '/fake/notes']);
  });

  test(
    'login does a full reconcile that removes clean rows the server lost',
    () async {
      h.seed('projects', 'projects-a', 'Alpha');
      h.seed('projects', 'projects-b', 'Beta');
      await h.engine.requestSync(SyncReason.login);
      expect(h.projects.calls, ['fullReconcile']);
      expect((await h.db.select(h.db.projects).get()), hasLength(2));

      // Beta is deleted remotely; Alpha has an unsent local edit.
      h.remote.store['projects']!.remove('projects-b');
      h.remote.store['projects']!.remove('projects-a');
      await h.lane.renameProject(
        'pulled-projects-a',
        'Mine',
        undo: const Duration(hours: 1),
      );
      await h.engine.requestSync(SyncReason.login);
      final left = await h.db.select(h.db.projects).get();
      expect(left.map((r) => r.localId), ['pulled-projects-a']);
    },
  );

  test(
    'full reconcile also runs when the last one is older than 6 hours',
    () async {
      await h.engine.requestSync(SyncReason.timer);
      expect(h.projects.calls, ['fullReconcile']);
      h.advance(const Duration(hours: 5));
      await h.engine.requestSync(SyncReason.timer);
      expect(h.projects.calls, ['fullReconcile', 'pull']);
      h.advance(const Duration(hours: 2));
      await h.engine.requestSync(SyncReason.timer);
      expect(h.projects.calls.last, 'fullReconcile');
    },
  );

  test('pull keeps local edits and merges the rest', () async {
    h.seed('projects', 'projects-a', 'Server');
    await h.engine.requestSync(SyncReason.login);
    await h.lane.renameProject(
      'pulled-projects-a',
      'Mine',
      undo: const Duration(hours: 1),
    );

    await h.engine.requestSync(SyncReason.timer);
    var p = (await h.lane.project('pulled-projects-a'))!;
    expect(p.name, 'Mine');
    expect(p.dirtyFields, isNot('{}'));

    // The server changed it later than our edit: the server wins.
    h.advance(const Duration(minutes: 1));
    h.seed('projects', 'projects-a', 'Theirs', updatedAt: h.t);
    h.remote.store['projects']!['projects-a']!['id'] = p.serverId;
    h.advance(const Duration(hours: 2));
    await h.engine.requestSync(SyncReason.timer);
    p = (await h.lane.project('pulled-projects-a'))!;
    expect((p.name, p.dirtyFields), ('Theirs', '{}'));
    expect(h.engine.status.notices.single.field, 'name');
    // The queued update has nothing left to send and is dropped.
    expect(await h.outbox(), isEmpty);
    expect(h.remote.requests('PATCH', '/fake/projects/projects-a'), 0);
  });

  test('create then delete offline sends nothing', () async {
    await h.lane.createProject('p1', 'Home');
    await h.lane.deleteProject('p1');
    expect(await h.outbox(), isEmpty);
    await h.engine.requestSync(SyncReason.write);
    expect(h.posts('projects'), 0);
    expect(await h.lane.project('p1'), isNull);
  });

  test('a network error mid-push marks offline and keeps the entry', () async {
    await h.lane.createProject('p1', 'Home');
    h.server.failNextConnection('/fake/projects/new');
    await h.engine.requestSync(SyncReason.write);
    expect(h.engine.status.phase, SyncPhase.offline);
    expect((await h.outbox()).single.state, OutboxState.failed);
  });

  test('account change wipes everything and resets the status', () async {
    await h.lane.createProject('p1', 'Home');
    await h.lane.createNote('n1', 'queued', projectLocalId: 'zzz');
    await h.engine.requestSync(SyncReason.write);
    expect(await h.db.select(h.db.projects).get(), isNotEmpty);
    expect(await h.outbox(), isNotEmpty);

    await h.engine.onAccountChanged();
    expect(await h.db.select(h.db.projects).get(), isEmpty);
    expect(await h.db.select(h.db.notes).get(), isEmpty);
    expect(await h.db.select(h.db.syncStates).get(), isEmpty);
    expect(await h.outbox(), isEmpty);
    expect(h.engine.status.pendingCount, 0);
    expect(h.engine.status.lastSyncAt, isNull);
    expect(h.engine.status.phase, SyncPhase.idle);
  });

  test('syncStatusProvider mirrors the engine', () async {
    final container = ProviderContainer(
      overrides: [syncEngineProvider.overrideWithValue(h.engine)],
    );
    addTearDown(container.dispose);
    expect(container.read(syncStatusProvider).phase, SyncPhase.idle);
    h.online = false;
    await h.engine.requestSync(SyncReason.timer);
    expect(container.read(syncStatusProvider).phase, SyncPhase.offline);
  });
}
