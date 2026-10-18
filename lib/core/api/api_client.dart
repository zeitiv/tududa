import 'dart:async';
import 'dart:math';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_error.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/csrf_interceptor.dart';
import 'interceptors/redacting_log_interceptor.dart';
import 'interceptors/retry_interceptor.dart';
import 'interceptors/skew_interceptor.dart';

/// Implemented by the session layer so the HTTP stack can recover from an
/// expired session without knowing about credentials.
abstract class SessionAuthCallbacks {
  /// Sign in again with the stored credentials. Returns true when a fresh
  /// session cookie is in the jar; false (or throwing) means give up.
  Future<bool> reauthenticate();
}

/// Builds a [Dio] for one server. The session lane owns the Riverpod provider
/// that calls this (so tests can substitute it).
typedef DioFactory = Dio Function({
  required String serverUrl,
  required CookieJar jar,
  required SessionAuthCallbacks callbacks,
});

/// Creates the standard client: base URL `<serverUrl>/api`, JSON, 2xx-only
/// `validateStatus`, and the interceptor stack in this order:
/// redacting log (debug only), cookies, skew, csrf, auth, retry.
///
/// Paths passed to the returned client are relative to `/api`
/// (e.g. `dio.get('/tasks')`). Pass `ApiError`-producing calls through
/// [guard].
Dio createDio({
  required String serverUrl,
  required CookieJar jar,
  required SessionAuthCallbacks callbacks,
  void Function(Duration skew)? onSkew,
  DateTime Function()? now,
  HttpClientAdapter? adapter,
  bool enableLogging = kDebugMode,
  Future<void> Function(Duration)? retryDelay,
  Random? random,
}) {
  final base = serverUrl.trim().replaceAll(RegExp(r'/+$'), '');
  final dio = Dio(
    BaseOptions(
      baseUrl: '$base/api',
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: const {
        Headers.acceptHeader: Headers.jsonContentType,
        Headers.contentTypeHeader: Headers.jsonContentType,
      },
    ),
  );
  if (adapter != null) dio.httpClientAdapter = adapter;

  dio.interceptors.addAll([
    if (enableLogging) RedactingLogInterceptor(),
    CookieManager(jar),
    SkewInterceptor(now: now, onSkew: onSkew),
    CsrfInterceptor(dio: dio),
    AuthInterceptor(dio: dio, callbacks: callbacks),
    RetryInterceptor(dio: dio, delay: retryDelay, random: random),
  ]);
  return dio;
}

/// A [CancelToken] that is cancelled when the provider is disposed.
extension RefCancelToken on Ref {
  CancelToken cancelToken() {
    final token = CancelToken();
    onDispose(() {
      if (!token.isCancelled) token.cancel('provider disposed');
    });
    return token;
  }
}

/// Runs [call] and converts failures into [ApiError]s. An [ApiError] thrown
/// by [call] is rethrown as is; parse failures become [DecodingError].
Future<T> guard<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on ApiError {
    rethrow;
  } on DioException catch (e, st) {
    Error.throwWithStackTrace(ApiError.fromDio(e), st);
  } on FormatException catch (e, st) {
    Error.throwWithStackTrace(DecodingError(e), st);
  } on TypeError catch (e, st) {
    Error.throwWithStackTrace(DecodingError(e), st);
  }
}
