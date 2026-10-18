import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/time/calendar_date.dart';
import 'package:tududa/tasks/domain/quick_add/quick_add_parser.dart';

import 'parse_check.dart';

QuickAddParser mon() => QuickAddParser(today: today);
QuickAddParser sun() => QuickAddParser(today: today, weekStart: 7);

void main() {
  runRows('en dates (week starts Monday)', mon, [
    PC(
      'call mom tomorrow',
      title: 'call mom',
      due: '2026-10-15',
      spans: [(TokenKind.date, 9, 17)],
    ),
    PC('tomorrow call mom', title: 'call mom', due: '2026-10-15'),
    PC('call tomorrow mom', title: 'call mom', due: '2026-10-15'),
    PC('buy milk today', title: 'buy milk', due: '2026-10-14'),
    PC('buy milk yesterday', title: 'buy milk', due: '2026-10-13'),
    PC('dinner tonight', title: 'dinner', due: '2026-10-14', time: '19:00'),
    PC('dinner tmrw', title: 'dinner', due: '2026-10-15'),
    PC('report monday', title: 'report', due: '2026-10-19'),
    PC('report friday', title: 'report', due: '2026-10-16'),
    PC('report wednesday', title: 'report', due: '2026-10-21'),
    PC('report wed', title: 'report', due: '2026-10-21'),
    PC('report thu', title: 'report', due: '2026-10-15'),
    PC('report sat', title: 'report', due: '2026-10-17'),
    PC('report Sunday', title: 'report', due: '2026-10-18'),
    PC('report on friday', title: 'report', due: '2026-10-16'),
    PC('report by friday', title: 'report', due: '2026-10-16'),
    PC('report due friday', title: 'report', due: '2026-10-16'),
    PC('report next monday', title: 'report', due: '2026-10-19'),
    PC('report next friday', title: 'report', due: '2026-10-23'),
    PC('report next sunday', title: 'report', due: '2026-10-25'),
    PC('report this friday', title: 'report', due: '2026-10-16'),
    PC('report this monday', title: 'report', due: '2026-10-19'),
    PC('report this wednesday', title: 'report', due: '2026-10-14'),
    PC('report next week', title: 'report', due: '2026-10-19'),
    PC('report this weekend', title: 'report', due: '2026-10-17'),
    PC('report next weekend', title: 'report', due: '2026-10-24'),
    PC('report next month', title: 'report', due: '2026-11-14'),
    PC('report in 3 days', title: 'report', due: '2026-10-17'),
    PC('report in 2 weeks', title: 'report', due: '2026-10-28'),
    PC('report in 2 months', title: 'report', due: '2026-12-14'),
    PC('report in a week', title: 'report', due: '2026-10-21'),
    PC('report in one day', title: 'report', due: '2026-10-15'),
    PC('party jan 5', title: 'party', due: '2027-01-05'),
    PC('party January 5th', title: 'party', due: '2027-01-05'),
    PC('party 5 jan', title: 'party', due: '2027-01-05'),
    PC('party 5th of january', title: 'party', due: '2027-01-05'),
    PC('party dec 25', title: 'party', due: '2026-12-25'),
    PC('party oct 14', title: 'party', due: '2026-10-14'),
    PC('party oct 13', title: 'party', due: '2027-10-13'),
    PC('party nov 3 2026', title: 'party', due: '2026-11-03'),
    PC('party nov 3, 2027', title: 'party', due: '2027-11-03'),
    PC('party feb 29', title: 'party', due: '2028-02-29'),
    PC('party 2026-11-03', title: 'party', due: '2026-11-03'),
    PC('party 2026-13-45', title: 'party 2026-13-45'),
    PC('party feb 30', title: 'party feb 30'),
    PC('party 15', title: 'party 15'),
    PC('party 1/5', title: 'party 1/5'),
    PC('read 5 books', title: 'read 5 books'),
  ]);

  runRows('en dates (week starts Sunday)', sun, [
    PC('report next monday', title: 'report', due: '2026-10-19'),
    PC('report next friday', title: 'report', due: '2026-10-23'),
    PC('report next sunday', title: 'report', due: '2026-10-18'),
    PC('report next week', title: 'report', due: '2026-10-18'),
    PC('report next weekend', title: 'report', due: '2026-10-24'),
    PC('report this sunday', title: 'report', due: '2026-10-18'),
    PC('report this monday', title: 'report', due: '2026-10-19'),
    PC('report this friday', title: 'report', due: '2026-10-16'),
    PC('report monday', title: 'report', due: '2026-10-19'),
  ]);

  runRows('en times', mon, [
    PC(
      'dentist at 3pm',
      title: 'dentist',
      time: '15:00',
      spans: [(TokenKind.time, 8, 14)],
    ),
    PC('dentist 3pm', title: 'dentist', time: '15:00'),
    PC('3pm dentist', title: 'dentist', time: '15:00'),
    PC('call 3:30pm', title: 'call', time: '15:30'),
    PC('call 3:30 PM', title: 'call', time: '15:30'),
    PC('call 11am', title: 'call', time: '11:00'),
    PC('call 9 a.m.', title: 'call', time: '09:00'),
    PC('standup at 15:00', title: 'standup', time: '15:00'),
    PC('standup 15:00', title: 'standup', time: '15:00'),
    PC('standup 9:00', title: 'standup', time: '09:00'),
    PC('standup at 0:30', title: 'standup', time: '00:30'),
    PC('call at noon', title: 'call', time: '12:00'),
    PC('sleep at midnight', title: 'sleep', time: '00:00'),
    PC('call noon', title: 'call noon'),
    PC('call morning', title: 'call morning'),
    PC('meet 12am', title: 'meet', time: '00:00'),
    PC('meet 12pm', title: 'meet', time: '12:00'),
    PC('meet 12:30am', title: 'meet', time: '00:30'),
    PC(
      'drink tomorrow morning',
      title: 'drink',
      due: '2026-10-15',
      time: '09:00',
    ),
    PC(
      'drink morning tomorrow',
      title: 'drink',
      due: '2026-10-15',
      time: '09:00',
    ),
    PC(
      'drink tomorrow in the evening',
      title: 'drink',
      due: '2026-10-15',
      time: '18:00',
    ),
    PC(
      'drink tomorrow afternoon',
      title: 'drink',
      due: '2026-10-15',
      time: '14:00',
    ),
    PC('lunch tomorrow noon', title: 'lunch', due: '2026-10-15', time: '12:00'),
    PC('gym this afternoon', title: 'gym', due: '2026-10-14', time: '14:00'),
    PC('party jan 5 at 3pm', title: 'party', due: '2027-01-05', time: '15:00'),
    PC(
      'dinner tonight at 8pm',
      title: 'dinner',
      due: '2026-10-14',
      time: '20:00',
    ),
    PC(
      'call tomorrow at 15:00',
      title: 'call',
      due: '2026-10-15',
      time: '15:00',
    ),
    PC('buy 3 apples', title: 'buy 3 apples'),
    PC('meeting at 3', title: 'meeting at 3'),
    PC('room 15', title: 'room 15'),
    PC('call at 25:00', title: 'call at 25:00'),
    PC('call 13pm', title: 'call 13pm'),
    PC('version 1:2', title: 'version 1:2'),
    PC('call 3pm tomorrow', title: 'call', due: '2026-10-15', time: '15:00'),
  ]);

  runRows(
    'en syntax tokens',
    () => QuickAddParser(
      today: today,
      knownProjects: ['Website', 'Website Redesign', 'Home', 'a b'],
      knownAreas: ['Home Life', 'Work'],
      knownTags: ['Urgent'],
    ),
    [
      PC(
        'buy milk #groceries',
        title: 'buy milk',
        tags: ['groceries'],
        spans: [(TokenKind.tag, 9, 19)],
      ),
      PC('#a #b task', title: 'task', tags: ['a', 'b']),
      PC('#a #a task', title: 'task', tags: ['a']),
      PC('task #Urgent', title: 'task', tags: ['Urgent']),
      PC('task #urgent', title: 'task', tags: ['Urgent']),
      PC('task #my-tag_1', title: 'task', tags: ['my-tag_1']),
      PC('task #émoji', title: 'task', tags: ['émoji']),
      PC('task # nothing', title: 'task # nothing'),
      PC('task #', title: 'task #'),
      PC('task #!', title: 'task #!'),
      PC('task +Work', title: 'task', project: 'Work'),
      PC('task +"Two words"', title: 'task', project: 'Two words'),
      PC("task +'Two words' now", title: 'task now', project: 'Two words'),
      PC('task +"unclosed', title: 'task +"unclosed'),
      PC('task +website', title: 'task', project: 'Website'),
      PC(
        'task +website redesign now',
        title: 'task now',
        project: 'Website Redesign',
      ),
      PC('task +Website Redesign', title: 'task', project: 'Website Redesign'),
      PC('task +websites', title: 'task', project: 'websites'),
      PC('task +home.', title: 'task', project: 'Home'),
      PC('task +"website"', title: 'task', project: 'Website'),
      PC(
        'task +unknown-proj stuff',
        title: 'task stuff',
        project: 'unknown-proj',
      ),
      PC('task +1', title: 'task +1'),
      PC('task + 1', title: 'task + 1'),
      PC('+a +b task', title: '+b task', project: 'a'),
      PC('task ~Work', title: 'task', area: 'Work'),
      PC('task ~home life now', title: 'task now', area: 'Home Life'),
      PC('task ~"My Area"', title: 'task', area: 'My Area'),
      PC('task ~5', title: 'task ~5'),
      PC('task ! now', title: 'task now', priority: QuickPriority.low),
      PC('task !', title: 'task', priority: QuickPriority.low),
      PC('task !!', title: 'task', priority: QuickPriority.medium),
      PC(
        'task !!!',
        title: 'task',
        priority: QuickPriority.high,
        spans: [(TokenKind.priority, 5, 8)],
      ),
      PC('task !low', title: 'task', priority: QuickPriority.low),
      PC('task !med', title: 'task', priority: QuickPriority.medium),
      PC('task !MEDIUM', title: 'task', priority: QuickPriority.medium),
      PC('task !high', title: 'task', priority: QuickPriority.high),
      PC('task !high.', title: 'task', priority: QuickPriority.high),
      PC('!! !!! x', title: '!!! x', priority: QuickPriority.medium),
      PC('task !!!!', title: 'task !!!!'),
      PC('task !urgent', title: 'task !urgent'),
      PC('task !highest', title: 'task !highest'),
      PC('task !!high', title: 'task !!high'),
      PC('ask @bob tomorrow', title: 'ask @bob', due: '2026-10-15'),
      PC(
        'all together #x +Home ~Work !! tomorrow at 3pm',
        title: 'all together',
        tags: ['x'],
        project: 'Home',
        area: 'Work',
        priority: QuickPriority.medium,
        due: '2026-10-15',
        time: '15:00',
      ),
    ],
  );

  runRows('en non-token look-alikes', mon, [
    PC('learn c++ today', title: 'learn c++', due: '2026-10-14'),
    PC('compute a+b', title: 'compute a+b'),
    PC('wow! tomorrow', title: 'wow!', due: '2026-10-15'),
    PC('Great!!!', title: 'Great!!!'),
    PC('see http://x.com/#frag now', title: 'see http://x.com/#frag now'),
    PC('mail me@x.com', title: 'mail me@x.com'),
    PC('a#b', title: 'a#b'),
    PC('x~y', title: 'x~y'),
    PC('path/+x', title: 'path/+x'),
    PC('3 + 4 = 7', title: '3 + 4 = 7'),
    PC('why?! tomorrow', title: 'why?!', due: '2026-10-15'),
  ]);

  runRows('en title cleanup, punctuation, robustness', mon, [
    PC(
      'call mom tomorrow, 3pm.',
      title: 'call mom',
      due: '2026-10-15',
      time: '15:00',
      spans: [(TokenKind.date, 9, 17), (TokenKind.time, 19, 22)],
    ),
    PC('tomorrow, call mom', title: 'call mom', due: '2026-10-15'),
    PC(
      'call mom, tomorrow, buy milk',
      title: 'call mom, buy milk',
      due: '2026-10-15',
    ),
    PC('call mom - tomorrow', title: 'call mom', due: '2026-10-15'),
    PC('call   mom    tomorrow', title: 'call mom', due: '2026-10-15'),
    PC('  call mom tomorrow  ', title: 'call mom', due: '2026-10-15'),
    PC(
      'CALL MOM TOMORROW AT 3PM',
      title: 'CALL MOM',
      due: '2026-10-15',
      time: '15:00',
    ),
    PC('Call (mom) tomorrow!', title: 'Call (mom)!', due: '2026-10-15'),
    PC('buy milk. tomorrow', title: 'buy milk.', due: '2026-10-15'),
    PC('call mom\ntomorrow', title: 'call mom', due: '2026-10-15'),
    PC('', title: ''),
    PC('   ', title: ''),
    PC('tomorrow', title: 'tomorrow'),
    PC('tomorrow at 3pm', title: 'tomorrow at 3pm'),
    PC('#tag', title: '#tag'),
    PC('!!! monday', title: '!!! monday'),
    PC('café tomorrow', title: 'café', due: '2026-10-15'),
    PC('日本語 tomorrow', title: '日本語', due: '2026-10-15'),
    PC('😀 tomorrow 😀', title: '😀 😀', due: '2026-10-15'),
    PC('tomorrow friday call', title: 'friday call', due: '2026-10-15'),
    PC('friday tomorrow call', title: 'tomorrow call', due: '2026-10-16'),
    PC('call at 3pm at 4pm', title: 'call at 4pm', time: '15:00'),
    PC('atomorrow', title: 'atomorrow'),
    PC('tomorrows list', title: 'tomorrows list'),
    PC('monday-ish', title: 'monday-ish'),
    PC(
      'monthly review',
      title: 'review',
      rec: monthly(),
      due: '2026-10-14',
      impliedDue: true,
    ),
  ]);

  group('en disabled tokens', () {
    test('disabled kind keeps text', () {
      final r = mon().parse('call mom tomorrow #x', disabled: {TokenKind.date});
      expect(r.title, 'call mom tomorrow');
      expect(r.dueDate, isNull);
      expect(r.tags, ['x']);
    });
    test('disabled token start keeps that phrase as text', () {
      checkRow(
        mon(),
        PC(
          'call mom tomorrow',
          title: 'call mom tomorrow',
          disabledStarts: {9},
        ),
      );
    });
    test('disabled start of a missing token is ignored', () {
      checkRow(
        mon(),
        PC(
          'call mom tomorrow',
          title: 'call mom',
          due: '2026-10-15',
          disabledStarts: {0, 3},
        ),
      );
    });
    test('disabling the first date lets the second one win', () {
      checkRow(
        mon(),
        PC(
          'tomorrow friday call',
          title: 'tomorrow call',
          due: '2026-10-16',
          disabledStarts: {0},
        ),
      );
    });
    test('disabled tag, priority, project, area, time', () {
      final p = QuickAddParser(today: today);
      final r = p.parse(
        'x #t +p ~a !! 3pm',
        disabled: {
          TokenKind.tag,
          TokenKind.project,
          TokenKind.area,
          TokenKind.priority,
          TokenKind.time,
        },
      );
      expect(r.title, 'x #t +p ~a !! 3pm');
      expect(r.tokens, isEmpty);
    });
    test('disabled recurrence leaves "every monday" intact', () {
      final r = mon().parse(
        'gym every monday',
        disabled: {TokenKind.recurrence},
      );
      expect(r.title, 'gym every monday');
      expect(r.recurrence, isNull);
      expect(r.dueDate, isNull);
    });
    test('disabled implied time from tonight', () {
      final r = mon().parse('dinner tonight', disabled: {TokenKind.date});
      expect(r.dueTime, isNull);
    });
    test('disabled time start leaves the time as text', () {
      final r = mon().parse('call tomorrow at 3pm', disabledTokenStarts: {14});
      expect(r.title, 'call at 3pm');
      expect(r.dueDate?.toIso(), '2026-10-15');
      expect(r.dueTime, isNull);
    });
  });

  group('en robustness', () {
    test('very long input terminates quickly', () {
      final long = '${'word ' * 20000}tomorrow at 3pm #x';
      final sw = Stopwatch()..start();
      final r = mon().parse(long);
      expect(sw.elapsedMilliseconds < 5000, isTrue);
      expect(r.dueDate?.toIso(), '2026-10-15');
      expect(r.tags, ['x']);
    });
    test('language fallbacks understand English', () {
      for (final lang in ['de', 'zh', 'xx']) {
        final r = QuickAddParser(
          today: today,
          language: lang,
        ).parse('call tomorrow at 3pm');
        expect(r.title, 'call');
        expect(r.dueDate?.toIso(), '2026-10-15');
      }
    });
    test('ParseResult tokens are sorted by start', () {
      final r = mon().parse('!! tomorrow #a +B at 3pm');
      final starts = r.tokens.map((t) => t.start).toList();
      expect([...starts]..sort(), starts);
    });
    test('token values carry parsed objects', () {
      final r = mon().parse('x tomorrow 3pm !!! #t');
      final byKind = {for (final t in r.tokens) t.kind: t.value};
      expect(byKind[TokenKind.date].toString(), '2026-10-15');
      expect(byKind[TokenKind.time].toString(), '15:00');
      expect(byKind[TokenKind.priority], QuickPriority.high);
      expect(byKind[TokenKind.tag], 't');
    });
  });

  runRows('en recurrence grammar', mon, [
    PC(
      'water plants every day',
      title: 'water plants',
      rec: daily(),
      due: '2026-10-14',
      impliedDue: true,
      spans: [(TokenKind.recurrence, 13, 22)],
    ),
    PC(
      'daily standup',
      title: 'standup',
      rec: daily(),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'every other day clean',
      title: 'clean',
      rec: daily(2),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'every 3 days clean',
      title: 'clean',
      rec: daily(3),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'standup every weekday',
      title: 'standup',
      rec: weekly({1, 2, 3, 4, 5}),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'gym every monday',
      title: 'gym',
      rec: weekly({1}),
      due: '2026-10-19',
      impliedDue: true,
    ),
    PC(
      'gym every friday',
      title: 'gym',
      rec: weekly({5}),
      due: '2026-10-16',
      impliedDue: true,
    ),
    PC(
      'gym every wednesday',
      title: 'gym',
      rec: weekly({3}),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'gym every mon and wed',
      title: 'gym',
      rec: weekly({1, 3}),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'gym every tuesday, thursday and saturday',
      title: 'gym',
      rec: weekly({2, 4, 6}),
      due: '2026-10-15',
      impliedDue: true,
    ),
    PC(
      'gym every Monday at 9am',
      title: 'gym',
      rec: weekly({1}),
      due: '2026-10-19',
      time: '09:00',
      impliedDue: true,
    ),
    PC(
      'gym every monday starting tomorrow',
      title: 'gym starting',
      rec: weekly({1}),
      due: '2026-10-15',
    ),
    PC(
      'review every 2 weeks',
      title: 'review',
      rec: weekly({}, 2),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'review every other week',
      title: 'review',
      rec: weekly({}, 2),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'review every 2 weeks on monday',
      title: 'review',
      rec: weekly({1}, 2),
      due: '2026-10-19',
      impliedDue: true,
    ),
    PC(
      'review weekly',
      title: 'review',
      rec: weekly({}),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'review biweekly',
      title: 'review',
      rec: weekly({}, 2),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'pay rent monthly',
      title: 'pay rent',
      rec: monthly(),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'pay rent every month',
      title: 'pay rent',
      rec: monthly(),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'pay rent every month on the 15th',
      title: 'pay rent',
      rec: monthly(day: 15),
      due: '2026-10-15',
      impliedDue: true,
    ),
    PC(
      'pay rent every 15th',
      title: 'pay rent',
      rec: monthly(day: 15),
      due: '2026-10-15',
      impliedDue: true,
    ),
    PC(
      'pay rent on the 1st of every month',
      title: 'pay rent',
      rec: monthly(day: 1),
      due: '2026-11-01',
      impliedDue: true,
    ),
    PC(
      'pay rent every 3 months',
      title: 'pay rent',
      rec: monthly(interval: 3),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'close books last day of the month',
      title: 'close books',
      rec: lastDay(),
      due: '2026-10-31',
      impliedDue: true,
    ),
    PC(
      'close books last day of month',
      title: 'close books',
      rec: lastDay(),
      due: '2026-10-31',
      impliedDue: true,
    ),
    PC(
      'close books every month on the last day',
      title: 'close books',
      rec: lastDay(),
      due: '2026-10-31',
      impliedDue: true,
    ),
    PC(
      'sync every first monday',
      title: 'sync',
      rec: nthWeekday(1, 1),
      due: '2026-11-02',
      impliedDue: true,
    ),
    PC(
      'sync every last friday',
      title: 'sync',
      rec: nthWeekday(5, 5),
      due: '2026-10-30',
      impliedDue: true,
    ),
    PC(
      'sync every 2nd tuesday',
      title: 'sync',
      rec: nthWeekday(2, 2),
      due: '2026-11-10',
      impliedDue: true,
    ),
    PC(
      'sync every month on the third thursday',
      title: 'sync',
      rec: nthWeekday(3, 4),
      due: '2026-10-15',
      impliedDue: true,
    ),
    PC(
      'sync every day until 2026-12-31',
      title: 'sync',
      rec: daily().copyWith(endDate: d('2026-12-31')),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'sync every week ends dec 31',
      title: 'sync',
      rec: weekly({}).copyWith(endDate: d('2026-12-31')),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'sync every day until jan 5 2027',
      title: 'sync',
      rec: daily().copyWith(endDate: d('2027-01-05')),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'sync every day after completion',
      title: 'sync',
      rec: daily().copyWith(completionBased: true),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'sync every week repeat after done',
      title: 'sync',
      rec: weekly({}).copyWith(completionBased: true),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'sync every day until 2026-12-31 after completion',
      title: 'sync',
      rec: daily().copyWith(endDate: d('2026-12-31'), completionBased: true),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      'birthday every year',
      title: 'birthday every year',
      hint: 'recurrence.yearly_unsupported',
    ),
    PC(
      'yearly review',
      title: 'yearly review',
      hint: 'recurrence.yearly_unsupported',
    ),
    PC(
      'taxes annually tomorrow',
      title: 'taxes annually',
      due: '2026-10-15',
      hint: 'recurrence.yearly_unsupported',
    ),
    PC('only until 2026-12-31', title: 'only until', due: '2026-12-31'),
    PC('every monday', title: 'every monday'),
  ]);

  group('en recurrence extras', () {
    test('explicit date wins over implied date', () {
      final r = mon().parse('gym every monday starting tomorrow');
      expect(r.dueDateImpliedByRecurrence, isFalse);
      expect(r.dueDate?.toIso(), '2026-10-15');
    });
    test('recurrence tokens share the final rule', () {
      final r = mon().parse('sync every day until 2026-12-31');
      expect(r.tokens.length, 2);
      expect(r.tokens.every((t) => t.value == r.recurrence), isTrue);
      expect(r.tokens.first.text, 'every day');
      expect(r.tokens.last.text, 'until 2026-12-31');
    });
    test('ended recurrence does not imply a due date', () {
      final r = mon().parse('sync every day until 2026-01-01');
      expect(r.dueDate, isNull);
      expect(r.recurrence, isNotNull);
    });
  });
}

CalendarDate d(String s) => CalendarDate.parse(s);
