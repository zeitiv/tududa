import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'merge.dart';
import 'sync_engine.dart';

enum SyncPhase {
  /// Nothing running; everything that could be sent was sent.
  idle,
  syncing,

  /// No connection (nothing was attempted) or the server was unreachable.
  offline,

  /// The last cycle failed for a reason other than connectivity or auth.
  error,

  /// The session expired and silent re-login failed; the queue is paused and
  /// every entry is kept until the user signs in again.
  signedOut,
}

@immutable
class SyncStatus {
  const SyncStatus({
    this.phase = SyncPhase.idle,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.stuckCount = 0,
    this.lastSyncAt,
    this.notices = const [],
    this.lastError,
  });

  final SyncPhase phase;
  final int pendingCount;
  final int failedCount;
  final int stuckCount;
  final DateTime? lastSyncAt;

  /// Conflicts resolved automatically, newest last (capped at 50).
  final List<ConflictNotice> notices;
  final String? lastError;

  bool get hasUnsynced => pendingCount + failedCount + stuckCount > 0;

  SyncStatus copyWith({
    SyncPhase? phase,
    int? pendingCount,
    int? failedCount,
    int? stuckCount,
    DateTime? lastSyncAt,
    List<ConflictNotice>? notices,
    String? lastError,
    bool clearError = false,
  }) => SyncStatus(
    phase: phase ?? this.phase,
    pendingCount: pendingCount ?? this.pendingCount,
    failedCount: failedCount ?? this.failedCount,
    stuckCount: stuckCount ?? this.stuckCount,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    notices: notices ?? this.notices,
    lastError: clearError ? null : (lastError ?? this.lastError),
  );

  @override
  bool operator ==(Object other) =>
      other is SyncStatus &&
      other.phase == phase &&
      other.pendingCount == pendingCount &&
      other.failedCount == failedCount &&
      other.stuckCount == stuckCount &&
      other.lastSyncAt == lastSyncAt &&
      other.lastError == lastError &&
      listEquals(other.notices, notices);

  @override
  int get hashCode => Object.hash(
    phase,
    pendingCount,
    failedCount,
    stuckCount,
    lastSyncAt,
    lastError,
    notices.length,
  );

  @override
  String toString() =>
      'SyncStatus($phase, pending: $pendingCount, failed: $failedCount, '
      'stuck: $stuckCount, lastSyncAt: $lastSyncAt, '
      'notices: ${notices.length}, error: $lastError)';
}

/// Mirrors [SyncEngine.statuses] for widgets:
/// `ref.watch(syncStatusProvider).phase`.
class SyncStatusNotifier extends Notifier<SyncStatus> {
  @override
  SyncStatus build() {
    final engine = ref.watch(syncEngineProvider);
    final sub = engine.statuses.listen((s) => state = s);
    ref.onDispose(sub.cancel);
    return engine.status;
  }
}

final syncStatusProvider = NotifierProvider<SyncStatusNotifier, SyncStatus>(
  SyncStatusNotifier.new,
);
