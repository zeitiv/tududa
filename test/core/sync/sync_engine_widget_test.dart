import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/ids.dart';
import 'package:tududa/core/platform/widget_bridge.dart';
import 'package:tududa/core/sync/retry_policy.dart';
import 'package:tududa/core/sync/sync_engine.dart';
import 'package:tududa/core/sync/sync_handler.dart';
import 'package:tududa/core/time/user_clock.dart';
import 'package:tududa/tasks/data/offline_task_repository.dart';
import 'package:tududa/tasks/data/task_sync_handler.dart';
import 'package:tududa/tasks/domain/task_views.dart';

import '../../support/api_stack.dart';
import '../../tasks/task_test_support.dart';

class _FakeTimer implements Timer {
  _FakeTimer(this.cb);
  final void Function() cb;
  bool cancelled = false;
  @override
  void cancel() => cancelled = true;
  @override
  bool get isActive => !cancelled;
  @override
  int get tick => 0;
}

void main() {
  late TaskTestRig net;
  late AppDatabase db;
  late InMemoryWidgetBridge widget;
  late SyncEngine engine;
  late OfflineTaskRepository repo;
  late List<_FakeTimer> timers;
  late DateTime t;
  var online = true;

  setUp(() async {
    net = TaskTestRig();
    await net.login();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    widget = InMemoryWidgetBridge();
    timers = [];
    online = true;
    t = DateTime.now().toUtc();
    final clock = UserClock(now: () => t, zoneName: 'UTC');
    repo = OfflineTaskRepository(
      db,
      now: () => t,
      day: () => TaskDay.fromClock(clock),
    );
    engine = SyncEngine(
      db: db,
      handlers: [TaskSyncHandler()],
      dio: () => net.stack.dio,
      clock: clock,
      reauthenticate: () async => false,
      isOnline: () => online,
      now: () => t,
      retryPolicy: RetryPolicy(random: FixedRandom()),
      createTimer: (d, cb) {
        final timer = _FakeTimer(cb);
        timers.add(timer);
        return timer;
      },
      widgetBridge: widget,
    );
    addTearDown(engine.dispose);
    await engine.start();
  });

  test(
    'a successful task push schedules one debounced widget refresh',
    () async {
      final uid = net.server.seedTask(name: 'A')['uid'] as String;
      await engine.requestSync(SyncReason.manual);
      await repo.complete(TaskUid(uid));
      t = t.add(const Duration(seconds: 6));
      await engine.requestSync(SyncReason.manual);

      expect(net.server.tasks[uid]!['status'], 2);
      final live = timers.where((x) => x.isActive).toList();
      expect(live, hasLength(1));
      expect(widget.refreshCount, 0);
      live.single.cb();
      await pumpEventQueue();
      expect(widget.refreshCount, 1);
    },
  );

  test('an offline completion is sent to the widget as an overlay', () async {
    final uid = net.server.seedTask(name: 'A')['uid'] as String;
    await engine.requestSync(SyncReason.manual);
    online = false;
    await repo.complete(TaskUid(uid));
    await engine.requestSync(SyncReason.write);
    expect(widget.overlays, [(uid: uid, status: 2)]);
    expect(widget.refreshCount, 0);
  });
}
