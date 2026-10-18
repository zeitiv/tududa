import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tududa/areas/data/area_sync_handler.dart';
import 'package:tududa/areas/data/offline_area_repository.dart';
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/sync/retry_policy.dart';
import 'package:tududa/core/sync/sync_engine.dart';
import 'package:tududa/core/sync/sync_handler.dart';
import 'package:tududa/core/time/user_clock.dart';
import 'package:tududa/projects/data/offline_project_repository.dart';
import 'package:tududa/projects/data/project_sync_handler.dart';

import '../support/api_stack.dart';
import 'harness.dart';

class _NoTimer implements Timer {
  @override
  void cancel() {}
  @override
  bool get isActive => false;
  @override
  int get tick => 0;
}

/// In-memory db + the real engine and the project/area handlers against the
/// fake Tududi server of [remote].
class OfflineHarness {
  OfflineHarness._(this.remote) {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    areas = OfflineAreaRepository(db, now: () => t);
    projects = OfflineProjectRepository(db, now: () => t);
    engine = SyncEngine(
      db: db,
      handlers: [ProjectSyncHandler(), AreaSyncHandler()],
      dio: () => remote.dio,
      clock: UserClock(now: () => t, zoneName: 'UTC'),
      reauthenticate: () async => false,
      now: () => t,
      retryPolicy: RetryPolicy(random: FixedRandom()),
      createTimer: (_, _) => _NoTimer(),
    );
  }

  static Future<OfflineHarness> create() async {
    final h = OfflineHarness._(await ProjectsHarness.create());
    await h.engine.start();
    return h;
  }

  final ProjectsHarness remote;
  late final AppDatabase db;
  late final OfflineAreaRepository areas;
  late final OfflineProjectRepository projects;
  late final SyncEngine engine;

  /// Device time; the server stamps writes with the real clock, so set this
  /// into the past/future to decide who wins a field conflict.
  DateTime t = DateTime.now().toUtc();

  Future<void> sync() => engine.requestSync(SyncReason.manual);

  SyncContext ctx() => SyncContext(
    db: db,
    dio: () => remote.dio,
    clock: UserClock(now: () => t, zoneName: 'UTC'),
    now: t,
    onNotice: notices.add,
  );

  final notices = <Object>[];

  ProviderContainer container() => ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      syncEngineProvider.overrideWithValue(engine),
    ],
  );

  Future<void> dispose() async {
    await engine.dispose();
    await db.close();
  }
}
