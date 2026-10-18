import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';

/// Retries idempotent requests (GET, PUT, DELETE, HEAD) that failed for
/// transient reasons: connection errors, timeouts, 502/503/504 and 429.
///
/// Up to [maxRetries] retries (so at most `maxRetries + 1` requests) with
/// exponential backoff `baseDelay * 2^n` plus up to 25% jitter. For 429 the
/// `Retry-After` header is honoured; if it exceeds [maxRetryAfter] the error
/// is passed through. POST and PATCH are never retried, nor are cancellations.
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required this._dio,
    this.maxRetries = 3,
    this.baseDelay = const Duration(milliseconds: 400),
    this.maxRetryAfter = const Duration(seconds: 30),
    Future<void> Function(Duration)? delay,
    Random? random,
  }) : _delay = delay ?? Future<void>.delayed,
       _random = random ?? Random();

  static const _attemptKey = 'retry.attempt';
  static const _methods = {'GET', 'PUT', 'DELETE', 'HEAD'};
  static const _retryStatuses = {502, 503, 504};

  final Dio _dio;
  final int maxRetries;
  final Duration baseDelay;
  final Duration maxRetryAfter;
  final Future<void> Function(Duration) _delay;
  final Random _random;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final o = err.requestOptions;
    final attempt = o.extra[_attemptKey] as int? ?? 0;
    if (!_methods.contains(o.method) ||
        attempt >= maxRetries ||
        o.cancelToken?.isCancelled == true) {
      return handler.next(err);
    }

    Duration? wait;
    switch (err.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        wait = _backoff(attempt);
      case DioExceptionType.badResponse:
        final status = err.response?.statusCode;
        if (_retryStatuses.contains(status)) {
          wait = _backoff(attempt);
        } else if (status == 429) {
          final secs = int.tryParse(
            err.response?.headers.value('retry-after')?.trim() ?? '',
          );
          final after = secs == null
              ? _backoff(attempt)
              : Duration(seconds: secs);
          if (after <= maxRetryAfter) wait = after;
        }
      default:
        break;
    }
    if (wait == null) return handler.next(err);

    await _delay(wait);
    if (o.cancelToken?.isCancelled == true) return handler.next(err);

    o.extra[_attemptKey] = attempt + 1;
    // CookieManager merges the old header with the jar; drop it so a fresh
    // session cookie is not shadowed.
    o.headers.remove('cookie');
    try {
      handler.resolve(await _dio.fetch<Object?>(o));
    } on DioException catch (e) {
      handler.reject(e);
    }
  }

  Duration _backoff(int attempt) {
    final base = baseDelay.inMilliseconds * (1 << attempt);
    final jitter = (base * 0.25 * _random.nextDouble()).round();
    return Duration(milliseconds: base + jitter);
  }
}
