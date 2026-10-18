import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/connectivity/connectivity_service.dart';
import 'package:tududa/core/sync/sync_handler.dart';
import 'package:tududa/core/sync/sync_triggers.dart';

void main() {
  test('triggers: connectivity, debounced writes, timer, lifecycle', () {
    fakeAsync((async) {
      final reasons = <SyncReason>[];
      final net = StreamController<NetworkStatus>.broadcast();
      final writes = StreamController<void>.broadcast();
      final triggers = SyncTriggers(
        request: reasons.add,
        connectivity: net.stream,
        writes: writes.stream,
        currentNetwork: () => NetworkStatus.offline,
      )..start();

      net.add(NetworkStatus.online);
      async.flushMicrotasks();
      expect(reasons, [SyncReason.connectivity]);
      net.add(NetworkStatus.online); // no change
      net.add(NetworkStatus.offline);
      net.add(NetworkStatus.online);
      async.flushMicrotasks();
      expect(reasons, hasLength(2));
      reasons.clear();

      // A burst of writes becomes one request, 500 ms after the last one.
      writes.add(null);
      async.elapse(const Duration(milliseconds: 200));
      writes.add(null);
      async.elapse(const Duration(milliseconds: 200));
      triggers.notifyWrite();
      async.elapse(const Duration(milliseconds: 499));
      expect(reasons, isEmpty);
      async.elapse(const Duration(milliseconds: 1));
      expect(reasons, [SyncReason.write]);
      reasons.clear();

      // Foreground timer every 5 minutes.
      async.elapse(const Duration(minutes: 5));
      expect(reasons, [SyncReason.timer]);
      reasons.clear();

      // Backgrounded: no timer; resumed: a request and the timer again.
      triggers.didChangeAppLifecycleState(AppLifecycleState.paused);
      async.elapse(const Duration(minutes: 20));
      expect(reasons, isEmpty);
      triggers.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(reasons, [SyncReason.resume]);
      async.elapse(const Duration(minutes: 5));
      expect(reasons, [SyncReason.resume, SyncReason.timer]);

      triggers.dispose();
      reasons.clear();
      writes.add(null);
      async.elapse(const Duration(minutes: 30));
      expect(reasons, isEmpty);
    });
  });

  test('timer sources are injectable', () {
    final created = <Duration>[];
    final triggers = SyncTriggers(
      request: (_) {},
      debounce: const Duration(milliseconds: 10),
      foregroundInterval: const Duration(minutes: 1),
      createTimer: (d, cb) {
        created.add(d);
        return Timer(const Duration(days: 1), cb)..cancel();
      },
      createPeriodic: (d, cb) {
        created.add(d);
        return Timer.periodic(const Duration(days: 1), cb)..cancel();
      },
    )..start();
    triggers.notifyWrite();
    expect(created, [
      const Duration(minutes: 1),
      const Duration(milliseconds: 10),
    ]);
    triggers.dispose();
  });
}
