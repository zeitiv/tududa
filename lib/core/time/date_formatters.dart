import 'dart:ui';

import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../l10n/gen/app_localizations.dart';
import 'calendar_date.dart';

enum WeekdayStyle { narrow, short, long }

/// Locale-aware date, time and number formatting.
///
/// Intl needs locale data loaded first. The app calls
/// [DateFormats.ensureInitialized] at startup; tests call
/// `await initializeDateFormatting()` in `setUpAll`.
class DateFormats {
  /// [weekStart] is an ISO weekday (1 = Mon .. 7 = Sun); null uses the
  /// locale default (en: Sunday, de/zh: Monday).
  DateFormats(this.locale, {int? weekStart})
    : weekStart = weekStart ?? _defaultWeekStart(locale),
      _tag = locale.languageCode;

  final Locale locale;
  final int weekStart;
  final String _tag;

  static Future<void> ensureInitialized() => initializeDateFormatting();

  static int _defaultWeekStart(Locale l) => l.languageCode == 'en' ? 7 : 1;

  bool get _uses24h => _tag != 'en';

  static DateTime _dt(CalendarDate d) => DateTime(d.year, d.month, d.day);

  /// Numeric date: 10/14/2026, 14.10.2026, 2026/10/14.
  String shortDate(CalendarDate d) => DateFormat.yMd(_tag).format(_dt(d));

  /// Day and month: Oct 14, 14. Okt., 10月14日.
  String mediumDate(CalendarDate d) => DateFormat.MMMd(_tag).format(_dt(d));

  /// Weekday, day, month and year: Wednesday, October 14, 2026.
  String fullDate(CalendarDate d) => DateFormat.yMMMMEEEEd(_tag).format(_dt(d));

  /// Time of day: 2:05 PM (en), 14:05 (de/zh).
  String time(LocalTime t) =>
      _timeFmt().format(DateTime(2000, 1, 1, t.hour, t.minute));

  DateFormat _timeFmt() => _uses24h ? DateFormat.Hm(_tag) : DateFormat.jm(_tag);

  /// Medium date plus time for a [DateTime] (local fields as given).
  String dateTime(DateTime dt) =>
      '${DateFormat.MMMd(_tag).format(dt)}, ${_timeFmt().format(dt)}';

  /// [isoWeekday]: 1 = Monday .. 7 = Sunday.
  String weekdayName(
    int isoWeekday, {
    WeekdayStyle style = WeekdayStyle.short,
  }) {
    final d = DateTime(2024, 1, isoWeekday); // 2024-01-01 is a Monday.
    final f = switch (style) {
      WeekdayStyle.narrow => DateFormat.EEEEE(_tag),
      WeekdayStyle.short => DateFormat.E(_tag),
      WeekdayStyle.long => DateFormat.EEEE(_tag),
    };
    return f.format(d);
  }

  /// [month]: 1..12. [long] false gives the abbreviated name.
  String monthName(int month, {bool long = true}) {
    final d = DateTime(2024, month);
    return (long ? DateFormat.MMMM(_tag) : DateFormat.MMM(_tag)).format(d);
  }

  String number(num value, {int? decimalDigits}) => decimalDigits == null
      ? NumberFormat.decimalPattern(_tag).format(value)
      : NumberFormat.decimalPatternDigits(
          locale: _tag,
          decimalDigits: decimalDigits,
        ).format(value);

  /// [fraction] 0.25 -> 25%.
  String percent(num fraction) =>
      NumberFormat.percentPattern(_tag).format(fraction);

  /// Today / Tomorrow / Yesterday / in N days / N days ago within 7 days,
  /// otherwise [mediumDate].
  String relativeDay(
    CalendarDate date,
    CalendarDate today,
    AppLocalizations l10n,
  ) {
    final diff = today.daysUntil(date);
    if (diff == 0) return l10n.coreToday;
    if (diff == 1) return l10n.coreTomorrow;
    if (diff == -1) return l10n.coreYesterday;
    if (diff > 1 && diff <= 7) return l10n.coreInDays(diff);
    if (diff < -1 && diff >= -7) return l10n.coreDaysAgo(-diff);
    return mediumDate(date);
  }

  /// First day of the week containing [d], per [weekStart].
  CalendarDate startOfWeek(CalendarDate d) =>
      d.addDays(-((d.weekday - weekStart + 7) % 7));
}
