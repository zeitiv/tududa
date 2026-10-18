import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/time/calendar_date.dart';
import 'package:tududa/tasks/domain/recurrence/describe.dart';
import 'package:tududa/tasks/domain/recurrence/next_occurrence.dart';
import 'package:tududa/tasks/domain/recurrence/recurrence_rule.dart';

CalendarDate d(String s) => CalendarDate.parse(s);

void main() {
  group('RecurrenceRule', () {
    test('value equality and hashCode ignore set order', () {
      final a = RecurrenceRule(
        type: RecurrenceType.weekly,
        weekdays: {1, 3},
        interval: 2,
      );
      final b = RecurrenceRule(
        type: RecurrenceType.weekly,
        weekdays: {3, 1},
        interval: 2,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == a.copyWith(interval: 3), isFalse);
      expect(a == a.copyWith(completionBased: true), isFalse);
    });

    test('weekdays are immutable', () {
      final r = RecurrenceRule(type: RecurrenceType.weekly, weekdays: {1});
      expect(() => r.weekdays.add(2), throwsUnsupportedError);
    });

    test('none', () {
      expect(RecurrenceRule.none().isRecurring, isFalse);
      expect(
        RecurrenceType.fromBackend('monthly_weekday'),
        RecurrenceType.monthlyWeekday,
      );
      expect(RecurrenceType.fromBackend('bogus'), RecurrenceType.none);
    });

    test('toBackendFields daily', () {
      expect(
        RecurrenceRule(
          type: RecurrenceType.daily,
          interval: 3,
        ).toBackendFields(),
        {
          'recurrence_type': 'daily',
          'recurrence_interval': 3,
          'recurrence_weekday': null,
          'recurrence_weekdays': null,
          'recurrence_month_day': null,
          'recurrence_week_of_month': null,
          'recurrence_end_date': null,
          'completion_based': false,
        },
      );
    });

    test('toBackendFields weekly', () {
      expect(
        RecurrenceRule(
          type: RecurrenceType.weekly,
          weekdays: {5, 1, 3},
          endDate: d('2026-12-31'),
          completionBased: true,
        ).toBackendFields(),
        {
          'recurrence_type': 'weekly',
          'recurrence_interval': 1,
          'recurrence_weekday': null,
          'recurrence_weekdays': [1, 3, 5],
          'recurrence_month_day': null,
          'recurrence_week_of_month': null,
          'recurrence_end_date': '2026-12-31',
          'completion_based': true,
        },
      );
    });

    test(
      'toBackendFields monthly, monthly_weekday, monthly_last_day, none',
      () {
        expect(
          RecurrenceRule(
            type: RecurrenceType.monthly,
            monthDay: 15,
          ).toBackendFields(),
          {
            'recurrence_type': 'monthly',
            'recurrence_interval': 1,
            'recurrence_weekday': null,
            'recurrence_weekdays': null,
            'recurrence_month_day': 15,
            'recurrence_week_of_month': null,
            'recurrence_end_date': null,
            'completion_based': false,
          },
        );
        expect(
          RecurrenceRule(
            type: RecurrenceType.monthlyWeekday,
            weekOfMonth: 5,
            weekday: 5,
          ).toBackendFields(),
          {
            'recurrence_type': 'monthly_weekday',
            'recurrence_interval': 1,
            'recurrence_weekday': 5,
            'recurrence_weekdays': null,
            'recurrence_month_day': null,
            'recurrence_week_of_month': 5,
            'recurrence_end_date': null,
            'completion_based': false,
          },
        );
        expect(
          RecurrenceRule(type: RecurrenceType.monthlyLastDay)
              .toBackendFields()['recurrence_type'],
          'monthly_last_day',
        );
        expect(
          RecurrenceRule.none().toBackendFields()['recurrence_type'],
          'none',
        );
      },
    );
  });

  group('nextOccurrence', () {
    test('none -> null', () {
      expect(
        nextOccurrence(RecurrenceRule.none(), from: d('2026-10-14')),
        isNull,
      );
    });

    test('daily with interval', () {
      final r = RecurrenceRule(type: RecurrenceType.daily, interval: 3);
      expect(nextOccurrence(r, from: d('2026-10-14')), d('2026-10-17'));
      expect(nextOccurrence(r, from: d('2026-12-30')), d('2027-01-02'));
    });

    test('weekly weekday set', () {
      final r = RecurrenceRule(type: RecurrenceType.weekly, weekdays: {1, 3});
      expect(nextOccurrence(r, from: d('2026-10-19')), d('2026-10-21'));
      expect(nextOccurrence(r, from: d('2026-10-21')), d('2026-10-26'));
      // From a non-matching day the anchor week is still used.
      expect(nextOccurrence(r, from: d('2026-10-22')), d('2026-10-26'));
    });

    test('weekly interval counts weeks from the anchor week (Mon start)', () {
      final r = RecurrenceRule(
        type: RecurrenceType.weekly,
        weekdays: {1, 5},
        interval: 2,
      );
      // Wed 14th: Fri of the same week is still due.
      expect(nextOccurrence(r, from: d('2026-10-14')), d('2026-10-16'));
      // After Friday, skip a week.
      expect(nextOccurrence(r, from: d('2026-10-16')), d('2026-10-26'));
      // Sunday belongs to the week that started on Monday.
      expect(nextOccurrence(r, from: d('2026-10-18')), d('2026-10-26'));
    });

    test('weekly with no weekdays uses the anchor weekday', () {
      final r = RecurrenceRule(type: RecurrenceType.weekly, interval: 2);
      expect(nextOccurrence(r, from: d('2026-10-14')), d('2026-10-28'));
    });

    test('monthly Jan 31 clamps to Feb 28 then returns to 31', () {
      final r = RecurrenceRule(type: RecurrenceType.monthly, monthDay: 31);
      expect(nextOccurrence(r, from: d('2027-01-31')), d('2027-02-28'));
      expect(nextOccurrence(r, from: d('2027-02-28')), d('2027-03-31'));
      expect(nextOccurrence(r, from: d('2027-03-31')), d('2027-04-30'));
    });

    test('monthly Jan 31 in leap year 2028 -> Feb 29', () {
      final r = RecurrenceRule(type: RecurrenceType.monthly, monthDay: 31);
      expect(nextOccurrence(r, from: d('2028-01-31')), d('2028-02-29'));
      expect(nextOccurrence(r, from: d('2028-02-29')), d('2028-03-31'));
    });

    test('monthly without monthDay uses the anchor day', () {
      final r = RecurrenceRule(type: RecurrenceType.monthly);
      expect(nextOccurrence(r, from: d('2026-10-14')), d('2026-11-14'));
      expect(nextOccurrence(r, from: d('2028-02-29')), d('2028-03-29'));
    });

    test('monthly Feb 29 anchored series falls back to Feb 28', () {
      final r = RecurrenceRule(type: RecurrenceType.monthly, monthDay: 29);
      expect(nextOccurrence(r, from: d('2027-01-29')), d('2027-02-28'));
      expect(nextOccurrence(r, from: d('2028-01-29')), d('2028-02-29'));
    });

    test('monthly interval 3 crosses the year', () {
      final r = RecurrenceRule(
        type: RecurrenceType.monthly,
        monthDay: 15,
        interval: 3,
      );
      expect(nextOccurrence(r, from: d('2026-11-15')), d('2027-02-15'));
    });

    test('monthlyWeekday second Tuesday', () {
      final r = RecurrenceRule(
        type: RecurrenceType.monthlyWeekday,
        weekOfMonth: 2,
        weekday: 2,
      );
      expect(nextOccurrence(r, from: d('2026-10-13')), d('2026-11-10'));
      expect(nextOccurrence(r, from: d('2026-11-10')), d('2026-12-08'));
    });

    test('monthlyWeekday week 5 means last occurrence', () {
      final r = RecurrenceRule(
        type: RecurrenceType.monthlyWeekday,
        weekOfMonth: 5,
        weekday: 5,
      );
      expect(nextOccurrence(r, from: d('2026-10-09')), d('2026-10-30'));
      expect(nextOccurrence(r, from: d('2026-10-30')), d('2026-11-27'));
      expect(nextOccurrence(r, from: d('2027-01-29')), d('2027-02-26'));
    });

    test('monthlyWeekday first Monday where month starts on that weekday', () {
      final r = RecurrenceRule(
        type: RecurrenceType.monthlyWeekday,
        weekOfMonth: 1,
        weekday: 1,
      );
      // 2026-06-01 is a Monday.
      expect(nextOccurrence(r, from: d('2026-05-04')), d('2026-06-01'));
    });

    test('monthlyLastDay', () {
      final r = RecurrenceRule(type: RecurrenceType.monthlyLastDay);
      expect(nextOccurrence(r, from: d('2026-10-31')), d('2026-11-30'));
      expect(nextOccurrence(r, from: d('2027-01-31')), d('2027-02-28'));
      expect(nextOccurrence(r, from: d('2028-01-31')), d('2028-02-29'));
      expect(nextOccurrence(r, from: d('2028-02-29')), d('2028-03-31'));
      expect(nextOccurrence(r, from: d('2026-10-14')), d('2026-10-31'));
    });

    test('endDate is inclusive', () {
      final r = RecurrenceRule(
        type: RecurrenceType.daily,
        endDate: d('2026-10-16'),
      );
      expect(nextOccurrence(r, from: d('2026-10-15')), d('2026-10-16'));
      expect(nextOccurrence(r, from: d('2026-10-16')), isNull);
      expect(nextOccurrence(r, from: d('2026-10-20')), isNull);
    });

    test('endDate with weekly and monthly', () {
      final w = RecurrenceRule(
        type: RecurrenceType.weekly,
        weekdays: {1},
        endDate: d('2026-10-25'),
      );
      expect(nextOccurrence(w, from: d('2026-10-19')), isNull);
      final w2 = w.copyWith(endDate: d('2026-10-26'));
      expect(nextOccurrence(w2, from: d('2026-10-19')), d('2026-10-26'));
      final m = RecurrenceRule(
        type: RecurrenceType.monthlyLastDay,
        endDate: d('2026-11-29'),
      );
      expect(nextOccurrence(m, from: d('2026-10-31')), isNull);
    });

    test('completionBased uses completedOn', () {
      final r = RecurrenceRule(
        type: RecurrenceType.daily,
        interval: 2,
        completionBased: true,
      );
      expect(
        nextOccurrence(r, from: d('2026-10-10'), completedOn: d('2026-10-14')),
        d('2026-10-16'),
      );
      // Without completedOn it falls back to from.
      expect(nextOccurrence(r, from: d('2026-10-10')), d('2026-10-12'));
    });

    test('completionBased weekly and monthly', () {
      final w = RecurrenceRule(
        type: RecurrenceType.weekly,
        completionBased: true,
      );
      // Completed on a Wednesday: next is a week later.
      expect(
        nextOccurrence(w, from: d('2026-10-05'), completedOn: d('2026-10-14')),
        d('2026-10-21'),
      );
      final m = RecurrenceRule(
        type: RecurrenceType.monthly,
        completionBased: true,
      );
      expect(
        nextOccurrence(m, from: d('2026-09-01'), completedOn: d('2026-10-14')),
        d('2026-11-14'),
      );
    });

    test('schedule-based rules ignore completedOn', () {
      final r = RecurrenceRule(type: RecurrenceType.daily);
      expect(
        nextOccurrence(r, from: d('2026-10-10'), completedOn: d('2026-10-14')),
        d('2026-10-11'),
      );
    });

    test('completionBased respects endDate', () {
      final r = RecurrenceRule(
        type: RecurrenceType.daily,
        completionBased: true,
        endDate: d('2026-10-14'),
      );
      expect(
        nextOccurrence(r, from: d('2026-10-10'), completedOn: d('2026-10-14')),
        isNull,
      );
    });
  });

  group('occurrencesBetween', () {
    test('limit caps the result', () {
      final r = RecurrenceRule(type: RecurrenceType.daily);
      final out = occurrencesBetween(
        r,
        d('2026-10-14'),
        d('2026-10-14'),
        d('2030-01-01'),
        limit: 5,
      );
      expect(out.length, 5);
      expect(out.last, d('2026-10-18'));
    });

    test('anchor included when it matches, window filters', () {
      final r = RecurrenceRule(type: RecurrenceType.weekly, weekdays: {3, 5});
      final out = occurrencesBetween(
        r,
        d('2026-10-14'),
        d('2026-10-15'),
        d('2026-10-31'),
      );
      expect(out, [
        d('2026-10-16'),
        d('2026-10-21'),
        d('2026-10-23'),
        d('2026-10-28'),
        d('2026-10-30'),
      ]);
    });

    test('Jan 31 monthly series from the anchor', () {
      final r = RecurrenceRule(type: RecurrenceType.monthly);
      final out = occurrencesBetween(
        r,
        d('2027-01-31'),
        d('2027-01-01'),
        d('2027-05-31'),
      );
      expect(out, [
        d('2027-01-31'),
        d('2027-02-28'),
        d('2027-03-31'),
        d('2027-04-30'),
        d('2027-05-31'),
      ]);
    });

    test('2028 leap year series', () {
      final r = RecurrenceRule(type: RecurrenceType.monthly);
      final out = occurrencesBetween(
        r,
        d('2028-01-31'),
        d('2028-01-01'),
        d('2028-03-31'),
      );
      expect(out[1], d('2028-02-29'));
    });

    test('respects endDate and none', () {
      final r = RecurrenceRule(
        type: RecurrenceType.daily,
        endDate: d('2026-10-16'),
      );
      expect(
        occurrencesBetween(
          r,
          d('2026-10-14'),
          d('2026-10-14'),
          d('2027-01-01'),
        ),
        [d('2026-10-14'), d('2026-10-15'), d('2026-10-16')],
      );
      expect(
        occurrencesBetween(
          RecurrenceRule.none(),
          d('2026-10-14'),
          d('2026-10-14'),
          d('2027-01-01'),
        ),
        isEmpty,
      );
    });

    test('limit 0 and from after to', () {
      final r = RecurrenceRule(type: RecurrenceType.daily);
      expect(
        occurrencesBetween(
          r,
          d('2026-10-14'),
          d('2026-10-14'),
          d('2026-11-01'),
          limit: 0,
        ),
        isEmpty,
      );
      expect(
        occurrencesBetween(
          r,
          d('2026-10-14'),
          d('2026-11-01'),
          d('2026-10-20'),
        ),
        isEmpty,
      );
    });
  });

  group('describe and preview', () {
    test('weekdays kind', () {
      final desc = describeRecurrence(
        RecurrenceRule(type: RecurrenceType.weekly, weekdays: {1, 2, 3, 4, 5}),
      );
      expect(desc.kind, RecurrenceKind.weekdays);
      expect(desc.weekdays, [1, 2, 3, 4, 5]);
    });

    test('weekly, monthly kinds', () {
      expect(
        describeRecurrence(
          RecurrenceRule(
            type: RecurrenceType.weekly,
            weekdays: {5, 1},
            interval: 2,
          ),
        ),
        const RecurrenceDescription(
          kind: RecurrenceKind.weekly,
          interval: 2,
          weekdays: [1, 5],
        ),
      );
      final m = describeRecurrence(
        RecurrenceRule(type: RecurrenceType.monthly, monthDay: 15),
      );
      expect(m.kind, RecurrenceKind.monthlyOnDay);
      expect(m.monthDay, 15);
      final mw = describeRecurrence(
        RecurrenceRule(
          type: RecurrenceType.monthlyWeekday,
          weekOfMonth: 5,
          weekday: 5,
          completionBased: true,
          endDate: d('2027-01-01'),
        ),
      );
      expect(mw.kind, RecurrenceKind.monthlyOnWeekday);
      expect(mw.weekOfMonth, 5);
      expect(mw.completionBased, isTrue);
      expect(mw.endDate, d('2027-01-01'));
      expect(
        describeRecurrence(RecurrenceRule(type: RecurrenceType.monthlyLastDay))
            .kind,
        RecurrenceKind.monthlyLastDay,
      );
      expect(
        describeRecurrence(RecurrenceRule.none()).kind,
        RecurrenceKind.none,
      );
    });

    test('previewOccurrences', () {
      final r = RecurrenceRule(type: RecurrenceType.monthlyLastDay);
      expect(previewOccurrences(r, d('2028-01-15'), 3), [
        d('2028-01-31'),
        d('2028-02-29'),
        d('2028-03-31'),
      ]);
      expect(
        previewOccurrences(RecurrenceRule.none(), d('2028-01-15'), 3),
        isEmpty,
      );
    });
  });
}
