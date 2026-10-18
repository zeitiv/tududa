import 'dart:io' show HttpDate;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Measures `serverTime - deviceTime` from the HTTP `Date` header (1 second
/// resolution) and publishes it through [skew] and [onSkew]. Wire it to
/// `UserClock.serverSkew`.
class SkewInterceptor extends Interceptor {
  SkewInterceptor({DateTime Function()? now, this.onSkew})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final void Function(Duration skew)? onSkew;

  /// Latest measurement; starts at zero.
  final ValueNotifier<Duration> skew = ValueNotifier(Duration.zero);

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _observe(response);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final res = err.response;
    if (res != null) _observe(res);
    handler.next(err);
  }

  void _observe(Response res) {
    final header = res.headers.value('date');
    if (header == null) return;
    try {
      final server = HttpDate.parse(header);
      final value = server.difference(_now());
      skew.value = value;
      onSkew?.call(value);
    } catch (_) {
      // Ignore malformed Date headers.
    }
  }
}
