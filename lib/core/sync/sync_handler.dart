// ignore_for_file: prefer_initializing_formals -- named params cannot be private.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_error.dart';
import '../db/app_database.dart';
import '../time/user_clock.dart';
import 'id_resolver.dart';
import 'merge.dart';

/// Why a sync cycle was requested.
enum SyncReason {
  /// First sync after sign-in: also runs a full reconcile.
  login,

  /// User asked (pull-to-refresh, "Sync now"): ignores the offline flag,
  /// retries failed and stuck entries immediately.
  manual,
  startup,
  resume,
  connectivity,
  write,
  timer,

  /// An outbox entry's `not_before` / retry time arrived.
  scheduled,
}

/// What a handler may use during pull / push / rollback.
class SyncContext {
  SyncContext({
    required this.db,
    required Dio Function() dio,
    required this.clock,
    required this.now,
    this.ref,
    this.reason = SyncReason.manual,
    this.pullCursor,
    void Function(ConflictNotice)? onNotice,
  }) : _dio = dio,
       _onNotice = onNotice;

  final AppDatabase db;
  final Dio Function() _dio;
  final UserClock clock;

  /// Device time (UTC) when the cycle started. Use for `local_updated_at` and
  /// dirty-field timestamps (`now.millisecondsSinceEpoch`).
  final DateTime now;
  final Ref? ref;
  final SyncReason reason;

  /// Server-time instant the previous successful pull of this entity started
  /// at; null on the first pull. Pass to `pullPaged`.
  final DateTime? pullCursor;
  final void Function(ConflictNotice)? _onNotice;

  /// The signed-in client. Read lazily: throws while no server is configured.
  Dio get dio => _dio();

  /// `now` on the server's clock.
  DateTime get serverNow => now.add(clock.serverSkew);

  /// Device-clock skew to pass to `mergeFields(skew: ...)`.
  Duration get skew => clock.serverSkew;

  /// Local <-> uid / server id lookups.
  late final IdResolver ids = IdResolver(db);

  /// Reports a conflict that was resolved automatically (shown in the sync
  /// screen).
  void notice(ConflictNotice n) => _onNotice?.call(n);

  SyncContext withCursor(DateTime? cursor) => SyncContext(
    db: db,
    dio: _dio,
    clock: clock,
    now: now,
    ref: ref,
    reason: reason,
    pullCursor: cursor,
    onNotice: _onNotice,
  );
}

/// Outcome of [SyncHandler.push].
sealed class PushResult {
  const PushResult();

  /// Sent and applied locally (uid filled in, dirty fields cleared, base_json
  /// replaced). The engine removes the entry.
  static const PushResult ok = PushOk();

  /// A referenced parent/project/area/tag has no uid yet: keep the entry,
  /// without counting an attempt, and retry after other entries ran.
  static const PushResult waitForDependency = PushWaitForDependency();

  /// The entry is obsolete (row gone, nothing to send): remove it.
  static const PushResult dropped = PushDropped();

  /// Retry later without an error ([delay] defaults to the backoff).
  static PushResult retryLater([Duration? delay]) => PushRetryLater(delay);
}

final class PushOk extends PushResult {
  const PushOk();
}

final class PushWaitForDependency extends PushResult {
  const PushWaitForDependency();
}

final class PushDropped extends PushResult {
  const PushDropped();
}

final class PushRetryLater extends PushResult {
  const PushRetryLater(this.delay);
  final Duration? delay;
}

/// Teaches the engine one entity. Implemented by each feature lane and
/// registered in `syncHandlersProvider`.
///
/// Handlers throw [ApiError] (via `guard`) for HTTP failures; the engine
/// classifies them with `RetryPolicy`. They throw `DependencyPendingException`
/// (from `ctx.ids.requireUid`) when a referenced row has no uid yet.
abstract class SyncHandler {
  /// One of `SyncEntity.*`; also the `outbox.entity` this handler consumes.
  String get entity;

  /// Incremental pull: fetch what changed since `ctx.pullCursor`, merge into
  /// the local rows (see merge.dart; rows with dirty fields are merged, not
  /// overwritten) and upsert.
  Future<void> pull(SyncContext ctx);

  /// Complete pull of this entity. Besides what [pull] does, remove clean
  /// local rows the server no longer has (`db.removeCleanMissing`).
  Future<void> fullReconcile(SyncContext ctx);

  /// Sends one outbox entry. Build the request from the row's *current* state
  /// and dirty fields at send time, never from a payload captured at enqueue.
  Future<PushResult> push(SyncContext ctx, OutboxEntry e);

  /// The server permanently rejected [e] ([error] is a 400/404/409/422-class
  /// error): restore `base_json` (or delete the row if it was never on the
  /// server), clear dirty fields, report a `ConflictNotice`. The engine
  /// removes the entry afterwards.
  Future<void> rollback(SyncContext ctx, OutboxEntry e, ApiError error);
}
