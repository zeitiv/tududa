import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

enum NetworkStatus { online, offline, unknown }

/// Tracks reachability: connectivity_plus says whether any interface is up;
/// an optional [probe] (GET `/api/health`) confirms the server is reachable.
///
/// While the probe fails the status stays [NetworkStatus.offline] and the
/// service re-probes with exponential backoff (starting at [probeBackoff],
/// capped at [maxProbeBackoff]). Call [dispose] when done.
class ConnectivityService {
  ConnectivityService({
    Stream<List<ConnectivityResult>>? changes,
    Future<List<ConnectivityResult>> Function()? check,
    this.probe,
    this.probeBackoff = const Duration(seconds: 2),
    this.maxProbeBackoff = const Duration(seconds: 60),
  }) : _check = check ?? (() => Connectivity().checkConnectivity()) {
    _sub = (changes ?? Connectivity().onConnectivityChanged).listen(
      _onChange,
      onError: (_) {},
    );
    unawaited(recheck());
  }

  /// Returns true when the server answered `/api/health`.
  final Future<bool> Function()? probe;
  final Duration probeBackoff;
  final Duration maxProbeBackoff;
  final Future<List<ConnectivityResult>> Function() _check;

  final _controller = StreamController<NetworkStatus>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  NetworkStatus _current = NetworkStatus.unknown;
  Timer? _probeTimer;
  Duration _nextBackoff = Duration.zero;
  bool _disposed = false;
  int _epoch = 0;

  NetworkStatus get current => _current;

  /// Emits on every change (not the initial value; read [current] for that).
  Stream<NetworkStatus> get status => _controller.stream;

  void _onChange(List<ConnectivityResult> results) =>
      unawaited(_evaluate(results));

  /// Re-reads the interface state and re-probes the server.
  Future<void> recheck() async {
    try {
      await _evaluate(await _check());
    } catch (_) {
      _set(NetworkStatus.unknown);
    }
  }

  Future<void> _evaluate(List<ConnectivityResult> results) async {
    final epoch = ++_epoch;
    _probeTimer?.cancel();
    final up = results.any((r) => r != ConnectivityResult.none);
    if (!up) {
      _nextBackoff = Duration.zero;
      return _set(NetworkStatus.offline);
    }
    final probe = this.probe;
    if (probe == null) return _set(NetworkStatus.online);

    bool ok;
    try {
      ok = await probe();
    } catch (_) {
      ok = false;
    }
    if (epoch != _epoch || _disposed) return;
    if (ok) {
      _nextBackoff = Duration.zero;
      return _set(NetworkStatus.online);
    }
    _set(NetworkStatus.offline);
    _nextBackoff = _nextBackoff == Duration.zero
        ? probeBackoff
        : Duration(
            milliseconds: (_nextBackoff.inMilliseconds * 2).clamp(
              0,
              maxProbeBackoff.inMilliseconds,
            ),
          );
    _probeTimer = Timer(_nextBackoff, () => unawaited(recheck()));
  }

  void _set(NetworkStatus s) {
    if (_disposed || s == _current) return;
    _current = s;
    _controller.add(s);
  }

  Future<void> dispose() async {
    _disposed = true;
    _probeTimer?.cancel();
    await _sub?.cancel();
    await _controller.close();
  }
}
