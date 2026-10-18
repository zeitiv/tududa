import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/sync/sync_status.dart';

/// Screen-reader description of [s], e.g. "Offline, 3 changes waiting to sync".
String syncStatusLabel(SyncStatus s) {
  final waiting = s.pendingCount + s.failedCount + s.stuckCount;
  final changes = '$waiting ${waiting == 1 ? 'change' : 'changes'}';
  switch (s.phase) {
    case SyncPhase.syncing:
      return 'Syncing';
    case SyncPhase.offline:
      return waiting > 0
          ? 'Offline, $changes waiting to sync'
          : 'Offline, nothing waiting to sync';
    case SyncPhase.signedOut:
      return waiting > 0
          ? 'Signed out, $changes waiting to sync'
          : 'Signed out';
    case SyncPhase.error:
    case SyncPhase.idle:
      final problems = s.failedCount + s.stuckCount;
      if (s.phase == SyncPhase.error || s.stuckCount > 0) {
        final n = problems == 0 ? waiting : problems;
        return 'Sync problem, $n ${n == 1 ? 'change' : 'changes'} failed';
      }
      return waiting > 0 ? '$changes waiting to sync' : 'All changes synced';
  }
}

/// Compact app-bar indicator of the sync state; opens `/more/sync`.
class SyncIndicator extends ConsumerWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(syncStatusProvider);
    final scheme = Theme.of(context).colorScheme;
    final waiting = s.pendingCount + s.failedCount + s.stuckCount;
    final problems = s.failedCount + s.stuckCount;

    final Widget icon;
    int? count;
    switch (s.phase) {
      case SyncPhase.syncing:
        icon = const SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case SyncPhase.offline:
        icon = Icon(Icons.cloud_off, color: scheme.onSurfaceVariant);
        count = waiting;
      case SyncPhase.signedOut:
        icon = Icon(Icons.lock_outline, color: scheme.error);
        count = waiting;
      case SyncPhase.error:
        icon = Icon(Icons.warning_amber_rounded, color: scheme.error);
        count = problems;
      case SyncPhase.idle:
        if (s.stuckCount > 0) {
          icon = Icon(Icons.warning_amber_rounded, color: scheme.error);
          count = problems;
        } else if (waiting > 0) {
          icon = Icon(Icons.sync, color: scheme.onSurfaceVariant);
          count = waiting;
        } else {
          icon = Icon(
            Icons.check,
            size: 20,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
          );
        }
    }

    return Semantics(
      button: true,
      label: syncStatusLabel(s),
      excludeSemantics: true,
      onTap: () => context.push('/more/sync'),
      child: InkResponse(
        onTap: () => context.push('/more/sync'),
        radius: 24,
        child: SizedBox.square(
          dimension: 48,
          child: Center(
            child: count != null && count > 0
                ? Badge(label: Text('$count'), child: icon)
                : icon,
          ),
        ),
      ),
    );
  }
}
