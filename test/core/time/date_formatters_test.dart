import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tududa/core/time/calendar_date.dart';
import 'package:tududa/core/time/date_formatters.dart';
import 'package:tududa/l10n/gen/app_localizations.dart';

void main() {
  setUpAll(() async => initializeDateFormatting());

  const d = CalendarDate(2026, 10, 14); // Wednesday
  final en = DateFormats(const Locale('en'));
  final de = DateFormats(const Locale('de'));
  final zh = DateFormats(const Locale('zh'));

  test('mediumDate', () {
    expect(en.mediumDate(d), 'Oct 14');
    expect(de.mediumDate(d), '14. Okt.');
    expect(zh.mediumDate(d), '10月14日');
  });

  test('shortDate and fullDate', () {
    expect(en.shortDate(d), '10/14/2026');
    expect(de.shortDate(d), '14.10.2026');
    expect(en.fullDate(d), 'Wednesday, October 14, 2026');
    expect(de.fullDate(d), 'Mittwoch, 14. Oktober 2026');
    expect(zh.fullDate(d), contains('星期三'));
  });

  test('time is 12h in en, 24h in de/zh', () {
    const t = LocalTime(14, 5);
    expect(en.time(t), contains('2:05'));
    expect(en.time(t), contains('PM'));
    expect(de.time(t), '14:05');
    expect(zh.time(t), '14:05');
    expect(de.dateTime(DateTime(2026, 10, 14, 9, 30)), '14. Okt., 09:30');
  });

  test('names', () {
    expect(en.weekdayName(1, style: WeekdayStyle.long), 'Monday');
    expect(de.weekdayName(7, style: WeekdayStyle.long), 'Sonntag');
    expect(en.weekdayName(3, style: WeekdayStyle.narrow), 'W');
    expect(zh.weekdayName(1, style: WeekdayStyle.long), '星期一');
    expect(de.monthName(3), 'März');
    expect(en.monthName(10, long: false), 'Oct');
  });

  test('numbers', () {
    expect(en.number(1234.5), '1,234.5');
    expect(de.number(1234.5), '1.234,5');
    expect(en.percent(0.25), '25%');
    expect(en.number(2, decimalDigits: 2), '2.00');
  });

  test('startOfWeek honours weekStart', () {
    expect(en.weekStart, 7);
    expect(de.weekStart, 1);
    expect(en.startOfWeek(d), const CalendarDate(2026, 10, 11));
    expect(de.startOfWeek(d), const CalendarDate(2026, 10, 12));
    expect(
      DateFormats(const Locale('en'), weekStart: 1).startOfWeek(d),
      const CalendarDate(2026, 10, 12),
    );
    expect(
      de.startOfWeek(const CalendarDate(2026, 10, 18)),
      const CalendarDate(2026, 10, 12),
    ); // Sunday belongs to Mon-start week
    expect(
      en.startOfWeek(const CalendarDate(2026, 10, 11)),
      const CalendarDate(2026, 10, 11),
    );
  });

  test('relativeDay', () async {
    final l = {
      'en': await AppLocalizations.delegate.load(const Locale('en')),
      'de': await AppLocalizations.delegate.load(const Locale('de')),
      'zh': await AppLocalizations.delegate.load(const Locale('zh')),
    };
    String r(DateFormats f, String loc, int off) =>
        f.relativeDay(d.addDays(off), d, l[loc]!);
    expect(r(en, 'en', 0), 'Today');
    expect(r(en, 'en', 1), 'Tomorrow');
    expect(r(en, 'en', -1), 'Yesterday');
    expect(r(en, 'en', 3), 'in 3 days');
    expect(r(en, 'en', -3), '3 days ago');
    expect(r(en, 'en', 7), 'in 7 days');
    expect(r(en, 'en', 8), 'Oct 22');
    expect(r(en, 'en', -8), 'Oct 6');
    expect(r(de, 'de', 0), 'Heute');
    expect(r(de, 'de', 3), 'in 3 Tagen');
    expect(r(de, 'de', -2), 'vor 2 Tagen');
    expect(r(zh, 'zh', 1), '明天');
    expect(r(zh, 'zh', 3), '3天后');
    expect(r(zh, 'zh', -3), '3天前');
  });
}
