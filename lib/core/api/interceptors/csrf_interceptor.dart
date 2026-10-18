import 'dart:async';

import 'package:dio/dio.dart';

const _mutating = {'POST', 'PUT', 'PATCH', 'DELETE'};

bool _pathEndsWith(RequestOptions o, String suffix) =>
    o.path == suffix || o.uri.path.endsWith(suffix);

/// Adds Tududi's `x-csrf-token` to mutating requests.
///
/// The token is fetched lazily from `GET /csrf-token` (`{csrfToken}`), shared
/// between concurrent callers, cleared on login, logout and any 401, and
/// refreshed once when the server answers 403 mentioning csrf.
class CsrfInterceptor extends Interceptor {
  CsrfInterceptor({required this._dio});

  static const headerName = 'x-csrf-token';
  static const _retriedKey = 'csrf.retried';

  final Dio _dio;
  String? _token;
  Future<String>? _inflight;
  int _generation = 0;

  /// The cached token, if any (visible for tests).
  String? get token => _token;

  void clear() {
    _token = null;
    _inflight = null;
    _generation++;
  }

  Future<String> _ensureToken() {
    final cached = _token;
    if (cached != null) return Future.value(cached);
    return _inflight ??= _fetch();
  }

  Future<String> _fetch() async {
    final gen = _generation;
    try {
      final res = await _dio.get<Object?>('/csrf-token');
      final data = res.data;
      final token = data is Map ? data['csrfToken'] : null;
      if (token is! String || token.isEmpty) {
        throw const FormatException('Missing csrfToken in response');
      }
      if (gen == _generation) _token = token;
      return token;
    } finally {
      if (gen == _generation) _inflight = null;
    }
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_pathEndsWith(options, '/login') || _pathEndsWith(options, '/logout')) {
      clear();
    }
    if (!_mutating.contains(options.method) ||
        _pathEndsWith(options, '/login')) {
      return handler.next(options);
    }
    try {
      options.headers[headerName] = await _ensureToken();
      handler.next(options);
    } on DioException catch (e) {
      // `true`: let the error interceptors (auth, retry) see this failure too.
      handler.reject(e.copyWith(requestOptions: options), true);
    } catch (e) {
      handler.reject(
        DioException(requestOptions: options, error: e, message: '$e'),
        true,
      );
    }
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final o = response.requestOptions;
    if (_pathEndsWith(o, '/login') || _pathEndsWith(o, '/logout')) clear();
    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final o = err.requestOptions;
    final status = err.response?.statusCode;
    if (status == 401 ||
        _pathEndsWith(o, '/login') ||
        _pathEndsWith(o, '/logout')) {
      clear();
    }
    if (status == 403 &&
        _mutating.contains(o.method) &&
        o.extra[_retriedKey] != true &&
        _mentionsCsrf(err.response?.data)) {
      clear();
      o.extra[_retriedKey] = true;
      // CookieManager merges the old header with the jar; drop it so a fresh
      // session cookie is not shadowed.
      o.headers.remove('cookie');
      try {
        handler.resolve(await _dio.fetch<Object?>(o));
      } on DioException catch (e) {
        handler.reject(e);
      }
      return;
    }
    handler.next(err);
  }

  static bool _mentionsCsrf(Object? data) {
    if (data is Map) {
      return data.values.any(
        (v) => v.toString().toLowerCase().contains('csrf'),
      );
    }
    return data is String && data.toLowerCase().contains('csrf');
  }
}
