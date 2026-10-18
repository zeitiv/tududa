import 'package:flutter/material.dart';

import '../../common/widgets/surface_card.dart';
import '../../core/design/tokens.dart';
import '../../core/time/calendar_date.dart';
import '../../core/time/date_formatters.dart';
import '../../l10n/l10n_ext.dart';
import '../providers/today_provider.dart';

/// "1 h 30 min" style text for [minutes].
String formatMinutes(BuildContext context, int minutes) {
  final l10n = context.l10n;
  final h = minutes ~/ 60, m = minutes % 60;
  if (h == 0) return l10n.todayDurationM(m);
  if (m == 0) return l10n.todayDurationH(h);
  return l10n.todayDurationHm(h, m);
}

/// Date, progress ring (done / total) and remaining estimated time.
class TodayHeader extends StatelessWidget {
  const TodayHeader({super.key, required this.sections, required this.date});

  final TodaySections sections;
  final CalendarDate date;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final fmt = DateFormats(Localizations.localeOf(context));
    final minutes = sections.remainingMinutes;

    return SurfaceCard(
      padding: EdgeInsets.all(tokens.space4),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: sections.progress),
                    duration: tokens.motionMedium,
                    builder: (_, value, _) => CircularProgressIndicator(
                      key: const Key('today.ring'),
                      value: value,
                      strokeWidth: 8,
                      strokeCap: StrokeCap.round,
                      color: tokens.today,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                Text(
                  fmt.percent(sections.progress),
                  key: const Key('today.percent'),
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
          ),
          SizedBox(width: tokens.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fmt.fullDate(date),
                  key: const Key('today.date'),
                  style: theme.textTheme.titleMedium,
                ),
                SizedBox(height: tokens.space1),
                Text(
                  l10n.todayProgress(sections.doneCount, sections.totalCount),
                  key: const Key('today.progress'),
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  minutes > 0
                      ? l10n.todayMinutesLeft(formatMinutes(context, minutes))
                      : l10n.todayNoEstimate,
                  key: const Key('today.minutes'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
