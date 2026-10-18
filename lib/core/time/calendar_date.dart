import 'package:json_annotation/json_annotation.dart';

/// A calendar day without a time or zone (Tududi's `due_date`, `YYYY-MM-DD`).
///
/// Arithmetic is done on UTC midnights so DST never shifts a day.
class CalendarDate implements Comparable<CalendarDate> {
  const CalendarDate(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  /// Parses `YYYY-MM-DD`. A full ISO timestamp is accepted too; only the first
  /// 10 characters are read (the date as written, no zone conversion).
  /// Throws [FormatException] on anything else.
  factory CalendarDate.parse(String input) {
    final s = input.trim();
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
    if (m == null || (s.length > 10 && !'T '.contains(s[10]))) {
      throw FormatException('Invalid calendar date', input);
    }
    final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
    final check = DateTime.utc(y, mo, d);
    if (check.year != y || check.month != mo || check.day != d) {
      throw FormatException('Invalid calendar date', input);
    }
    return CalendarDate(y, mo, d);
  }

  static CalendarDate? tryParse(String? input) {
    if (input == null) return null;
    try {
      return CalendarDate.parse(input);
    } on FormatException {
      return null;
    }
  }

  /// The date components of [dt] as they are (no zone conversion).
  factory CalendarDate.fromDateTime(DateTime dt) =>
      CalendarDate(dt.year, dt.month, dt.day);

  DateTime get _utc => DateTime.utc(year, month, day);

  /// `YYYY-MM-DD`.
  String toIso() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  CalendarDate addDays(int days) =>
      CalendarDate.fromDateTime(_utc.add(Duration(days: days)));

  /// ISO weekday: Monday = 1 ... Sunday = 7.
  int get weekday => _utc.weekday;

  /// Midnight (local time) at the start of this day.
  DateTime toLocalDateTime() => DateTime(year, month, day);

  bool isBefore(CalendarDate other) => compareTo(other) < 0;
  bool isAfter(CalendarDate other) => compareTo(other) > 0;

  /// Whole days from this date to [other] (negative if [other] is earlier).
  int daysUntil(CalendarDate other) => other._utc.difference(_utc).inDays;

  @override
  int compareTo(CalendarDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is CalendarDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();
}

/// Use as `@CalendarDateConverter()` / `@NullableCalendarDateConverter()`.
class CalendarDateConverter implements JsonConverter<CalendarDate, String> {
  const CalendarDateConverter();
  @override
  CalendarDate fromJson(String json) => CalendarDate.parse(json);
  @override
  String toJson(CalendarDate object) => object.toIso();
}

class NullableCalendarDateConverter
    implements JsonConverter<CalendarDate?, String?> {
  const NullableCalendarDateConverter();
  @override
  CalendarDate? fromJson(String? json) =>
      json == null ? null : CalendarDate.tryParse(json);
  @override
  String? toJson(CalendarDate? object) => object?.toIso();
}

/// A wall-clock time of day (Tududi's `due_time`, `HH:mm`).
class LocalTime implements Comparable<LocalTime> {
  const LocalTime(this.hour, this.minute)
    : assert(hour >= 0 && hour < 24),
      assert(minute >= 0 && minute < 60);

  final int hour;
  final int minute;

  /// Parses `HH:mm` (also `HH:mm:ss`, seconds ignored).
  /// Throws [FormatException] otherwise.
  factory LocalTime.parse(String input) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$')
        .firstMatch(input.trim());
    if (m == null) throw FormatException('Invalid time', input);
    final h = int.parse(m[1]!), mi = int.parse(m[2]!);
    if (h > 23 || mi > 59) throw FormatException('Invalid time', input);
    return LocalTime(h, mi);
  }

  static LocalTime? tryParse(String? input) {
    if (input == null) return null;
    try {
      return LocalTime.parse(input);
    } on FormatException {
      return null;
    }
  }

  /// `HH:mm`.
  String format() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  int get minutesSinceMidnight => hour * 60 + minute;

  @override
  int compareTo(LocalTime other) =>
      minutesSinceMidnight.compareTo(other.minutesSinceMidnight);

  @override
  bool operator ==(Object other) =>
      other is LocalTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => format();
}

class LocalTimeConverter implements JsonConverter<LocalTime, String> {
  const LocalTimeConverter();
  @override
  LocalTime fromJson(String json) => LocalTime.parse(json);
  @override
  String toJson(LocalTime object) => object.format();
}

class NullableLocalTimeConverter implements JsonConverter<LocalTime?, String?> {
  const NullableLocalTimeConverter();
  @override
  LocalTime? fromJson(String? json) =>
      json == null ? null : LocalTime.tryParse(json);
  @override
  String? toJson(LocalTime? object) => object?.format();
}
