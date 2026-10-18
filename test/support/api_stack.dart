import 'dart:math';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:tududa/core/api/api_client.dart';

import 'fake_tududi/dio_adapter.dart';
import 'fake_tududi/fake_tududi.dart';

/// Callbacks double: counts calls, delegates to [onReauth].
class FakeAuthCallbacks implements SessionAuthCallbacks {
  FakeAuthCallbacks([this.onReauth]);
  Future<bool> Function()? onReauth;
  int calls = 0;

  @override
  Future<bool> reauthenticate() async {
    calls++;
    return onReauth == null ? false : onReauth!();
  }
}

/// A Random that always returns [value] (0 = no jitter).
class FixedRandom implements Random {
  FixedRandom([this.value = 0]);
  final double value;
  @override
  double nextDouble() => value;
  @override
  bool nextBool() => false;
  @override
  int nextInt(int max) => 0;
}

/// The full production stack from [createDio] against [server], with a
/// recording instant delay.
class TestStack {
  TestStack(
    this.server, {
    FakeAuthCallbacks? callbacks,
    CookieJar? jar,
    void Function(Duration)? onSkew,
    DateTime Function()? now,
  }) : callbacks = callbacks ?? FakeAuthCallbacks(),
       jar = jar ?? CookieJar() {
    dio = createDio(
      serverUrl: 'http://fake.tududi.test',
      jar: this.jar,
      callbacks: this.callbacks,
      adapter: FakeTududiAdapter(server),
      enableLogging: false,
      retryDelay: (d) async => delays.add(d),
      random: FixedRandom(),
      onSkew: onSkew,
      now: now,
    );
  }

  final FakeTududi server;
  final FakeAuthCallbacks callbacks;
  final CookieJar jar;
  final List<Duration> delays = [];
  late final Dio dio;

  int count(String method, String path) =>
      server.requests.where((r) => r.method == method && r.path == path).length;
}
