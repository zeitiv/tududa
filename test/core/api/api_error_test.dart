import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/api/api_error.dart';

DioException resp(
  int status,
  Object? body, {
  String path = '/tasks',
  Map<String, String> headers = const {},
}) {
  final ro = RequestOptions(path: path);
  return DioException(
    requestOptions: ro,
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: ro,
      statusCode: status,
      data: body,
      headers: Headers.fromMap({
        for (final e in headers.entries) e.key: [e.value],
      }),
    ),
  );
}

DioException typed(DioExceptionType t, {Object? error}) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  type: t,
  error: error,
);

void main() {
  group('type mapping', () {
    test('timeouts', () {
      for (final t in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(ApiError.fromDio(typed(t)), isA<TimeoutError>());
      }
    });
    test('connection error, bad certificate, socket exception', () {
      expect(
        ApiError.fromDio(typed(DioExceptionType.connectionError)),
        isA<NetworkError>(),
      );
      expect(
        ApiError.fromDio(typed(DioExceptionType.badCertificate)),
        isA<NetworkError>(),
      );
      expect(
        ApiError.fromDio(
          typed(DioExceptionType.unknown, error: const SocketException('down')),
        ),
        isA<NetworkError>(),
      );
    });
    test('cancel', () {
      expect(
        ApiError.fromDio(typed(DioExceptionType.cancel)),
        isA<CancelledError>(),
      );
    });
    test('parse failures become DecodingError', () {
      final e = ApiError.fromDio(
        typed(DioExceptionType.unknown, error: const FormatException('bad')),
      );
      expect(e, isA<DecodingError>());
      expect((e as DecodingError).cause, isA<FormatException>());
    });
    test('carried ApiError is returned as is', () {
      const inner = NotFoundError('x');
      expect(
        ApiError.fromDio(typed(DioExceptionType.unknown, error: inner)),
        same(inner),
      );
    });
  });

  group('401', () {
    test('on /login -> InvalidCredentials, message from errors[0]', () {
      final e = ApiError.fromDio(
        resp(401, {
          'errors': ['Invalid credentials'],
        }, path: '/login'),
      );
      expect(e, isA<InvalidCredentialsError>());
      expect(e.message, 'Invalid credentials');
      expect(e.statusCode, 401);
    });
    test('on /login with error string', () {
      final e = ApiError.fromDio(resp(401, {'error': 'Nope'}, path: '/login'));
      expect(e, isA<InvalidCredentialsError>());
      expect(e.message, 'Nope');
    });
    test('elsewhere -> Unauthorized', () {
      final e = ApiError.fromDio(
        resp(401, {'error': 'Authentication required'}),
      );
      expect(e, isA<UnauthorizedError>());
      expect(e.message, 'Authentication required');
    });
  });

  group('403', () {
    test('csrf (case-insensitive)', () {
      expect(
        ApiError.fromDio(resp(403, {'error': 'Invalid CSRF token'})),
        isA<CsrfError>(),
      );
      expect(
        ApiError.fromDio(resp(403, {'error': 'bad csrf'})),
        isA<CsrfError>(),
      );
    });
    test('email not verified', () {
      expect(
        ApiError.fromDio(
          resp(403, {'error': 'Email not verified. Please verify.'}),
        ),
        isA<EmailNotVerifiedError>(),
      );
    });
    test('password login disabled / sso', () {
      expect(
        ApiError.fromDio(resp(403, {'error': 'Password login is disabled'})),
        isA<PasswordLoginDisabledError>(),
      );
      expect(
        ApiError.fromDio(resp(403, {'error': 'Use SSO instead of password'})),
        isA<PasswordLoginDisabledError>(),
      );
    });
    test('other 403 -> Forbidden (permanent, not transient)', () {
      final e = ApiError.fromDio(resp(403, {'error': 'Forbidden'}));
      expect(e, isA<ForbiddenError>());
      expect(e.isPermanent, isTrue);
      expect(e.isTransient, isFalse);
    });
    test('csrf error is neither permanent nor transient', () {
      final e = ApiError.fromDio(resp(403, {'error': 'Invalid CSRF token'}));
      expect(e.isPermanent, isFalse);
      expect(e.isTransient, isFalse);
    });
  });

  group('other statuses', () {
    test('404', () {
      final e = ApiError.fromDio(resp(404, {'error': 'Task not found'}));
      expect(e, isA<NotFoundError>());
      expect(e.message, 'Task not found');
      expect(e.isPermanent, isTrue);
    });
    test('400/409/422 -> Validation with fieldErrors', () {
      for (final s in [400, 409, 422]) {
        final e = ApiError.fromDio(
          resp(s, {
            'errors': ['Name is required', 'Bad date'],
          }),
        );
        expect(e, isA<ValidationError>());
        expect((e as ValidationError).fieldErrors, [
          'Name is required',
          'Bad date',
        ]);
        expect(e.statusCode, s);
        expect(e.message, 'Name is required\nBad date');
        expect(e.isPermanent, isTrue);
      }
    });
    test('429 parses Retry-After', () {
      final e = ApiError.fromDio(
        resp(429, {'error': 'slow down'}, headers: {'retry-after': '7'}),
      );
      expect(e, isA<RateLimitedError>());
      expect((e as RateLimitedError).retryAfter, const Duration(seconds: 7));
      expect(e.isTransient, isTrue);
    });
    test('429 without header', () {
      final e = ApiError.fromDio(resp(429, null));
      expect((e as RateLimitedError).retryAfter, isNull);
    });
    test('5xx -> Server, transient', () {
      for (final s in [500, 502, 503, 504]) {
        final e = ApiError.fromDio(resp(s, {'error': 'boom'}));
        expect(e, isA<ServerError>());
        expect(e.statusCode, s);
        expect(e.isTransient, isTrue);
        expect(e.isPermanent, isFalse);
      }
    });
    test('network and timeout are transient', () {
      expect(const NetworkError().isTransient, isTrue);
      expect(const TimeoutError().isTransient, isTrue);
      expect(const CancelledError().isTransient, isFalse);
      expect(const UnauthorizedError().isTransient, isFalse);
    });
    test('unexpected 4xx -> ServerError, not transient', () {
      final e = ApiError.fromDio(resp(418, 'teapot'));
      expect(e, isA<ServerError>());
      expect(e.message, 'teapot');
      expect(e.isTransient, isFalse);
    });
  });

  group('message extraction', () {
    test('error string', () {
      expect(ApiError.extractMessage({'error': 'a'}), 'a');
    });
    test('errors list of strings and maps', () {
      expect(
        ApiError.extractMessage({
          'errors': [
            'a',
            {'message': 'b'},
          ],
        }),
        'a\nb',
      );
    });
    test('message', () {
      expect(ApiError.extractMessage({'message': 'm'}), 'm');
    });
    test('string body / empty / null', () {
      expect(ApiError.extractMessage('plain'), 'plain');
      expect(ApiError.extractMessage(' '), isNull);
      expect(ApiError.extractMessage(null), isNull);
      expect(ApiError.extractMessage({'x': 1}), isNull);
    });
  });
}
