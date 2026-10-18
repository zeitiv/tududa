import '../../core/time/date_formatters.dart';
import '../../l10n/gen/app_localizations.dart';
import '../domain/recurrence/describe.dart';
import '../domain/recurrence/recurrence_rule.dart';

/// Localized one-line description of [rule], e.g. "Every 2 weeks on Mon, Wed".
String recurrenceSummary(
  AppLocalizations l,
  DateFormats f,
  RecurrenceRule rule,
) {
  final d = describeRecurrence(rule);
  var text = switch (d.kind) {
    RecurrenceKind.none => l.quickAddRepeatNone,
    RecurrenceKind.daily => l.quickAddRecurDaily(d.interval),
    RecurrenceKind.weekdays => l.quickAddRecurWeekdays,
    RecurrenceKind.weekly =>
      d.weekdays.isEmpty
          ? l.quickAddRecurWeekly(d.interval)
          : l.quickAddRecurWeeklyOn(
              d.interval,
              d.weekdays.map(f.weekdayName).join(', '),
            ),
    RecurrenceKind.monthlyOnDay =>
      d.monthDay == null
          ? l.quickAddRecurMonthly(d.interval)
          : l.quickAddRecurMonthlyOnDay(d.interval, d.monthDay!),
    RecurrenceKind.monthlyOnWeekday => l.quickAddRecurMonthlyWeekday(
      '${d.weekOfMonth ?? 5}',
      f.weekdayName(d.weekday ?? 1, style: WeekdayStyle.long),
    ),
    RecurrenceKind.monthlyLastDay => l.quickAddRecurMonthlyLastDay,
  };
  if (d.kind == RecurrenceKind.none) return text;
  if (d.endDate != null) {
    text += ' ${l.quickAddRecurUntil(f.mediumDate(d.endDate!))}';
  }
  if (d.completionBased) text += ' ${l.quickAddRecurAfterCompletion}';
  return text;
}
