import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/connectivity/connectivity_service.dart';

void main() {
  late StreamController<List<ConnectivityResult>> changes;
  var initial = [ConnectivityResult.wifi];

  setUp(() {
    changes = StreamController<List<ConnectivityResult>>.broadcast();
    initial = [ConnectivityResult.wifi];
  });
  tearDown(() => changes.close());

  ConnectivityService make({Future<bool> Function()? probe}) =>
      ConnectivityService(
        changes: changes.stream,
        check: () async => initial,
        probe: probe,
      );

  test('starts unknown, then reflects the interface state', () async {
    final s = make();
    expect(s.current, NetworkStatus.unknown);
    await Future<void>.delayed(Duration.zero);
    expect(s.current, NetworkStatus.online);
    await s.dispose();
  });

  test('emits on changes', () async {
    final s = make();
    final seen = <NetworkStatus>[];
    s.status.listen(seen.add);
    await Future<void>.delayed(Duration.zero);
    changes.add([ConnectivityResult.none]);
    await Future<void>.delayed(Duration.zero);
    changes.add([ConnectivityResult.mobile]);
    await Future<void>.delayed(Duration.zero);
    expect(seen, [
      NetworkStatus.online,
      NetworkStatus.offline,
      NetworkStatus.online,
    ]);
    await s.dispose();
  });

  test('duplicate states are not re-emitted', () async {
    final s = make();
    final seen = <NetworkStatus>[];
    s.status.listen(seen.add);
    await Future<void>.delayed(Duration.zero);
    changes.add([ConnectivityResult.wifi, ConnectivityResult.vpn]);
    await Future<void>.delayed(Duration.zero);
    expect(seen, [NetworkStatus.online]);
    await s.dispose();
  });

  test('an interface that is up but a failing probe means offline', () async {
    var reachable = false;
    final s = make(probe: () async => reachable);
    await Future<void>.delayed(Duration.zero);
    expect(s.current, NetworkStatus.offline);
    reachable = true;
    await s.recheck();
    expect(s.current, NetworkStatus.online);
    await s.dispose();
  });

  test('probe is skipped when no interface is up', () async {
    initial = [ConnectivityResult.none];
    var probes = 0;
    final s = make(
      probe: () async {
        probes++;
        return true;
      },
    );
    await Future<void>.delayed(Duration.zero);
    expect(s.current, NetworkStatus.offline);
    expect(probes, 0);
    await s.dispose();
  });

  test('failing probe is re-run with exponential backoff', () {
    fakeAsync((async) {
      final probeTimes = <Duration>[];
      var elapsed = Duration.zero;
      var reachable = false;
      final s = ConnectivityService(
        changes: changes.stream,
        check: () async => initial,
        probe: () async {
          probeTimes.add(elapsed);
          return reachable;
        },
        probeBackoff: const Duration(seconds: 2),
        maxProbeBackoff: const Duration(seconds: 5),
      );
      void advance(Duration d) {
        elapsed += d;
        async.elapse(d);
      }

      async.flushMicrotasks();
      expect(probeTimes, [Duration.zero]);
      advance(const Duration(seconds: 2)); // 1st backoff: 2s
      expect(probeTimes.length, 2);
      advance(const Duration(seconds: 4)); // 2nd backoff: 4s
      expect(probeTimes.length, 3);
      advance(const Duration(seconds: 5)); // capped at 5s
      expect(probeTimes.length, 4);
      reachable = true;
      advance(const Duration(seconds: 5));
      expect(s.current, NetworkStatus.online);
      advance(const Duration(minutes: 1)); // stops probing once online
      expect(probeTimes.length, 5);
      s.dispose();
    });
  });

  test('a throwing probe counts as unreachable', () async {
    final s = make(probe: () async => throw StateError('x'));
    await Future<void>.delayed(Duration.zero);
    expect(s.current, NetworkStatus.offline);
    await s.dispose();
  });
}
