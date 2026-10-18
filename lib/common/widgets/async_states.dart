import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/sync_status.dart';
import '../../l10n/l10n_ext.dart';
import '../../tasks/widgets/api_error_message.dart';

bool _reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Renders an [AsyncValue] as loading skeleton, error-with-retry, offline,
/// empty or data. Stale data wins: once a value exists it is shown even while
/// reloading or after a failed refresh.
///
/// The non-data states scroll (always scrollable), so a surrounding
/// `RefreshIndicator` keeps working on them.
class AsyncStateView<T> extends ConsumerWidget {
  const AsyncStateView({
    super.key,
    required this.value,
    required this.data,
    this.isEmpty,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyTitle,
    this.emptyHint,
    this.emptyAction,
    this.onRetry,
    this.loading,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;

  /// Defaults to `data is Iterable && data.isEmpty`.
  final bool Function(T data)? isEmpty;

  final IconData emptyIcon;
  final String? emptyTitle;
  final String? emptyHint;

  /// Optional button under the empty state.
  final Widget? emptyAction;
  final VoidCallback? onRetry;

  /// Replaces the default [SkeletonList].
  final Widget? loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = value;
    if (!v.hasValue) {
      if (v.hasError) {
        return ScrollableState(
          child: ErrorState(error: v.error!, onRetry: onRetry),
        );
      }
      return loading ?? const SkeletonList();
    }
    final d = v.requireValue;
    final empty = isEmpty?.call(d) ?? (d is Iterable && d.isEmpty);
    if (!empty) return data(d);
    final offline = ref.watch(syncStatusProvider).phase == SyncPhase.offline;
    if (offline) {
      return ScrollableState(child: OfflineState(onRetry: onRetry));
    }
    return ScrollableState(
      child: EmptyState(
        icon: emptyIcon,
        title: emptyTitle ?? '',
        hint: emptyHint,
        action: emptyAction,
      ),
    );
  }
}

/// Centers [child] in the available space inside an always-scrollable view.
class ScrollableState extends StatelessWidget {
  const ScrollableState({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: c.maxHeight),
        child: Center(child: child),
      ),
    ),
  );
}

/// Icon, title, optional hint and optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.hint,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(
              hint!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

/// Shown for an empty list while the device is offline: the list may simply
/// not have been synced yet.
class OfflineState extends StatelessWidget {
  const OfflineState({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return EmptyState(
      icon: Icons.cloud_off_outlined,
      title: l.asyncStateOfflineTitle,
      hint: l.asyncStateOfflineHint,
      action: onRetry == null
          ? null
          : OutlinedButton(onPressed: onRetry, child: Text(l.asyncStateRetry)),
    );
  }
}

/// A localized message for [error] (typed `ApiError`s get specific text)
/// with a retry button.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return EmptyState(
      icon: Icons.error_outline,
      title: l.asyncStateErrorTitle,
      hint: apiErrorMessage(l, error),
      action: onRetry == null
          ? null
          : FilledButton(onPressed: onRetry, child: Text(l.asyncStateRetry)),
    );
  }
}

/// Placeholder rows that pulse gently; static when animations are disabled.
class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key, this.rows = 6});

  final int rows;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion(context)) {
      _c.stop();
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget bar(double? w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
    );
    return Semantics(
      label: context.l10n.asyncStateLoading,
      container: true,
      child: ExcludeSemantics(
        child: FadeTransition(
          opacity: Tween(begin: 0.45, end: 1.0).animate(_c),
          child: ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.rows,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bar(i.isEven ? 220 : 160, 14),
                        const SizedBox(height: 8),
                        bar(90, 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
