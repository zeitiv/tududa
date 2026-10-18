import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/token_lookup.dart';
import '../../core/design/tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../domain/task.dart';

/// Pops the current screen: through go_router when there is one, otherwise
/// the plain navigator (widget tests).
void popScreen(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    if (router.canPop()) router.pop();
  } else {
    Navigator.of(context).pop();
  }
}

/// Token colour of a task status.
Color taskStatusColor(AppTokens t, TaskStatus s) => switch (s) {
  TaskStatus.inProgress => t.statusInProgress,
  TaskStatus.done => t.statusDone,
  TaskStatus.archived => t.statusArchived,
  TaskStatus.waiting => t.statusWaiting,
  TaskStatus.cancelled => t.statusCancelled,
  TaskStatus.planned => t.statusPlanned,
  TaskStatus.notStarted || TaskStatus.unknown => t.statusNotStarted,
};

/// Token colour of a priority.
Color taskPriorityColor(AppTokens t, Priority p) => t.priorityFor(p.code);

/// A small tinted pill with an icon and a label.
class TaskInfoChip extends StatelessWidget {
  const TaskInfoChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: t.space3,
        vertical: t.space2 * 0.75,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(t.radiusMedium),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: t.space1),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// A read-only detail row: icon, small label and a value (text or widget).
class TaskFieldRow extends StatelessWidget {
  const TaskFieldRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.child,
    this.color,
  }) : assert(value != null || child != null);

  final IconData icon;
  final String label;
  final String? value;
  final Widget? child;

  /// Tints icon and value (overdue dates).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: t.space2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color ?? muted),
          SizedBox(width: t.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(color: muted),
                ),
                child ??
                    Text(
                      value!,
                      style: theme.textTheme.bodyLarge?.copyWith(color: color),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "45 min" / "1 h 30 min".
String formatEstimate(AppLocalizations l, int minutes) => minutes < 60
    ? l.todayDurationM(minutes)
    : l.todayDurationHm(minutes ~/ 60, minutes % 60);
