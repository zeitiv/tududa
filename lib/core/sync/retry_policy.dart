import 'dart:math';

import '../api/api_error.dart';

/// What the engine should do with an outbox entry whose push failed.
sealed class FailureAction {
  const FailureAction();
}

/// Transient failure: keep the entry, retry after [delay]
/// (state `failed`).
final class RetryAfter extends FailureAction {
  const RetryAfter(this.delay);
  final Duration delay;
}

/// Transient failure and [RetryPolicy.maxAttempts] reached: keep the entry,
/// mark it `stuck` (shown in the UI, retried on manual sync only).
final class GiveUpAutomatic extends FailureAction {
  const GiveUpAutomatic();
}

/// The server will never accept this: call `handler.rollback`, then remove
/// the entry.
final class RollbackAndRemove extends FailureAction {
  const RollbackAndRemove();
}

/// 401: re-login once. On success retry now; on failure pause the queue as
/// signed out. Never drops entries.
final class Reauthenticate extends FailureAction {
  const Reauthenticate();
}

/// Decides what to do about a failed push. Pure, so tests inject [random].
class RetryPolicy {
  RetryPolicy({
    Random? random,
    this.baseDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(minutes: 5),
    this.maxAttempts = 10,
    this.jitter = 0.25,
  }) : _random = random ?? Random();

  final Random _random;
  final Duration baseDelay;
  final Duration maxDelay;

  /// Failed attempts after which an entry becomes stuck.
  final int maxAttempts;

  /// Up to this fraction of the delay is added at random.
  final double jitter;

  /// Delay before the retry that follows the [attempt]-th failure
  /// (1-based): 2s, 4s, 8s ... capped at [maxDelay], plus jitter (the cap
  /// applies after jitter).
  Duration backoff(int attempt) {
    final exp = max(0, attempt - 1);
    final ms = baseDelay.inMilliseconds * pow(2, min(exp, 30));
    final withJitter = ms * (1 + jitter * _random.nextDouble());
    return Duration(
      milliseconds: min(withJitter, maxDelay.inMilliseconds.toDouble()).round(),
    );
  }

  /// [attemptsSoFar] is the number of failed attempts *before* this one.
  FailureAction classify(ApiError error, {required int attemptsSoFar}) {
    if (error is UnauthorizedError) return const Reauthenticate();
    // CSRF problems are healed by the HTTP stack; one that still reaches us is
    // treated as transient. Cancelled/decoding/unknown statuses too: an entry
    // is never dropped unless the server definitively refused it.
    if (error.isPermanent) return const RollbackAndRemove();
    final attempt = attemptsSoFar + 1;
    if (attempt >= maxAttempts) return const GiveUpAutomatic();
    var delay = backoff(attempt);
    if (error is RateLimitedError &&
        error.retryAfter != null &&
        error.retryAfter! > delay) {
      delay = error.retryAfter!;
    }
    return RetryAfter(delay);
  }
}
