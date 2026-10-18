import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/time/calendar_date.dart';

void main() {
  group('CalendarDate', () {
    test('parse / toIso round trip', () {
      final d = CalendarDate.parse('2025-03-09');
      expect((d.year, d.month, d.day), (2025, 3, 9));
      expect(d.toIso(), '2025-03-09');
      expect('$d', '2025-03-09');
    });

    test('accepts a full ISO timestamp (first 10 chars)', () {
      expect(
        CalendarDate.parse('2025-03-09T23:30:00.000Z'),
        const CalendarDate(2025, 3, 9),
      );
      expect(
        CalendarDate.parse('2025-03-09 10:00:00'),
        const CalendarDate(2025, 3, 9),
      );
    });

    test('rejects garbage and impossible dates', () {
      for (final s in ['', 'tomorrow', '2025-13-01', '2025-02-30', '25-1-1']) {
        expect(() => CalendarDate.parse(s), throwsFormatException, reason: s);
      }
      expect(CalendarDate.tryParse('x'), isNull);
      expect(CalendarDate.tryParse(null), isNull);
    });

    test('addDays crosses month, year and leap days', () {
      expect(
        const CalendarDate(2025, 1, 31).addDays(1),
        const CalendarDate(2025, 2, 1),
      );
      expect(
        const CalendarDate(2025, 12, 31).addDays(1),
        const CalendarDate(2026, 1, 1),
      );
      expect(
        const CalendarDate(2024, 2, 28).addDays(1),
        const CalendarDate(2024, 2, 29),
      );
      expect(
        const CalendarDate(2025, 3, 1).addDays(-1),
        const CalendarDate(2025, 2, 28),
      );
    });

    test('addDays is DST-safe', () {
      // US spring-forward and fall-back weekends.
      expect(
        const CalendarDate(2025, 3, 8).addDays(2),
        const CalendarDate(2025, 3, 10),
      );
      expect(
        const CalendarDate(2025, 11, 1).addDays(2),
        const CalendarDate(2025, 11, 3),
      );
    });

    test('weekday is ISO (Mon=1..Sun=7)', () {
      expect(const CalendarDate(2025, 3, 10).weekday, DateTime.monday);
      expect(const CalendarDate(2025, 3, 16).weekday, DateTime.sunday);
    });

    test('comparison and daysUntil', () {
      const a = CalendarDate(2025, 3, 9), b = CalendarDate(2025, 3, 12);
      expect(a.isBefore(b), isTrue);
      expect(b.isAfter(a), isTrue);
      expect(a.isBefore(a), isFalse);
      expect(a.daysUntil(b), 3);
      expect(b.daysUntil(a), -3);
      expect(const CalendarDate(2025, 3, 8).daysUntil(a), 1); // across DST
      expect([b, a]..sort(), [a, b]);
      expect(a, const CalendarDate(2025, 3, 9));
      expect(a.hashCode, const CalendarDate(2025, 3, 9).hashCode);
    });

    test('json converters', () {
      const c = CalendarDateConverter();
      expect(c.fromJson('2025-03-09'), const CalendarDate(2025, 3, 9));
      expect(c.toJson(const CalendarDate(2025, 3, 9)), '2025-03-09');
      const n = NullableCalendarDateConverter();
      expect(n.fromJson(null), isNull);
      expect(n.toJson(null), isNull);
      expect(
        n.fromJson('2025-03-09T00:00:00Z'),
        const CalendarDate(2025, 3, 9),
      );
    });
  });

  group('LocalTime', () {
    test('parse / format', () {
      expect(LocalTime.parse('09:05'), const LocalTime(9, 5));
      expect(LocalTime.parse('9:05'), const LocalTime(9, 5));
      expect(LocalTime.parse('23:59:30'), const LocalTime(23, 59));
      expect(const LocalTime(7, 0).format(), '07:00');
      expect('${const LocalTime(7, 0)}', '07:00');
    });

    test('rejects invalid', () {
      for (final s in ['', '24:00', '12:60', 'noon', '1200']) {
        expect(() => LocalTime.parse(s), throwsFormatException, reason: s);
      }
      expect(LocalTime.tryParse('x'), isNull);
    });

    test('ordering and converter', () {
      expect(
        const LocalTime(9, 0).compareTo(const LocalTime(9, 1)),
        lessThan(0),
      );
      expect([const LocalTime(18, 0), const LocalTime(8, 30)]..sort(), [
        const LocalTime(8, 30),
        const LocalTime(18, 0),
      ]);
      expect(const LocalTimeConverter().toJson(const LocalTime(8, 5)), '08:05');
      expect(
        const LocalTimeConverter().fromJson('08:05'),
        const LocalTime(8, 5),
      );
      expect(const NullableLocalTimeConverter().fromJson(null), isNull);
    });
  });
}
