import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart' show addTearDown;
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/sync/retry_policy.dart';
import 'package:tududa/core/sync/sync_engine.dart';
import 'package:tududa/core/sync/sync_handler.dart';
import 'package:tududa/core/time/user_clock.dart';
import 'package:tududa/tasks/data/offline_task_repository.dart';
import 'package:tududa/tasks/data/task_dao.dart';
import 'package:tududa/tasks/data/task_sync_handler.dart';
import 'package:tududa/tasks/domain/task_views.dart';

import '../support/api_stack.dart';
import 'task_test_support.dart';

class _NoTimer implements Timer {
  @override
  void cancel() {}
  @override
  bool get isActive => false;
  @override
  int get tick => 0;
}

/// An in-memory database, the offline repository, the real `SyncEngine` with
/// `TaskSyncHandler`, and a fake Tududi behind the production Dio stack. Time
/// is [t]; move it with [advance].
class OfflineRig {
  OfflineRig({String zone = 'UTC'}) : net = TaskTestRig() {
    t = DateTime.now().toUtc();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    dao = TaskDao(db);
    clock = UserClock(now: () => t, zoneName: zone);
    repo = OfflineTaskRepository(db, now: () => t, day: () => today());
    handler = TaskSyncHandler();
    engine = SyncEngine(
      db: db,
      handlers: [handler],
      dio: () => net.stack.dio,
      clock: clock,
      reauthenticate: () async => false,
      now: () => t,
      retryPolicy: RetryPolicy(random: FixedRandom()),
      createTimer: (d, cb) => _NoTimer(),
    );
    addTearDown(engine.dispose);
  }

  final TaskTestRig net;
  late DateTime t;
  late final AppDatabase db;
  late final TaskDao dao;
  late final UserClock clock;
  late final OfflineTaskRepository repo;
  late final TaskSyncHandler handler;
  late final SyncEngine engine;

  Future<void> init() async {
    await net.login();
    await engine.start();
  }

  TaskDay today() => TaskDay.fromClock(clock);

  void advance(Duration d) => t = t.add(d);

  /// One manual sync cycle (ignores the undo window unless [t] is earlier
  /// than the entries' `not_before`).
  Future<void> sync() => engine.requestSync(SyncReason.manual);

  /// Moves past the undo window, then syncs.
  Future<void> flush() {
    advance(const Duration(seconds: 6));
    return sync();
  }

  Future<List<OutboxEntry>> outbox() => db.outboxDao.all();

  Future<TaskRow> row(String idOrUid) async => (await dao.byAnyId(idOrUid))!;
}
