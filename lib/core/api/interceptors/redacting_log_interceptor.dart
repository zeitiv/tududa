import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Logs requests/responses like Dio's LogInterceptor but redacts secrets
/// (passwords, tokens, cookies, auth headers) from headers and JSON bodies.
class RedactingLogInterceptor extends Interceptor {
  RedactingLogInterceptor({void Function(String)? sink})
    : _sink = sink ?? _defaultSink;

  static void _defaultSink(String message) => debugPrint(message);

  static const redacted = '***';

  static const _sensitiveBodyKeys = {
    'password',
    'current_password',
    'new_password',
    'token',
    'csrftoken',
    'csrf_token',
    'api_key',
  };

  static const _sensitiveHeaders = {
    'cookie',
    'set-cookie',
    'authorization',
    'x-csrf-token',
  };

  final void Function(String) _sink;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _sink('--> ${options.method} ${options.uri}');
    _sink('headers: ${_redactHeaders(options.headers)}');
    if (options.data != null) {
      _sink('body: ${_redactBody(options.data)}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final req = response.requestOptions;
    _sink('<-- ${response.statusCode} ${req.method} ${req.uri}');
    _sink('headers: ${_redactHeaders(response.headers.map)}');
    if (response.data != null) {
      _sink('body: ${_redactBody(response.data)}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final req = err.requestOptions;
    _sink(
      '<-- ERROR ${err.response?.statusCode ?? '-'} ${req.method} ${req.uri}'
      ' (${err.type.name})',
    );
    final data = err.response?.data;
    if (data != null) {
      _sink('body: ${_redactBody(data)}');
    }
    handler.next(err);
  }

  Map<String, dynamic> _redactHeaders(Map<String, dynamic> headers) {
    return {
      for (final e in headers.entries)
        e.key: _sensitiveHeaders.contains(e.key.toLowerCase())
            ? redacted
            : e.value,
    };
  }

  /// Returns a redacted copy; never mutates [data].
  Object? _redactBody(Object? data) {
    if (data is FormData) {
      return 'FormData(fields: ${data.fields.map((f) => f.key).toList()}, '
          'files: ${data.files.length})';
    }
    return _redactValue(data);
  }

  Object? _redactValue(Object? value) {
    if (value is Map) {
      return {
        for (final e in value.entries)
          e.key: _sensitiveBodyKeys.contains(e.key.toString().toLowerCase())
              ? redacted
              : _redactValue(e.value),
      };
    }
    if (value is List) {
      return value.map(_redactValue).toList();
    }
    if (value is String || value is num || value is bool || value == null) {
      return value;
    }
    return '<${value.runtimeType}>';
  }
}
