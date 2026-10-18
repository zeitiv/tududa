import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/time/calendar_date.dart';
import 'package:tududa/tasks/domain/quick_add/quick_add_parser.dart';

import 'parse_check.dart';

QuickAddParser mon() => QuickAddParser(today: today, language: 'de');
QuickAddParser sun() =>
    QuickAddParser(today: today, language: 'de', weekStart: 7);

CalendarDate d(String s) => CalendarDate.parse(s);

void main() {
  runRows('de dates (week starts Monday)', mon, [
    PC('Oma anrufen heute', title: 'Oma anrufen', due: '2026-10-14'),
    PC(
      'Oma anrufen heute Abend',
      title: 'Oma anrufen',
      due: '2026-10-14',
      time: '19:00',
      spans: [(TokenKind.date, 12, 23)],
    ),
    PC('Oma anrufen morgen', title: 'Oma anrufen', due: '2026-10-15'),
    PC('morgen Oma anrufen', title: 'Oma anrufen', due: '2026-10-15'),
    PC('Oma anrufen übermorgen', title: 'Oma anrufen', due: '2026-10-16'),
    PC('Oma anrufen gestern', title: 'Oma anrufen', due: '2026-10-13'),
    PC('Bericht Montag', title: 'Bericht', due: '2026-10-19'),
    PC('Bericht Mittwoch', title: 'Bericht', due: '2026-10-21'),
    PC('Bericht Donnerstag', title: 'Bericht', due: '2026-10-15'),
    PC('Bericht am Freitag', title: 'Bericht', due: '2026-10-16'),
    PC('Bericht am Mo', title: 'Bericht', due: '2026-10-19'),
    PC('Bericht Di', title: 'Bericht Di'),
    PC('Bericht Di.', title: 'Bericht', due: '2026-10-20'),
    PC('das mache ich so', title: 'das mache ich so'),
    PC('Bericht Sonntag', title: 'Bericht', due: '2026-10-18'),
    PC('Bericht Samstag', title: 'Bericht', due: '2026-10-17'),
    PC('Bericht nächsten Montag', title: 'Bericht', due: '2026-10-19'),
    PC('Bericht nächsten Freitag', title: 'Bericht', due: '2026-10-23'),
    PC('Bericht kommenden Freitag', title: 'Bericht', due: '2026-10-16'),
    PC('Bericht diesen Freitag', title: 'Bericht', due: '2026-10-16'),
    PC('Bericht nächste Woche', title: 'Bericht', due: '2026-10-19'),
    PC('Bericht dieses Wochenende', title: 'Bericht', due: '2026-10-17'),
    PC('Bericht am Wochenende', title: 'Bericht', due: '2026-10-17'),
    PC('Bericht nächstes Wochenende', title: 'Bericht', due: '2026-10-24'),
    PC('Bericht nächsten Monat', title: 'Bericht', due: '2026-11-14'),
    PC('Bericht in 3 Tagen', title: 'Bericht', due: '2026-10-17'),
    PC('Bericht in 2 Wochen', title: 'Bericht', due: '2026-10-28'),
    PC('Bericht in 2 Monaten', title: 'Bericht', due: '2026-12-14'),
    PC('Bericht in einer Woche', title: 'Bericht', due: '2026-10-21'),
    PC('Bericht in drei Tagen', title: 'Bericht', due: '2026-10-17'),
    PC('Fest am 5.1.', title: 'Fest', due: '2027-01-05'),
    PC('Fest 5.1.', title: 'Fest', due: '2027-01-05'),
    PC('Fest 05.01.2026', title: 'Fest', due: '2026-01-05'),
    PC('Fest am 5. Januar', title: 'Fest', due: '2027-01-05'),
    PC('Fest 5. Januar 2028', title: 'Fest', due: '2028-01-05'),
    PC('Fest am 20. Oktober', title: 'Fest', due: '2026-10-20'),
    PC('Fest am 3. März', title: 'Fest', due: '2027-03-03'),
    PC('Fest am 24. Dez', title: 'Fest', due: '2026-12-24'),
    PC('Fest 31.2.', title: 'Fest 31.2.'),
    PC('Version 1.2.3', title: 'Version 1.2.3'),
    PC('Preis 5.50', title: 'Preis 5.50'),
    PC('Fest 2026-11-03', title: 'Fest', due: '2026-11-03'),
    PC('Fest tomorrow', title: 'Fest', due: '2026-10-15'),
    PC('Fest next friday', title: 'Fest', due: '2026-10-23'),
  ]);

  runRows('de dates (week starts Sunday)', sun, [
    PC('Bericht nächsten Montag', title: 'Bericht', due: '2026-10-19'),
    PC('Bericht nächsten Sonntag', title: 'Bericht', due: '2026-10-18'),
    PC('Bericht nächste Woche', title: 'Bericht', due: '2026-10-18'),
    PC('Bericht diesen Montag', title: 'Bericht', due: '2026-10-19'),
  ]);

  runRows('de times', mon, [
    PC(
      'Zahnarzt um 15 Uhr',
      title: 'Zahnarzt',
      time: '15:00',
      spans: [(TokenKind.time, 9, 18)],
    ),
    PC('Zahnarzt 15 Uhr', title: 'Zahnarzt', time: '15:00'),
    PC('Zahnarzt um 15:30', title: 'Zahnarzt', time: '15:30'),
    PC(
      'Zahnarzt 15:30 Uhr',
      title: 'Zahnarzt',
      time: '15:30',
      spans: [(TokenKind.time, 9, 18)],
    ),
    PC('Zahnarzt um 15.30 Uhr', title: 'Zahnarzt', time: '15:30'),
    PC('Zahnarzt um 9 Uhr', title: 'Zahnarzt', time: '09:00'),
    PC('Zahnarzt 24 Uhr', title: 'Zahnarzt 24 Uhr'),
    PC('Zahnarzt 9:61', title: 'Zahnarzt 9:61'),
    PC(
      'Zahnarzt morgen um 15 Uhr',
      title: 'Zahnarzt',
      due: '2026-10-15',
      time: '15:00',
    ),
    PC(
      'Zahnarzt morgen mittags',
      title: 'Zahnarzt',
      due: '2026-10-15',
      time: '12:00',
    ),
    PC(
      'Zahnarzt morgen morgens',
      title: 'Zahnarzt',
      due: '2026-10-15',
      time: '09:00',
    ),
    PC(
      'Zahnarzt morgen abends',
      title: 'Zahnarzt',
      due: '2026-10-15',
      time: '18:00',
    ),
    PC(
      'Zahnarzt morgen Abend',
      title: 'Zahnarzt',
      due: '2026-10-15',
      time: '18:00',
    ),
    PC(
      'Zahnarzt heute Mittag',
      title: 'Zahnarzt',
      due: '2026-10-14',
      time: '12:00',
    ),
    PC(
      'Zahnarzt am Montag nachmittags',
      title: 'Zahnarzt',
      due: '2026-10-19',
      time: '15:00',
    ),
    PC('Zahnarzt mittags', title: 'Zahnarzt mittags'),
    PC('Zahnarzt abends', title: 'Zahnarzt abends'),
    PC(
      'Zahnarzt am 5.1. um 8 Uhr',
      title: 'Zahnarzt',
      due: '2027-01-05',
      time: '08:00',
    ),
    PC(
      'Zahnarzt heute Abend um 20 Uhr',
      title: 'Zahnarzt',
      due: '2026-10-14',
      time: '20:00',
    ),
    PC('Zahnarzt at 3pm', title: 'Zahnarzt', time: '15:00'),
    PC('Zahnarzt um 3 uhr', title: 'Zahnarzt', time: '03:00'),
  ]);

  runRows(
    'de syntax and cleanup',
    () => QuickAddParser(
      today: today,
      language: 'de',
      knownProjects: ['Haus Umbau', 'Haus'],
      knownAreas: ['Arbeit'],
    ),
    [
      PC('Milch kaufen #einkauf', title: 'Milch kaufen', tags: ['einkauf']),
      PC('Milch kaufen #größe', title: 'Milch kaufen', tags: ['größe']),
      PC(
        'Milch kaufen +haus umbau',
        title: 'Milch kaufen',
        project: 'Haus Umbau',
      ),
      PC(
        'Milch kaufen +Haus morgen',
        title: 'Milch kaufen',
        project: 'Haus',
        due: '2026-10-15',
      ),
      PC(
        'Milch kaufen ~arbeit !!!',
        title: 'Milch kaufen',
        area: 'Arbeit',
        priority: QuickPriority.high,
      ),
      PC(
        'Milch kaufen morgen, 15 Uhr.',
        title: 'Milch kaufen',
        due: '2026-10-15',
        time: '15:00',
      ),
      PC(
        'MILCH KAUFEN MORGEN UM 15 UHR',
        title: 'MILCH KAUFEN',
        due: '2026-10-15',
        time: '15:00',
      ),
      PC(
        'Übermorgen Müll rausbringen',
        title: 'Müll rausbringen',
        due: '2026-10-16',
      ),
      PC('Straße fegen', title: 'Straße fegen'),
      PC('morgens Sport', title: 'morgens Sport'),
      PC('Morgen kommt Besuch', title: 'kommt Besuch', due: '2026-10-15'),
    ],
  );

  runRows('de recurrence grammar', mon, [
    PC(
      'Blumen gießen jeden Tag',
      title: 'Blumen gießen',
      rec: daily(),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'täglich Blumen gießen',
      title: 'Blumen gießen',
      rec: daily(),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'Blumen gießen alle 3 Tage',
      title: 'Blumen gießen',
      rec: daily(3),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'Blumen gießen jeden zweiten Tag',
      title: 'Blumen gießen',
      rec: daily(2),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'Stand-up werktags',
      title: 'Stand-up',
      rec: weekly({1, 2, 3, 4, 5}),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'Sport jeden Montag',
      title: 'Sport',
      rec: weekly({1}),
      due: '2026-10-19',
      impliedDue: true,
    ),
    PC(
      'Sport jeden Mo und Mi',
      title: 'Sport',
      rec: weekly({1, 3}),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'Sport jeden Dienstag und Donnerstag',
      title: 'Sport',
      rec: weekly({2, 4}),
      due: '2026-10-15',
      impliedDue: true,
    ),
    PC(
      'Sport montags',
      title: 'Sport',
      rec: weekly({1}),
      due: '2026-10-19',
      impliedDue: true,
    ),
    PC(
      'Sport jeden Freitag um 18 Uhr',
      title: 'Sport',
      rec: weekly({5}),
      due: '2026-10-16',
      time: '18:00',
      impliedDue: true,
    ),
    PC(
      'Review alle 2 Wochen',
      title: 'Review',
      rec: weekly({}, 2),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'Review jede zweite Woche',
      title: 'Review',
      rec: weekly({}, 2),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'Review alle zwei Wochen',
      title: 'Review',
      rec: weekly({}, 2),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'Review wöchentlich',
      title: 'Review',
      rec: weekly({}),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'Review jede Woche',
      title: 'Review',
      rec: weekly({}),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'Miete monatlich',
      title: 'Miete',
      rec: monthly(),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'Miete jeden Monat',
      title: 'Miete',
      rec: monthly(),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'Miete jeden Monat am 15.',
      title: 'Miete',
      rec: monthly(day: 15),
      due: '2026-10-15',
      impliedDue: true,
    ),
    PC(
      'Miete jeden 1.',
      title: 'Miete',
      rec: monthly(day: 1),
      due: '2026-11-01',
      impliedDue: true,
    ),
    PC(
      'Miete alle 2 Monate',
      title: 'Miete',
      rec: monthly(interval: 2),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'Abschluss am Monatsletzten',
      title: 'Abschluss',
      rec: lastDay(),
      due: '2026-10-31',
      impliedDue: true,
    ),
    PC(
      'Abschluss am letzten Tag des Monats',
      title: 'Abschluss',
      rec: lastDay(),
      due: '2026-10-31',
      impliedDue: true,
    ),
    PC(
      'Sync jeden ersten Montag',
      title: 'Sync',
      rec: nthWeekday(1, 1),
      due: '2026-11-02',
      impliedDue: true,
    ),
    PC(
      'Sync jeden letzten Freitag',
      title: 'Sync',
      rec: nthWeekday(5, 5),
      due: '2026-10-30',
      impliedDue: true,
    ),
    PC(
      'Sync jeden zweiten Dienstag',
      title: 'Sync',
      rec: nthWeekday(2, 2),
      due: '2026-11-10',
      impliedDue: true,
    ),
    PC(
      'Sync jeden Tag bis 2026-12-31',
      title: 'Sync',
      rec: daily().copyWith(endDate: d('2026-12-31')),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'Sync jeden Tag bis zum 31.12.2026',
      title: 'Sync',
      rec: daily().copyWith(endDate: d('2026-12-31')),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'Sync täglich bis 24. Dezember',
      title: 'Sync',
      rec: daily().copyWith(endDate: d('2026-12-24')),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'Sync täglich nach Erledigung',
      title: 'Sync',
      rec: daily().copyWith(completionBased: true),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'Geburtstag jährlich',
      title: 'Geburtstag jährlich',
      hint: 'recurrence.yearly_unsupported',
    ),
    PC(
      'Geburtstag jedes Jahr',
      title: 'Geburtstag jedes Jahr',
      hint: 'recurrence.yearly_unsupported',
    ),
    PC(
      'Sport jeden Montag morgen',
      title: 'Sport',
      rec: weekly({1}),
      due: '2026-10-15',
    ),
    PC('jeden Tag', title: 'jeden Tag'),
  ]);

  group('de extras', () {
    test('disabled token start keeps text', () {
      final r = mon().parse('Oma anrufen morgen', disabledTokenStarts: {12});
      expect(r.title, 'Oma anrufen morgen');
      expect(r.dueDate, isNull);
    });
    test('English recurrence also works in German mode', () {
      final r = mon().parse('gym every monday');
      expect(r.recurrence, weekly({1}));
    });
  });
}
