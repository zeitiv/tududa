import '../../../core/time/calendar_date.dart';
import 'recurrence_rule.dart';

const int _maxPeriods = 100000;

int daysInMonth(int year, int month) => DateTime.utc(year, month + 1, 0).day;

/// Adds [months] to the month of [d]; returns (year, month).
(int, int) _addMonths(CalendarDate d, int months) {
  final idx = d.year * 12 + (d.month - 1) + months;
  return (idx ~/ 12, idx % 12 + 1);
}

/// All dates of the schedule that are on or after [anchor], ascending, up to
/// the rule's end date (inclusive). The pattern is evaluated per period
/// counted from the anchor (week starts on Monday).
Iterable<CalendarDate> _schedule(RecurrenceRule r, CalendarDate anchor) sync* {
  final interval = r.interval < 1 ? 1 : r.interval;
  final end = r.endDate;

  bool past(CalendarDate d) => end != null && d.isAfter(end);

  switch (r.type) {
    case RecurrenceType.none:
      return;
    case RecurrenceType.daily:
      for (var k = 0; k < _maxPeriods; k++) {
        final d = anchor.addDays(k * interval);
        if (past(d)) return;
        yield d;
      }
    case RecurrenceType.weekly:
      final set = r.weekdays.where((w) => w >= 1 && w <= 7).toList()..sort();
      if (set.isEmpty) set.add(anchor.weekday);
      final weekStart = anchor.addDays(-(anchor.weekday - 1));
      for (var k = 0; k < _maxPeriods; k++) {
        final ws = weekStart.addDays(7 * k * interval);
        for (final wd in set) {
          final d = ws.addDays(wd - 1);
          if (d.isBefore(anchor)) continue;
          if (past(d)) return;
          yield d;
        }
      }
    case RecurrenceType.monthly:
    case RecurrenceType.monthlyWeekday:
    case RecurrenceType.monthlyLastDay:
      for (var k = 0; k < _maxPeriods; k++) {
        final (y, m) = _addMonths(anchor, k * interval);
        final dim = daysInMonth(y, m);
        final int day;
        if (r.type == RecurrenceType.monthly) {
          final want = r.monthDay ?? anchor.day;
          day = want > dim ? dim : want;
        } else if (r.type == RecurrenceType.monthlyLastDay) {
          day = dim;
        } else {
          final wd = r.weekday ?? anchor.weekday;
          final wk = (r.weekOfMonth ?? ((anchor.day - 1) ~/ 7 + 1)).clamp(1, 5);
          if (wk >= 5) {
            final lastWd = DateTime.utc(y, m, dim).weekday;
            day = dim - ((lastWd - wd + 7) % 7);
          } else {
            final firstWd = DateTime.utc(y, m, 1).weekday;
            day = (wd - firstWd + 7) % 7 + 1 + 7 * (wk - 1);
          }
        }
        final d = CalendarDate(y, m, day);
        if (d.isBefore(anchor)) continue;
        if (past(d)) return;
        yield d;
      }
  }
}

/// The occurrence following [from] (the current schedule date), or null when
/// the rule does not repeat or the series has ended (end date inclusive).
///
/// For completion-based rules the next date is computed from [completedOn]
/// (falling back to [from]) instead of the schedule date.
CalendarDate? nextOccurrence(
  RecurrenceRule rule, {
  required CalendarDate from,
  CalendarDate? completedOn,
}) {
  if (!rule.isRecurring) return null;
  final base = rule.completionBased ? (completedOn ?? from) : from;
  for (final d in _schedule(rule, base)) {
    if (d.isAfter(base)) return d;
  }
  return null;
}

/// Occurrences of the series that starts at [anchor], restricted to
/// `from <= d <= to`, at most [limit] of them. The anchor itself is
/// included when it matches the pattern.
List<CalendarDate> occurrencesBetween(
  RecurrenceRule rule,
  CalendarDate anchor,
  CalendarDate from,
  CalendarDate to, {
  int limit = 1000,
}) {
  final out = <CalendarDate>[];
  if (!rule.isRecurring || limit <= 0) return out;
  for (final d in _schedule(rule, anchor)) {
    if (d.isAfter(to)) break;
    if (d.isBefore(from)) continue;
    out.add(d);
    if (out.length >= limit) break;
  }
  return out;
}
