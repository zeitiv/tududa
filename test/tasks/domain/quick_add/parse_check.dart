import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/time/calendar_date.dart';
import 'package:tududa/tasks/domain/quick_add/quick_add_parser.dart';
import 'package:tududa/tasks/domain/recurrence/recurrence_rule.dart';

/// 2026-10-14 is a Wednesday.
final CalendarDate today = CalendarDate.parse('2026-10-14');

/// One table row. Every field not given is expected to be empty/null.
class PC {
  PC(
    this.input, {
    required this.title,
    this.due,
    this.time,
    this.priority,
    this.project,
    this.area,
    this.tags = const [],
    this.rec,
    this.hint,
    this.disabled,
    this.disabledStarts,
    this.spans,
    this.impliedDue = false,
  });

  final String input;
  final String title;
  final String? due;
  final String? time;
  final QuickPriority? priority;
  final String? project;
  final String? area;
  final List<String> tags;
  final RecurrenceRule? rec;
  final String? hint;
  final Set<TokenKind>? disabled;
  final Set<int>? disabledStarts;

  /// Expected token (kind, start, end) triples, in order.
  final List<(TokenKind, int, int)>? spans;
  final bool impliedDue;
}

void checkRow(QuickAddParser parser, PC c) {
  final r = parser.parse(
    c.input,
    disabled: c.disabled,
    disabledTokenStarts: c.disabledStarts,
  );
  expect(r.title, c.title, reason: 'title of "${c.input}"');
  expect(r.dueDate?.toIso(), c.due, reason: 'due of "${c.input}"');
  expect(r.dueTime?.format(), c.time, reason: 'time of "${c.input}"');
  expect(r.priority, c.priority, reason: 'priority of "${c.input}"');
  expect(r.projectName, c.project, reason: 'project of "${c.input}"');
  expect(r.areaName, c.area, reason: 'area of "${c.input}"');
  expect(r.tags, c.tags, reason: 'tags of "${c.input}"');
  expect(r.recurrence, c.rec, reason: 'recurrence of "${c.input}"');
  expect(r.hint, c.hint, reason: 'hint of "${c.input}"');
  expect(
    r.dueDateImpliedByRecurrence,
    c.impliedDue,
    reason: 'impliedDue of "${c.input}"',
  );
  if (c.spans != null) {
    expect(
      [for (final t in r.tokens) (t.kind, t.start, t.end)],
      c.spans,
      reason: 'token spans of "${c.input}"',
    );
  }
  checkTokenInvariants(c.input, r);
}

void checkTokenInvariants(String input, ParseResult r) {
  var lastEnd = 0;
  for (final t in r.tokens) {
    expect(
      t.start >= 0 && t.end <= input.length && t.start < t.end,
      isTrue,
      reason: 'range of $t in "$input"',
    );
    expect(input.substring(t.start, t.end), t.text);
    expect(t.start >= lastEnd, isTrue, reason: 'overlap at $t in "$input"');
    lastEnd = t.end;
  }
  expect(r.title, r.title.trim());
  expect(r.title.contains(RegExp(r'\s{2,}')), isFalse);
}

void runRows(String name, QuickAddParser Function() make, List<PC> rows) {
  group(name, () {
    for (final row in rows) {
      test(row.input, () => checkRow(make(), row));
    }
  });
}

RecurrenceRule daily([int interval = 1]) =>
    RecurrenceRule(type: RecurrenceType.daily, interval: interval);

RecurrenceRule weekly(Set<int> days, [int interval = 1]) => RecurrenceRule(
  type: RecurrenceType.weekly,
  weekdays: days,
  interval: interval,
);

RecurrenceRule monthly({int? day, int interval = 1}) => RecurrenceRule(
  type: RecurrenceType.monthly,
  monthDay: day,
  interval: interval,
);

RecurrenceRule nthWeekday(int week, int weekday) => RecurrenceRule(
  type: RecurrenceType.monthlyWeekday,
  weekOfMonth: week,
  weekday: weekday,
);

RecurrenceRule lastDay() => RecurrenceRule(type: RecurrenceType.monthlyLastDay);
