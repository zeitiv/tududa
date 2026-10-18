import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/api/api_error.dart';
import 'package:tududa/core/sync/retry_policy.dart';

import '../../support/api_stack.dart';

void main() {
  final policy = RetryPolicy(random: FixedRandom());

  test('backoff doubles from 2s and caps at 5 minutes', () {
    expect(
      [for (var i = 1; i <= 10; i++) policy.backoff(i).inSeconds],
      [2, 4, 8, 16, 32, 64, 128, 256, 300, 300],
    );
  });

  test('jitter only adds, up to 25 percent, and the cap still holds', () {
    final max = RetryPolicy(random: FixedRandom(1));
    expect(max.backoff(1), const Duration(milliseconds: 2500));
    expect(max.backoff(9), const Duration(minutes: 5));
  });

  test('transient errors retry with growing delay then give up at 10', () {
    const e = ServerError(503);
    for (var attempts = 0; attempts < 9; attempts++) {
      final a = policy.classify(e, attemptsSoFar: attempts);
      expect(a, isA<RetryAfter>());
      expect((a as RetryAfter).delay, policy.backoff(attempts + 1));
    }
    expect(policy.classify(e, attemptsSoFar: 9), isA<GiveUpAutomatic>());
  });

  test('429 honours Retry-After when longer than the backoff', () {
    final a = policy.classify(
      const RateLimitedError('slow down', Duration(seconds: 30)),
      attemptsSoFar: 0,
    );
    expect((a as RetryAfter).delay, const Duration(seconds: 30));
  });

  test('network, timeout and CSRF errors are transient', () {
    for (final e in <ApiError>[
      const NetworkError(),
      const TimeoutError(),
      const CsrfError(),
      const ServerError(502),
    ]) {
      expect(
        policy.classify(e, attemptsSoFar: 0),
        isA<RetryAfter>(),
        reason: '$e',
      );
    }
  });

  test('permanent errors roll back', () {
    for (final e in <ApiError>[
      const ValidationError('bad'),
      const ValidationError('conflict', statusCode: 409),
      const ValidationError('unprocessable', statusCode: 422),
      const NotFoundError(),
      const ServerError(400),
    ]) {
      expect(
        policy.classify(e, attemptsSoFar: 0),
        isA<RollbackAndRemove>(),
        reason: '$e',
      );
    }
  });

  test('401 asks to re-authenticate, never to drop', () {
    expect(
      policy.classify(const UnauthorizedError(), attemptsSoFar: 99),
      isA<Reauthenticate>(),
    );
  });
}
