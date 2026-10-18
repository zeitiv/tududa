import 'package:drift/native.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:tududa/auth/session/session_providers.dart';
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/sync/sync_engine.dart';
import 'package:tududa/core/sync/sync_handlers.dart';
import 'package:tududa/core/sync/sync_status.dart';
import 'package:tududa/core/time/user_clock.dart';

import '../core/sync/support/fake_entity_handler.dart';
import '../core/sync/support/fake_lane.dart';
import '../support/fake_tududi/fake_tududi.dart';

/// Status notifier whose state tests set directly.
class FakeSyncStatus extends SyncStatusNotifier {
  FakeSyncStatus(this.initial);
  final SyncStatus initial;

  @override
  SyncStatus build() => initial;

  void set(SyncStatus s) => state = s;
}

/// In-memory DB + real engine with the fake project handler, wired to a fake
/// server, for the sync UI tests.
class SyncUiHarness {
  SyncUiHarness({SyncStatus status = const SyncStatus()}) : initial = status {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    server = FakeTududi();
    remote = FakeEntityServer(server);
    lane = FakeLane(db, DateTime.now);
    final dio = plainDio(server);
    clock = UserClock(now: DateTime.now, zoneName: 'UTC');
    engine = SyncEngine(
      db: db,
      handlers: [handler],
      dio: () => dio,
      clock: clock,
      reauthenticate: () async => false,
    );
  }

  final SyncStatus initial;
  late final AppDatabase db;
  late final FakeTududi server;
  late final FakeEntityServer remote;
  late final FakeLane lane;
  late final UserClock clock;
  late final SyncEngine engine;
  final handler = FakeEntityHandler('project');

  List<Override> get overrides => [
    appDatabaseProvider.overrideWithValue(db),
    syncEngineProvider.overrideWithValue(engine),
    syncHandlersProvider.overrideWithValue([handler]),
    userClockProvider.overrideWithValue(clock),
    syncStatusProvider.overrideWith(() => FakeSyncStatus(initial)),
  ];
}
