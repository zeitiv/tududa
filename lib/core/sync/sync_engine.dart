// ignore_for_file: prefer_initializing_formals -- named params cannot be private.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/session/session_controller.dart';
import '../api/api_error.dart';
import '../api/api_providers.dart';
import '../connectivity/connectivity_service.dart';
import '../db/app_database.dart';
import '../time/user_clock.dart';
import '../../auth/session/session_providers.dart';
import 'id_resolver.dart';
import 'merge.dart';
import 'outbox_dao.dart';
import 'retry_policy.dart';
import 'sync_handler.dart';
import 'sync_handlers.dart';
import 'sync_status.dart';
import 'sync_triggers.dart';

export 'pull_paged.dart';

/// Runs sync cycles: pull (handlers in dependency order) -> push (due outbox
/// entries, oldest first). One cycle at a time; requests that arrive while a
/// cycle runs are merged into a single follow-up cycle.
///
/// Auth: a 401 triggers one `reauthenticate()` per cycle; if that fails the
/// queue pauses with [SyncPhase.signedOut] and keeps every entry until a
/// `login` or `manual` request. Entries are only deleted by
/// [onAccountChanged].
class SyncEngine {
  SyncEngine({
    required this.db,
    required List<SyncHandler> handlers,
    required Dio Function() dio,
    required this.clock,
    required Future<bool> Function() reauthenticate,
    bool Function()? isOnline,
    DateTime Function()? now,
    RetryPolicy? retryPolicy,
    this.fullReconcileInterval = const Duration(hours: 6),
    Timer Function(Duration, void Function())? createTimer,
    this.ref,
  }) : _handlers = _ordered(handlers),
       _dio = dio,
       _reauthenticate = reauthenticate,
       _isOnline = isOnline ?? (() => true),
       _now = now ?? (() => DateTime.now().toUtc()),
       _policy = retryPolicy ?? RetryPolicy(),
       _createTimer = createTimer ?? Timer.new;

  final AppDatabase db;
  final UserClock clock;
  final Ref? ref;
  final Duration fullReconcileInterval;
  final List<SyncHandler> _handlers;
  final Dio Function() _dio;
  final Future<bool> Function() _reauthenticate;
  final bool Function() _isOnline;
  final DateTime Function() _now;
  final RetryPolicy _policy;
  final Timer Function(Duration, void Function()) _createTimer;

  final _controller = StreamController<SyncStatus>.broadcast(sync: true);
  SyncStatus _status = const SyncStatus();
  final List<ConflictNotice> _notices = [];

  StreamSubscription<OutboxCounts>? _countsSub;
  Timer? _wake;

  bool _running = false;
  Future<void>? _runFuture;
  SyncReason? _queuedReason;
  Completer<void>? _followUp;
  bool _signedOut = false;
  bool _reauthTried = false;
  bool _disposed = false;
  int _epoch = 0;

  static List<SyncHandler> _ordered(List<SyncHandler> handlers) {
    final order = SyncEntity.pullOrder;
    return [...handlers]..sort(
      (a, b) => order.indexOf(a.entity).compareTo(order.indexOf(b.entity)),
    );
  }

  /// Current status; [statuses] emits every change (synchronously).
  SyncStatus get status => _status;
  Stream<SyncStatus> get statuses => _controller.stream;

  /// Loads persisted state and starts tracking outbox counts. Idempotent.
  Future<void> start() async {
    if (_countsSub != null || _disposed) return;
    await db.outboxDao.recoverInflight();
    final last = await db.syncStateDao.lastSyncAt();
    final counts = await db.outboxDao.countsNow();
    _update(
      _status.copyWith(
        lastSyncAt: last,
        pendingCount: counts.pending,
        failedCount: counts.failed,
        stuckCount: counts.stuck,
      ),
    );
    _countsSub = db.outboxDao.counts().listen((c) {
      _update(
        _status.copyWith(
          pendingCount: c.pending,
          failedCount: c.failed,
          stuckCount: c.stuck,
        ),
      );
    });
  }

  /// Asks for a cycle and completes when the cycle covering this request has
  /// finished. Overlapping requests share one follow-up cycle.
  Future<void> requestSync(SyncReason reason) {
    if (_disposed) return Future.value();
    if (_running) {
      _queuedReason = _stronger(_queuedReason, reason);
      return (_followUp ??= Completer<void>()).future;
    }
    return _runFuture = _run(reason);
  }

  static SyncReason _stronger(SyncReason? a, SyncReason b) {
    if (a == null) return b;
    int rank(SyncReason r) => switch (r) {
      SyncReason.login => 3,
      SyncReason.manual => 2,
      _ => 1,
    };
    return rank(b) > rank(a) ? b : a;
  }

  Future<void> _run(SyncReason first) async {
    _running = true;
    var reason = first;
    Completer<void>? waiting;
    try {
      while (true) {
        try {
          await _cycle(reason);
        } catch (e, st) {
          // A bug in a handler must not wedge the engine.
          if (kDebugMode) debugPrint('sync cycle failed: $e\n$st');
          _setPhase(SyncPhase.error, error: '$e');
        }
        waiting?.complete();
        final next = _queuedReason;
        if (next == null) break;
        reason = next;
        _queuedReason = null;
        waiting = _followUp;
        _followUp = null;
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _cycle(SyncReason reason) async {
    final epoch = _epoch;
    final forced = reason == SyncReason.manual || reason == SyncReason.login;
    if (_signedOut && !forced) return;
    if (!forced && !_isOnline()) {
      _setPhase(SyncPhase.offline);
      return;
    }
    _signedOut = false;
    _reauthTried = false;
    _setPhase(SyncPhase.syncing, clearError: true);

    final start = _now().toUtc();
    final ctx = SyncContext(
      db: db,
      dio: _dio,
      clock: clock,
      now: start,
      ref: ref,
      reason: reason,
      onNotice: _addNotice,
    );
    if (forced) await db.outboxDao.retryNow();
    await db.outboxDao.recoverInflight();

    var offline = false;
    String? error;

    // Pull.
    for (final h in _handlers) {
      if (epoch != _epoch) return;
      try {
        await _withAuth(() => _pullOne(h, ctx, reason));
      } on _SignedOut {
        return _finish(epoch, signedOut: true);
      } on ApiError catch (e) {
        if (e is NetworkError || e is TimeoutError) {
          offline = true;
          break;
        }
        error = e.message;
      }
    }
    if (epoch != _epoch) return;

    // Push.
    if (!offline) {
      try {
        final outcome = await _pushAll(ctx, epoch);
        offline = outcome.offline;
        error ??= outcome.error;
      } on _SignedOut {
        return _finish(epoch, signedOut: true);
      }
    }
    if (epoch != _epoch) return;
    await _finish(epoch, offline: offline, error: error);
  }

  Future<void> _finish(
    int epoch, {
    bool signedOut = false,
    bool offline = false,
    String? error,
  }) async {
    if (epoch != _epoch) return;
    _signedOut = signedOut;
    final counts = await db.outboxDao.countsNow();
    if (epoch != _epoch) return;
    final ok = !signedOut && !offline && error == null;
    final lastSync = ok ? _now().toUtc() : null;
    _update(
      _status.copyWith(
        phase: signedOut
            ? SyncPhase.signedOut
            : offline
            ? SyncPhase.offline
            : error != null
            ? SyncPhase.error
            : SyncPhase.idle,
        pendingCount: counts.pending,
        failedCount: counts.failed,
        stuckCount: counts.stuck,
        lastSyncAt: lastSync,
        lastError: error,
        clearError: error == null,
      ),
    );
    await _scheduleWake();
  }

  Future<void> _scheduleWake() async {
    _wake?.cancel();
    _wake = null;
    if (_disposed || _signedOut) return;
    final now = _now().toUtc();
    final next = await db.outboxDao.nextDueAfter(now);
    if (next == null || _disposed) return;
    final delay = next.difference(now);
    _wake = _createTimer(
      delay < const Duration(milliseconds: 250)
          ? const Duration(milliseconds: 250)
          : delay,
      () => unawaited(requestSync(SyncReason.scheduled)),
    );
  }

  /// Runs [op]; on a 401 re-authenticates once per cycle and retries.
  Future<T> _withAuth<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on UnauthorizedError {
      if (_reauthTried || !await _tryReauth()) throw const _SignedOut();
      try {
        return await op();
      } on UnauthorizedError {
        throw const _SignedOut();
      }
    }
  }

  Future<bool> _tryReauth() async {
    _reauthTried = true;
    try {
      return await _reauthenticate();
    } catch (_) {
      return false;
    }
  }

  Future<void> _pullOne(
    SyncHandler handler,
    SyncContext ctx,
    SyncReason reason,
  ) async {
    final entity = handler.entity;
    final st = await db.syncStateDao.get(entity);
    final lastFull = st?.lastFullReconcileAt;
    final full =
        reason == SyncReason.login ||
        lastFull == null ||
        ctx.now.difference(lastFull) > fullReconcileInterval;
    final hctx = ctx.withCursor(st?.lastPullCursor);
    if (full) {
      await handler.fullReconcile(hctx);
    } else {
      await handler.pull(hctx);
    }
    await db.syncStateDao.update(
      entity,
      lastPullCursor: Value(ctx.serverNow),
      lastSyncAt: Value(ctx.now),
      lastFullReconcileAt: full ? Value(ctx.now) : const Value.absent(),
    );
  }

  Future<({bool offline, String? error})> _pushAll(
    SyncContext ctx,
    int epoch,
  ) async {
    final byEntity = {for (final h in _handlers) h.entity: h};
    // Rows with an entry that failed: later entries of the same row wait.
    final failedKeys = <String>{};
    String? error;
    var progress = false;
    var waiting = <int>{};
    do {
      progress = false;
      waiting = <int>{};
      // Rows with an entry left unsent in this pass (dependency wait).
      final blocked = {...failedKeys};
      final due = await db.outboxDao.due(_now());
      for (final e in due) {
        if (epoch != _epoch) return (offline: false, error: error);
        final key = '${e.entity}:${e.localId}';
        final handler = byEntity[e.entity];
        if (waiting.contains(e.id) || blocked.contains(key)) continue;
        if (handler == null) {
          blocked.add(key);
          continue;
        }
        final r = await _pushOne(handler, ctx, e);
        switch (r) {
          case _Pushed():
            progress = true;
          case _Waiting():
            waiting.add(e.id);
            blocked.add(key);
          case _Failed(:final offline, :final message):
            failedKeys.add(key);
            blocked.add(key);
            error ??= offline ? null : message;
            if (offline) return (offline: true, error: error);
        }
      }
    } while (progress && waiting.isNotEmpty);
    return (offline: false, error: error);
  }

  Future<_PushOutcome> _pushOne(
    SyncHandler handler,
    SyncContext ctx,
    OutboxEntry e,
  ) async {
    final dao = db.outboxDao;
    await dao.markInflight(e.id);
    try {
      final PushResult result;
      try {
        result = await _withAuth(() => handler.push(ctx, e));
      } on DependencyPendingException {
        await dao.markPending(e.id);
        return const _Waiting();
      }
      switch (result) {
        case PushOk() || PushDropped():
          await dao.remove(e.id);
          return const _Pushed();
        case PushWaitForDependency():
          await dao.markPending(e.id);
          return const _Waiting();
        case PushRetryLater(:final delay):
          await dao.markFailed(
            e.id,
            error: 'Retry requested',
            nextAttemptAt: _now().add(delay ?? _policy.backoff(e.attempts + 1)),
          );
          return const _Failed(offline: false, message: null);
      }
    } on _SignedOut {
      await dao.markPending(e.id);
      rethrow;
    } on ApiError catch (err) {
      return _onPushError(handler, ctx, e, err);
    } catch (err) {
      return _onPushError(handler, ctx, e, ServerError(500, '$err'));
    }
  }

  Future<_PushOutcome> _onPushError(
    SyncHandler handler,
    SyncContext ctx,
    OutboxEntry e,
    ApiError err,
  ) async {
    final dao = db.outboxDao;
    final offline = err is NetworkError || err is TimeoutError;
    switch (_policy.classify(err, attemptsSoFar: e.attempts)) {
      case Reauthenticate():
        // _withAuth already tried; a second 401 means signed out.
        await dao.markPending(e.id);
        throw const _SignedOut();
      case RollbackAndRemove():
        try {
          await handler.rollback(ctx, e, err);
        } catch (rollbackError) {
          await dao.markStuck(e.id, error: 'Rollback failed: $rollbackError');
          return _Failed(offline: false, message: err.message);
        }
        await dao.remove(e.id);
        return const _Pushed();
      case GiveUpAutomatic():
        await dao.markStuck(e.id, error: err.message);
        return _Failed(offline: offline, message: err.message);
      case RetryAfter(:final delay):
        await dao.markFailed(
          e.id,
          error: err.message,
          nextAttemptAt: _now().add(delay),
        );
        return _Failed(offline: offline, message: err.message);
    }
  }

  /// Publishes a conflict notice (also used by user-initiated discards).
  void addNotice(ConflictNotice n) => _addNotice(n);

  void _addNotice(ConflictNotice n) {
    _notices.add(n);
    if (_notices.length > 50) _notices.removeAt(0);
    _update(_status.copyWith(notices: List.unmodifiable(_notices)));
  }

  /// Clears the conflict notices (the user has seen them).
  void dismissNotices() {
    _notices.clear();
    _update(_status.copyWith(notices: const []));
  }

  /// A different account or server: stops the current cycle, then deletes
  /// every local row, the outbox and all sync state. The only way entries are
  /// ever dropped.
  Future<void> onAccountChanged() async {
    _epoch++;
    _wake?.cancel();
    _wake = null;
    _queuedReason = null;
    final follow = _followUp;
    _followUp = null;
    try {
      await _runFuture;
    } catch (_) {}
    follow?.complete();
    await db.wipe();
    _signedOut = false;
    _notices.clear();
    _update(const SyncStatus());
  }

  Future<void> dispose() async {
    _disposed = true;
    _epoch++;
    _wake?.cancel();
    await _countsSub?.cancel();
    _countsSub = null;
    try {
      await _runFuture;
    } catch (_) {}
    await _controller.close();
  }

  void _setPhase(SyncPhase phase, {String? error, bool clearError = false}) =>
      _update(
        _status.copyWith(
          phase: phase,
          lastError: error,
          clearError: clearError,
        ),
      );

  void _update(SyncStatus next) {
    if (_disposed || next == _status) return;
    _status = next;
    _controller.add(next);
  }
}

class _SignedOut implements Exception {
  const _SignedOut();
}

sealed class _PushOutcome {
  const _PushOutcome();
}

class _Pushed extends _PushOutcome {
  const _Pushed();
}

class _Waiting extends _PushOutcome {
  const _Waiting();
}

class _Failed extends _PushOutcome {
  const _Failed({required this.offline, required this.message});
  final bool offline;
  final String? message;
}

/// The app's engine. Handlers come from [syncHandlersProvider]. Signing in
/// requests a `login` cycle (with full reconcile). Triggers (connectivity,
/// resume, writes, timer) are started separately: watch [syncTriggersProvider]
/// once at the app root.
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final engine = SyncEngine(
    db: ref.watch(appDatabaseProvider),
    handlers: ref.watch(syncHandlersProvider),
    dio: () => ref.read(dioProvider),
    clock: ref.watch(userClockProvider),
    reauthenticate: () =>
        ref.read(sessionControllerProvider.notifier).reauthenticate(),
    isOnline: () =>
        ref.read(connectivityServiceProvider).current != NetworkStatus.offline,
    ref: ref,
  );
  unawaited(engine.start());
  final session = ref.read(sessionControllerProvider.notifier);
  session.onAccountChanged = engine.onAccountChanged;
  ref.onDispose(() => session.onAccountChanged = null);
  ref.listen<SessionState>(sessionControllerProvider, (prev, next) {
    final wasIn = prev is SessionSignedIn && !prev.offline;
    if (next is SessionSignedIn && !next.offline && !wasIn) {
      unawaited(engine.requestSync(SyncReason.login));
    }
  });
  ref.onDispose(() => unawaited(engine.dispose()));
  return engine;
});
