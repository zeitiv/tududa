import 'dart:async';

import 'package:dio/dio.dart';

import '../api_client.dart';

/// On a 401, signs in again through [SessionAuthCallbacks.reauthenticate]
/// and replays the request once.
///
/// Any number of parallel 401s share a single re-login. Requests that were
/// sent before that re-login finished are replayed without triggering another.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this._dio, required this._callbacks});

  static const _retriedKey = 'auth.retried';
  static const _generationKey = 'auth.generation';
  static const _skipSuffixes = [
    '/login',
    '/current_user',
    '/logout',
    '/csrf-token',
  ];

  final Dio _dio;
  final SessionAuthCallbacks _callbacks;
  Future<bool>? _inflight;
  int _generation = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_generationKey] = _generation;
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final o = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        o.extra[_retriedKey] == true ||
        _skipSuffixes.any((s) => o.path == s || o.uri.path.endsWith(s))) {
      return handler.next(err);
    }

    final sentIn = o.extra[_generationKey] as int? ?? _generation;
    final bool ok;
    if (sentIn < _generation) {
      ok = true; // a re-login already completed after this request left
    } else {
      ok = await (_inflight ??= _reauth());
    }
    if (!ok) return handler.next(err);

    o.extra[_retriedKey] = true;
    // CookieManager merges the old header with the jar; drop it so a fresh
    // session cookie is not shadowed.
    o.headers.remove('cookie');
    try {
      handler.resolve(await _dio.fetch<Object?>(o));
    } on DioException catch (e) {
      handler.reject(e);
    }
  }

  Future<bool> _reauth() async {
    try {
      final ok = await _callbacks.reauthenticate();
      if (ok) _generation++;
      return ok;
    } catch (_) {
      return false;
    } finally {
      _inflight = null;
    }
  }
}
