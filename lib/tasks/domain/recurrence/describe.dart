import '../../../core/time/calendar_date.dart';
import 'next_occurrence.dart';
import 'recurrence_rule.dart';

enum RecurrenceKind {
  none,
  daily,

  /// Weekly on Monday to Friday.
  weekdays,
  weekly,

  /// Monthly on a day of month ([RecurrenceDescription.monthDay], null = the
  /// due date's day).
  monthlyOnDay,

  /// Monthly on the n-th weekday (`weekOfMonth` 5 = last).
  monthlyOnWeekday,
  monthlyLastDay,
}

/// Structured, non-localized description of a rule for the UI to render.
class RecurrenceDescription {
  const RecurrenceDescription({
    required this.kind,
    this.interval = 1,
    this.weekdays = const [],
    this.monthDay,
    this.weekOfMonth,
    this.weekday,
    this.endDate,
    this.completionBased = false,
  });

  final RecurrenceKind kind;
  final int interval;

  /// Sorted ISO weekdays (weekly).
  final List<int> weekdays;
  final int? monthDay;
  final int? weekOfMonth;
  final int? weekday;
  final CalendarDate? endDate;
  final bool completionBased;

  @override
  bool operator ==(Object other) =>
      other is RecurrenceDescription &&
      other.kind == kind &&
      other.interval == interval &&
      _listEq(other.weekdays, weekdays) &&
      other.monthDay == monthDay &&
      other.weekOfMonth == weekOfMonth &&
      other.weekday == weekday &&
      other.endDate == endDate &&
      other.completionBased == completionBased;

  @override
  int get hashCode => Object.hash(
    kind,
    interval,
    Object.hashAll(weekdays),
    monthDay,
    weekOfMonth,
    weekday,
    endDate,
    completionBased,
  );

  @override
  String toString() =>
      'RecurrenceDescription($kind, interval: $interval, weekdays: $weekdays, '
      'monthDay: $monthDay, weekOfMonth: $weekOfMonth, weekday: $weekday, '
      'endDate: $endDate, completionBased: $completionBased)';
}

bool _listEq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

RecurrenceDescription describeRecurrence(RecurrenceRule rule) {
  final days = rule.weekdays.toList()..sort();
  final kind = switch (rule.type) {
    RecurrenceType.none => RecurrenceKind.none,
    RecurrenceType.daily => RecurrenceKind.daily,
    RecurrenceType.weekly =>
      rule.interval == 1 && _listEq(days, const [1, 2, 3, 4, 5])
          ? RecurrenceKind.weekdays
          : RecurrenceKind.weekly,
    RecurrenceType.monthly => RecurrenceKind.monthlyOnDay,
    RecurrenceType.monthlyWeekday => RecurrenceKind.monthlyOnWeekday,
    RecurrenceType.monthlyLastDay => RecurrenceKind.monthlyLastDay,
  };
  return RecurrenceDescription(
    kind: kind,
    interval: rule.interval,
    weekdays: rule.type == RecurrenceType.weekly ? days : const [],
    monthDay: rule.type == RecurrenceType.monthly ? rule.monthDay : null,
    weekOfMonth: rule.type == RecurrenceType.monthlyWeekday
        ? rule.weekOfMonth
        : null,
    weekday: rule.type == RecurrenceType.monthlyWeekday ? rule.weekday : null,
    endDate: rule.endDate,
    completionBased: rule.completionBased,
  );
}

/// The first [count] occurrences of the series starting at [from] (inclusive
/// when [from] matches the pattern).
List<CalendarDate> previewOccurrences(
  RecurrenceRule rule,
  CalendarDate from,
  int count,
) => occurrencesBetween(
  rule,
  from,
  from,
  const CalendarDate(9999, 12, 31),
  limit: count,
);
