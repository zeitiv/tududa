import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/session/server_config.dart';
import '../../auth/session/session_controller.dart';
import '../../auth/session/session_providers.dart';
import 'api_client.dart';

/// Knobs for [dioProvider] that only tests change.
class DioTuning {
  const DioTuning({
    this.adapter,
    this.enableLogging = kDebugMode,
    this.retryDelay,
    this.random,
    this.now,
  });
  final HttpClientAdapter? adapter;
  final bool enableLogging;
  final Future<void> Function(Duration)? retryDelay;
  final Random? random;
  final DateTime Function()? now;
}

final dioTuningProvider = Provider<DioTuning>((ref) => const DioTuning());

/// Forwards to the session controller, looked up when first needed.
///
/// [dioProvider] cannot depend on the controller directly: the controller
/// reads [dioProvider] to log in, which would be a provider cycle. A runtime
/// `ref.read` inside the callback keeps the graph acyclic.
class _LateBoundCallbacks implements SessionAuthCallbacks {
  _LateBoundCallbacks(this._ref);
  final Ref _ref;

  @override
  Future<bool> reauthenticate() =>
      _ref.read(sessionControllerProvider.notifier).reauthenticate();
}

/// Dio configured for the signed-in server (CSRF, re-auth, retry included).
///
/// Rebuilt when the server URL changes; carries the shared cookie jar.
/// Repositories read this provider; they never build their own client.
/// Throws a [StateError] while no server is configured. Tests override it
/// with `makeDio(FakeTududi)` / `TestStack.dio`, or override
/// [dioTuningProvider] to run the real stack against a fake adapter.
final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(serverConfigProvider);
  if (config == null) {
    throw StateError('dioProvider read before a server was configured.');
  }
  final tuning = ref.watch(dioTuningProvider);
  final dio = createDio(
    serverUrl: config.url,
    jar: ref.watch(cookieJarProvider),
    callbacks: _LateBoundCallbacks(ref),
    onSkew: (skew) {
      try {
        ref.read(userClockProvider).serverSkew = skew;
      } catch (_) {
        // The provider was disposed while a response was in flight.
      }
    },
    adapter: tuning.adapter,
    enableLogging: tuning.enableLogging,
    retryDelay: tuning.retryDelay,
    random: tuning.random,
    now: tuning.now,
  );
  ref.onDispose(() => dio.close());
  return dio;
});
