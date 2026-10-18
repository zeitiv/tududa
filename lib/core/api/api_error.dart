import 'dart:io' show SocketException;

import 'package:dio/dio.dart';

/// Every failure that leaves the API layer. Repositories and controllers
/// switch exhaustively on this; they never see [DioException].
sealed class ApiError implements Exception {
  const ApiError(this.message, {this.statusCode});

  /// Human-readable, from the server body when it gave one.
  final String message;
  final int? statusCode;

  /// Worth retrying later without changing the request (offline, 5xx, 429).
  bool get isTransient => switch (this) {
    NetworkError() || TimeoutError() || RateLimitedError() => true,
    ServerError(:final statusCode) => (statusCode ?? 0) >= 500,
    _ => false,
  };

  /// Retrying the same request can never succeed; drop or surface it.
  bool get isPermanent => switch (this) {
    ValidationError() || NotFoundError() => true,
    ForbiddenError() => true,
    ServerError(:final statusCode) =>
      statusCode == 400 ||
          statusCode == 404 ||
          statusCode == 409 ||
          statusCode == 422,
    _ => false,
  };

  @override
  String toString() => '$runtimeType($statusCode): $message';

  /// Maps a [DioException] to the matching [ApiError]. An [ApiError] already
  /// carried as `e.error` is returned as is.
  static ApiError fromDio(DioException e) {
    final inner = e.error;
    if (inner is ApiError) return inner;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutError(e.message ?? 'The request timed out');
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return NetworkError(e.message ?? 'Could not reach the server');
      case DioExceptionType.cancel:
        return const CancelledError();
      case DioExceptionType.unknown:
        if (inner is FormatException || inner is TypeError) {
          return DecodingError(inner!);
        }
        if (inner is SocketException) return NetworkError(inner.message);
        return NetworkError(e.message ?? inner?.toString() ?? 'Network error');
      case DioExceptionType.badResponse:
        return _fromResponse(e);
    }
  }

  static ApiError _fromResponse(DioException e) {
    final res = e.response;
    final status = res?.statusCode ?? 0;
    final data = res?.data;
    final msg = extractMessage(data);
    final lower = (msg ?? '').toLowerCase();
    final path = e.requestOptions.path;
    final isLogin = path == '/login' || path.endsWith('/login');

    switch (status) {
      case 401:
        return isLogin
            ? InvalidCredentialsError(msg ?? 'Invalid credentials')
            : UnauthorizedError(msg ?? 'Authentication required');
      case 403:
        if (lower.contains('csrf')) {
          return CsrfError(msg ?? 'Invalid CSRF token');
        }
        if (lower.contains('verif')) {
          return EmailNotVerifiedError(msg ?? 'Email not verified');
        }
        if (lower.contains('password') &&
            (lower.contains('disabled') || lower.contains('sso'))) {
          return PasswordLoginDisabledError(
            msg ?? 'Password login is disabled',
          );
        }
        return ForbiddenError(msg ?? 'Forbidden');
      case 404:
        return NotFoundError(msg ?? 'Not found');
      case 400:
      case 409:
      case 422:
        return ValidationError(
          msg ?? 'Invalid request',
          statusCode: status,
          fieldErrors: _fieldErrors(data),
        );
      case 429:
        return RateLimitedError(
          msg ?? 'Too many requests',
          _retryAfter(res?.headers.value('retry-after')),
        );
    }
    if (status >= 500 || status == 0) {
      return ServerError(
        status,
        msg ?? (status == 0 ? 'Unexpected response' : 'Server error'),
      );
    }
    return ServerError(status, msg ?? 'Request failed ($status)');
  }

  /// Pulls a message out of a Tududi error body: `error` (string),
  /// `errors` (list of strings or `{message}` maps), or `message`.
  static String? extractMessage(Object? data) {
    if (data is String) return data.trim().isEmpty ? null : data.trim();
    if (data is! Map) return null;
    final error = data['error'];
    if (error is String && error.isNotEmpty) return error;
    final errors = data['errors'];
    if (errors is List && errors.isNotEmpty) {
      final parts = [
        for (final x in errors)
          if (x is String)
            x
          else if (x is Map && x['message'] is String)
            x['message'] as String,
      ];
      if (parts.isNotEmpty) return parts.join('\n');
    } else if (errors is String && errors.isNotEmpty) {
      return errors;
    }
    final message = data['message'];
    if (message is String && message.isNotEmpty) return message;
    return null;
  }

  static List<String> _fieldErrors(Object? data) {
    if (data is Map && data['errors'] is List) {
      return [
        for (final x in data['errors'] as List)
          if (x is String) x else if (x is Map) (x['message'] ?? '').toString(),
      ].where((s) => s.isNotEmpty).toList();
    }
    return const [];
  }

  static Duration? _retryAfter(String? header) {
    final secs = int.tryParse(header?.trim() ?? '');
    return secs == null || secs < 0 ? null : Duration(seconds: secs);
  }
}

/// Offline, DNS failure, connection refused, TLS failure.
final class NetworkError extends ApiError {
  const NetworkError([super.message = 'Network error']);
}

/// connect / send / receive timeout.
final class TimeoutError extends ApiError {
  const TimeoutError([super.message = 'The request timed out']);
}

/// The caller cancelled the request (CancelToken).
final class CancelledError extends ApiError {
  const CancelledError([super.message = 'Cancelled']);
}

/// 401 on a normal request: the session is gone.
final class UnauthorizedError extends ApiError {
  const UnauthorizedError([super.message = 'Authentication required'])
    : super(statusCode: 401);
}

/// 401 on `/login`: wrong email or password.
final class InvalidCredentialsError extends ApiError {
  const InvalidCredentialsError([super.message = 'Invalid credentials'])
    : super(statusCode: 401);
}

final class EmailNotVerifiedError extends ApiError {
  const EmailNotVerifiedError([super.message = 'Email not verified'])
    : super(statusCode: 403);
}

final class PasswordLoginDisabledError extends ApiError {
  const PasswordLoginDisabledError([
    super.message = 'Password login is disabled',
  ]) : super(statusCode: 403);
}

/// 403 caused by a missing or stale CSRF token.
final class CsrfError extends ApiError {
  const CsrfError([super.message = 'Invalid CSRF token'])
    : super(statusCode: 403);
}

final class ForbiddenError extends ApiError {
  const ForbiddenError([super.message = 'Forbidden']) : super(statusCode: 403);
}

final class NotFoundError extends ApiError {
  const NotFoundError([super.message = 'Not found']) : super(statusCode: 404);
}

/// 400 / 409 / 422. [fieldErrors] holds the server's `errors[]` strings.
final class ValidationError extends ApiError {
  const ValidationError(
    super.message, {
    super.statusCode = 400,
    this.fieldErrors = const [],
  });
  final List<String> fieldErrors;
}

/// 429. [retryAfter] comes from the `Retry-After` header (seconds).
final class RateLimitedError extends ApiError {
  const RateLimitedError([super.message = 'Too many requests', this.retryAfter])
    : super(statusCode: 429);
  final Duration? retryAfter;
}

/// 5xx (or any other unexpected status).
final class ServerError extends ApiError {
  // ignore: use_super_parameters
  const ServerError(int statusCode, [String message = 'Server error'])
    : super(message, statusCode: statusCode);
}

/// The response arrived but could not be parsed into the expected shape.
final class DecodingError extends ApiError {
  const DecodingError(this.cause) : super('Unexpected response format');
  final Object cause;
}
