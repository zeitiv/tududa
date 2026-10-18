import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/tasks/domain/quick_add/quick_add_parser.dart';

import 'parse_check.dart';

void main() {
  final pieces = [
    'tomorrow',
    'today',
    'monday',
    'next',
    'every',
    'day',
    'week',
    'month',
    'at',
    '3pm',
    '15:00',
    '3:30',
    'noon',
    'jan',
    '5',
    '5th',
    'of',
    'in',
    'days',
    'until',
    '2026-12-31',
    '2026-02-30',
    '#tag',
    '+proj',
    '~area',
    '!',
    '!!',
    '!!!',
    '!high',
    '+"',
    '"',
    "'",
    '+',
    '~',
    '#',
    'last',
    'first',
    'friday',
    'heute',
    'morgen',
    'um',
    'Uhr',
    'jeden',
    'Montag',
    'bis',
    '5.1.',
    '31.12.',
    '今天',
    '明天',
    '下午',
    '3点',
    '半',
    '每',
    '周',
    '一',
    '三',
    '五',
    '月',
    '号',
    '日',
    '天',
    '后',
    '下个',
    '直到',
    '工作日',
    '　',
    ' ',
    ' ',
    ' ',
    '\n',
    ',',
    '.',
    ';',
    ':',
    '-',
    '/',
    '(',
    ')',
    '😀',
    'é',
    'ß',
    'İ',
    '\u0000',
    '\uD800',
    'x' * 50,
    '٣',
    '１２',
  ];

  test('fuzz: random strings never throw and keep invariants', () {
    final rnd = Random(20261014);
    for (final lang in ['en', 'de', 'zh']) {
      for (final ws in [1, 7]) {
        final parser = QuickAddParser(
          today: today,
          language: lang,
          weekStart: ws,
          knownProjects: ['Home', 'Home Office'],
          knownAreas: ['Work'],
          knownTags: ['x'],
        );
        for (var i = 0; i < 1500; i++) {
          final n = rnd.nextInt(14);
          final input = List.generate(
            n,
            (_) => pieces[rnd.nextInt(pieces.length)],
          ).join(rnd.nextBool() ? ' ' : '');
          final ParseResult r;
          try {
            r = parser.parse(input);
          } catch (e, st) {
            fail('threw on ${input.runes.toList()}: $e\n$st');
          }
          checkTokenInvariants(input, r);
          // Disabling every token start must also be safe.
          final off = parser.parse(
            input,
            disabledTokenStarts: {for (final t in r.tokens) t.start},
          );
          checkTokenInvariants(input, off);
        }
      }
    }
  });

  test('fuzz: random code units', () {
    final rnd = Random(7);
    final parser = QuickAddParser(today: today, language: 'zh');
    for (var i = 0; i < 1000; i++) {
      final input = String.fromCharCodes(
        List.generate(rnd.nextInt(40), (_) => rnd.nextInt(0x3000)),
      );
      checkTokenInvariants(input, parser.parse(input));
    }
  });

  test('disabling a token makes it plain text again', () {
    final parser = QuickAddParser(today: today);
    const input = 'call mom tomorrow at 3pm #x !! every monday';
    final r = parser.parse(input);
    for (final t in r.tokens) {
      final off = parser.parse(input, disabledTokenStarts: {t.start});
      expect(
        off.title.contains(t.text),
        isTrue,
        reason: 'disabling $t should keep its text',
      );
    }
  });
}
