import '../../../core/time/calendar_date.dart';
import '../recurrence/next_occurrence.dart' show daysInMonth;
import '../recurrence/recurrence_rule.dart';

/// Unicode-aware "not inside a word" lookbehind / lookahead.
const String lb = r'(?<![\p{L}\p{N}_])(?<!\p{L}-)';
const String la = r'(?![\p{L}\p{N}_]|-\p{L})';

/// Case-insensitive unicode regex. Texts are lower-cased by the parser first.
RegExp rx(String pattern) =>
    RegExp(pattern, unicode: true, caseSensitive: false);

/// Lower-cases [s] without ever changing its UTF-16 length, so offsets into
/// the folded text are valid offsets into the original.
String foldCase(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    final l = c.toLowerCase();
    b.write(l.length == c.length ? l : c);
  }
  return b.toString();
}

/// Resolution context shared by all grammars.
class GrammarContext {
  GrammarContext(this.today, int weekStart)
    : weekStart = ((weekStart - 1) % 7 + 7) % 7 + 1;

  final CalendarDate today;

  /// ISO weekday the week starts on (1 = Monday ... 7 = Sunday).
  final int weekStart;

  CalendarDate weekStartOf(CalendarDate d) =>
      d.addDays(-((d.weekday - weekStart + 7) % 7));

  CalendarDate get nextWeekStart => weekStartOf(today).addDays(7);

  /// The next [wd] strictly after today.
  CalendarDate upcomingWeekday(int wd) {
    var diff = (wd - today.weekday + 7) % 7;
    if (diff == 0) diff = 7;
    return today.addDays(diff);
  }

  /// [wd] inside next week (weeks begin on [weekStart]).
  CalendarDate nextWeekWeekday(int wd) =>
      nextWeekStart.addDays((wd - weekStart + 7) % 7);

  /// [wd] inside last week.
  CalendarDate lastWeekWeekday(int wd) =>
      weekStartOf(today).addDays(-7 + (wd - weekStart + 7) % 7);

  /// [wd] inside the current week; when that is already past, the next one.
  CalendarDate thisWeekWeekday(int wd) {
    final c = weekStartOf(today).addDays((wd - weekStart + 7) % 7);
    return c.isBefore(today) ? c.addDays(7) : c;
  }

  /// Saturday of this weekend (today when it is Saturday or Sunday).
  CalendarDate get upcomingWeekend =>
      today.weekday == 7 ? today : today.addDays(6 - today.weekday);

  CalendarDate addMonths(CalendarDate d, int n) {
    final idx = d.year * 12 + (d.month - 1) + n;
    final y = idx ~/ 12, m = idx % 12 + 1;
    final dim = daysInMonth(y, m);
    return CalendarDate(y, m, d.day > dim ? dim : d.day);
  }

  static CalendarDate? validDate(int y, int m, int d) {
    if (y < 1 || y > 9999 || m < 1 || m > 12 || d < 1) return null;
    if (d > daysInMonth(y, m)) return null;
    return CalendarDate(y, m, d);
  }

  /// Month/day with an optional explicit year; without one the next
  /// occurrence on or after today.
  CalendarDate? monthDay(int month, int day, [int? year]) {
    if (year != null) return validDate(year, month, day);
    for (var y = today.year; y <= today.year + 8; y++) {
      final c = validDate(y, month, day);
      if (c != null && !c.isBefore(today)) return c;
    }
    return null;
  }

  /// Next date on or after today with the given day of month.
  CalendarDate? nextDayOfMonth(int day) {
    var c = CalendarDate(today.year, today.month, 1);
    for (var i = 0; i < 24; i++) {
      final v = validDate(c.year, c.month, day);
      if (v != null && !v.isBefore(today)) return v;
      c = addMonths(c, 1);
    }
    return null;
  }
}

/// A recognised date phrase. [impliedTime] is set for phrases like "tonight".
class DateMatch {
  const DateMatch(this.start, this.end, this.date, [this.impliedTime]);
  final int start;
  final int end;
  final CalendarDate date;
  final LocalTime? impliedTime;
}

/// A recognised time phrase. Vague phrases ("morning") set [needsAnchor]:
/// they only count when attached to a date.
class TimeMatch {
  const TimeMatch(this.start, this.end, this.time, {this.needsAnchor = false});
  final int start;
  final int end;
  final LocalTime time;
  final bool needsAnchor;
}

enum RecurrenceRole { base, completion, yearly }

class RecurrenceMatch {
  const RecurrenceMatch(this.start, this.end, this.role, [this.rule]);
  final int start;
  final int end;
  final RecurrenceRole role;
  final RecurrenceRule? rule;
}

/// One language's phrase grammar. All input is already case-folded.
abstract class Grammar {
  List<DateMatch> dates(String t, GrammarContext c);
  List<TimeMatch> times(String t, GrammarContext c);
  List<RecurrenceMatch> recurrences(String t, GrammarContext c);

  /// Start offset of an "until" style marker that ends at [dateStart]
  /// (whitespace allowed in between), or null.
  int? endMarkerStart(String t, int dateStart);
}

/// Helper: start of [marker] (a regex ending in `\s*$`) in `t[0, dateStart)`.
int? markerBefore(RegExp marker, String t, int dateStart) {
  if (dateStart <= 0 || dateStart > t.length) return null;
  final m = marker.firstMatch(t.substring(0, dateStart));
  return m?.start;
}

/// Parses an int in a safe range, null when absent or too big.
int? safeInt(String? s) {
  if (s == null) return null;
  final v = int.tryParse(s);
  if (v == null || v > 100000) return null;
  return v;
}

LocalTime? mkTime(int h, int m) {
  if (h < 0 || h > 23 || m < 0 || m > 59) return null;
  return LocalTime(h, m);
}

RecurrenceRule weeklyRule(Set<int> days, int interval) => RecurrenceRule(
  type: RecurrenceType.weekly,
  interval: interval < 1 ? 1 : interval,
  weekdays: days,
);

/// ISO `YYYY-MM-DD` (shared by all languages through the English grammar).
final RegExp isoDate = rx(
  r'(?:' +
      lb +
      r'(?:on|by|due)\s+)?(?<![\p{N}-])(\d{4})-(\d{2})-(\d{2})(?![\p{N}-])',
);
