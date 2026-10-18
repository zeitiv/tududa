import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/sync_actions.dart';
import '../../core/sync/sync_status.dart';
import 'sync_indicator.dart';

/// Thin banner shown while offline, signed out or when changes are stuck.
/// Collapses to zero height otherwise.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(syncStatusProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final visible =
        s.phase == SyncPhase.offline ||
        s.phase == SyncPhase.signedOut ||
        s.stuckCount > 0;
    final offline = s.phase == SyncPhase.offline;
    final fg = offline ? scheme.onSecondaryContainer : scheme.onErrorContainer;

    Widget child = const SizedBox.shrink();
    if (visible) {
      final label = syncStatusLabel(s);
      final actions = ref.read(syncActionsProvider);
      child = Semantics(
        liveRegion: true,
        container: true,
        label: label,
        child: Material(
          color: offline ? scheme.secondaryContainer : scheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      offline ? Icons.cloud_off : Icons.warning_amber_rounded,
                      size: 18,
                      color: fg,
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width - 64,
                      ),
                      child: ExcludeSemantics(
                        child: Text(
                          label,
                          style: theme.textTheme.bodySmall?.copyWith(color: fg),
                        ),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () =>
                      offline ? actions.syncNow() : actions.retryAll(),
                  child: Text(offline ? 'Sync now' : 'Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AnimatedSize(
      duration: reduce ? Duration.zero : const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      child: child,
    );
  }
}
