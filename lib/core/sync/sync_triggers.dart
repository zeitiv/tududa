// ignore_for_file: prefer_initializing_formals -- named params cannot be private.
import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery, UpdateKind;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_providers.dart';
import '../connectivity/connectivity_service.dart';
import '../db/app_database.dart';
import 'sync_engine.dart';
import 'sync_handler.dart';

/// Turns app events into `requestSync` calls:
/// - connectivity going offline -> online ([SyncReason.connectivity]);
/// - the app returning to the foreground ([SyncReason.resume]);
/// - local writes, debounced by [debounce] ([SyncReason.write]);
/// - a periodic timer while in the foreground ([SyncReason.timer]).
///
/// Manual sync is `engine.requestSync(SyncReason.manual)` and needs no
/// trigger. All sources are injectable for tests; call [start] once and
/// [dispose] when done.
class SyncTriggers with WidgetsBindingObserver {
  SyncTriggers({
    required void Function(SyncReason) request,
    Stream<NetworkStatus>? connectivity,
    Stream<void>? writes,
    NetworkStatus Function()? currentNetwork,
    this.debounce = const Duration(milliseconds: 500),
    this.foregroundInterval = const Duration(minutes: 5),
    Timer Function(Duration, void Function())? createTimer,
    Timer Function(Duration, void Function(Timer))? createPeriodic,
    WidgetsBinding? binding,
  }) : _request = request,
       _connectivity = connectivity,
       _writes = writes,
       _currentNetwork = currentNetwork,
       _createTimer = createTimer ?? Timer.new,
       _createPeriodic = createPeriodic ?? Timer.periodic,
       _binding = binding;

  final void Function(SyncReason) _request;
  final Stream<NetworkStatus>? _connectivity;
  final Stream<void>? _writes;
  final NetworkStatus Function()? _currentNetwork;
  final Duration debounce;
  final Duration foregroundInterval;
  final Timer Function(Duration, void Function()) _createTimer;
  final Timer Function(Duration, void Function(Timer)) _createPeriodic;
  final WidgetsBinding? _binding;

  final List<StreamSubscription<Object?>> _subs = [];
  Timer? _debounceTimer;
  Timer? _periodic;
  NetworkStatus? _last;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    _last = _currentNetwork?.call();
    final connectivity = _connectivity;
    if (connectivity != null) {
      _subs.add(
        connectivity.listen((s) {
          final was = _last;
          _last = s;
          if (s == NetworkStatus.online && was != NetworkStatus.online) {
            _request(SyncReason.connectivity);
          }
        }),
      );
    }
    final writes = _writes;
    if (writes != null) _subs.add(writes.listen((_) => notifyWrite()));
    _binding?.addObserver(this);
    _startPeriodic();
  }

  /// A local write happened; requests a sync after the debounce.
  void notifyWrite() {
    _debounceTimer?.cancel();
    _debounceTimer = _createTimer(debounce, () => _request(SyncReason.write));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _request(SyncReason.resume);
        _startPeriodic();
      case AppLifecycleState.inactive ||
          AppLifecycleState.hidden ||
          AppLifecycleState.paused ||
          AppLifecycleState.detached:
        _periodic?.cancel();
        _periodic = null;
    }
  }

  void _startPeriodic() {
    _periodic?.cancel();
    _periodic = _createPeriodic(
      foregroundInterval,
      (_) => _request(SyncReason.timer),
    );
  }

  void dispose() {
    _binding?.removeObserver(this);
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _debounceTimer?.cancel();
    _periodic?.cancel();
    _started = false;
  }
}

/// Reachability: connectivity_plus plus a `/api/health` probe.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService(
    probe: () async {
      try {
        await ref.read(dioProvider).get<Object?>('/health');
        return true;
      } catch (_) {
        return false;
      }
    },
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Starts the triggers for [syncEngineProvider]. Watch it once at the app
/// root (T3.Z); it fires on database writes to the outbox automatically, so
/// lanes never call `notifyWrite` themselves.
final syncTriggersProvider = Provider<SyncTriggers>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final engine = ref.watch(syncEngineProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  final triggers = SyncTriggers(
    request: (reason) => unawaited(engine.requestSync(reason)),
    connectivity: connectivity.status,
    currentNetwork: () => connectivity.current,
    writes: db
        .tableUpdates(
          TableUpdateQuery.onTable(
            db.outbox,
            limitUpdateKind: UpdateKind.insert,
          ),
        )
        .map((_) {}),
    binding: WidgetsBinding.instance,
  )..start();
  ref.onDispose(triggers.dispose);
  return triggers;
});
