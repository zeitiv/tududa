import '../../../core/time/calendar_date.dart';
import '../recurrence/recurrence_rule.dart';
import 'grammar.dart';

const _wd =
    r'(?:monday|mon|tuesday|tues|tue|wednesday|wed|thursday|thurs|thur|thu|'
    r'friday|fri|saturday|sat|sunday|sun)';
const _mon =
    r'(?:january|jan|february|feb|march|mar|april|apr|may|june|jun|july|jul|'
    r'august|aug|september|sept|sep|october|oct|november|nov|december|dec)';
const _pre = r'(?:(?:on|by|due)\s+)?';
const _words =
    r'(?:an?|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)';

const _wordNums = {
  'a': 1,
  'an': 1,
  'one': 1,
  'two': 2,
  'three': 3,
  'four': 4,
  'five': 5,
  'six': 6,
  'seven': 7,
  'eight': 8,
  'nine': 9,
  'ten': 10,
  'eleven': 11,
  'twelve': 12,
  'other': 2,
  'second': 2,
  'third': 3,
  'fourth': 4,
};

const _ordinals = {
  'first': 1,
  '1st': 1,
  'second': 2,
  '2nd': 2,
  'third': 3,
  '3rd': 3,
  'fourth': 4,
  '4th': 4,
  'fifth': 5,
  '5th': 5,
  'last': 5,
};

int? _wdIndex(String? s) {
  if (s == null || s.length < 3) return null;
  return const {
    'mon': 1,
    'tue': 2,
    'wed': 3,
    'thu': 4,
    'fri': 5,
    'sat': 6,
    'sun': 7,
  }[s.substring(0, 3)];
}

int? _monIndex(String? s) {
  if (s == null || s.length < 3) return null;
  return const {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  }[s.substring(0, 3)];
}

int? _num(String? s) {
  if (s == null) return null;
  return safeInt(s) ?? _wordNums[s];
}

Set<int> _weekdaySet(String text) {
  final out = <int>{};
  for (final m in rx(_wd).allMatches(text)) {
    final i = _wdIndex(m[0]);
    if (i != null) out.add(i);
  }
  return out;
}

final _simple = rx(
  '$lb'
  r'(today|tonight|tomorrow|tmrw|tmr|yesterday|yday)'
  '$la',
);
final _partOfDay = rx(
  '$lb'
  r'this\s+(morning|afternoon|evening)'
  '$la',
);
final _weekday = rx(
  '$lb$_pre'
  r'(?:(next|this)\s+)?'
  '($_wd)$la',
);
final _nextThis = rx(
  '$lb'
  r'(next|this)\s+(week|weekend|month)'
  '$la',
);
final _inN = rx(
  '$lb'
  r'in\s+(\d+|'
  '$_words'
  r')\s+(days?|weeks?|months?)'
  '$la',
);
final _monthDay = rx(
  '$lb$_pre'
  '($_mon)'
  r'\.?\s+(\d{1,2})(?:st|nd|rd|th)?(?![\p{L}\p{N}:])'
  r'(?!\s*(?:am|pm|a\.m|p\.m)(?![\p{L}]))'
  r'(?:,?\s+(\d{4})(?!\p{N}))?',
);
final _dayMonth = rx(
  '$lb$_pre'
  r'(\d{1,2})(?:st|nd|rd|th)?\s+(?:of\s+)?'
  '($_mon)'
  r'\.?'
  '$la'
  r'(?:,?\s+(\d{4})(?!\p{N}))?',
);

final _ampm = rx(
  r'(?:(?<![\p{L}\p{N}_])at\s+)?(?<![\p{L}\p{N}:.])'
  r'(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)(?![\p{L}\p{N}])',
);
final _h24 = rx(
  r'(?:(?<![\p{L}\p{N}_])at\s+)?(?<![\p{L}\p{N}:.])'
  r'([01]?\d|2[0-3]):([0-5]\d)(?![\p{N}]|:\d|\.\d)'
  r'(?!\s*(?:am|pm|a\.m|p\.m)(?![\p{L}]))',
);
final _timeWord = rx(
  r'((?<![\p{L}\p{N}_])at\s+|(?<![\p{L}\p{N}_])in\s+the\s+)?'
  '$lb'
  r'(noon|midnight|morning|afternoon|evening)'
  '$la',
);

final _endMarker = rx(
  '$lb'
  r'(?:until|till|through|ends?(?:\s+on)?)\s+$',
);

class EnglishGrammar implements Grammar {
  const EnglishGrammar();

  @override
  List<DateMatch> dates(String t, GrammarContext c) {
    final out = <DateMatch>[];
    void add(Match m, CalendarDate? d, [LocalTime? time]) {
      if (d != null) out.add(DateMatch(m.start, m.end, d, time));
    }

    for (final m in _simple.allMatches(t)) {
      switch (m[1]) {
        case 'today':
          add(m, c.today);
        case 'tonight':
          add(m, c.today, const LocalTime(19, 0));
        case 'tomorrow' || 'tmrw' || 'tmr':
          add(m, c.today.addDays(1));
        default:
          add(m, c.today.addDays(-1));
      }
    }
    for (final m in _partOfDay.allMatches(t)) {
      final h = switch (m[1]) {
        'morning' => 9,
        'afternoon' => 14,
        _ => 18,
      };
      add(m, c.today, LocalTime(h, 0));
    }
    for (final m in _weekday.allMatches(t)) {
      final wd = _wdIndex(m[2]);
      if (wd == null) continue;
      add(m, switch (m[1]) {
        'next' => c.nextWeekWeekday(wd),
        'this' => c.thisWeekWeekday(wd),
        _ => c.upcomingWeekday(wd),
      });
    }
    for (final m in _nextThis.allMatches(t)) {
      final next = m[1] == 'next';
      switch (m[2]) {
        case 'week':
          if (next) add(m, c.nextWeekStart);
        case 'weekend':
          add(m, next ? c.nextWeekWeekday(6) : c.upcomingWeekend);
        case 'month':
          if (next) add(m, c.addMonths(c.today, 1));
      }
    }
    for (final m in _inN.allMatches(t)) {
      final n = _num(m[1]);
      if (n == null || n > 5000) continue;
      final unit = m[2]!;
      if (unit.startsWith('day')) {
        add(m, c.today.addDays(n));
      } else if (unit.startsWith('week')) {
        add(m, c.today.addDays(7 * n));
      } else {
        add(m, c.addMonths(c.today, n));
      }
    }
    for (final m in _monthDay.allMatches(t)) {
      final mo = _monIndex(m[1]);
      final day = safeInt(m[2]);
      if (mo == null || day == null) continue;
      add(m, c.monthDay(mo, day, safeInt(m[3])));
    }
    for (final m in _dayMonth.allMatches(t)) {
      final mo = _monIndex(m[2]);
      final day = safeInt(m[1]);
      if (mo == null || day == null) continue;
      add(m, c.monthDay(mo, day, safeInt(m[3])));
    }
    for (final m in isoDate.allMatches(t)) {
      final y = safeInt(m[1]), mo = safeInt(m[2]), d = safeInt(m[3]);
      if (y == null || mo == null || d == null) continue;
      add(m, GrammarContext.validDate(y, mo, d));
    }
    return out;
  }

  @override
  List<TimeMatch> times(String t, GrammarContext c) {
    final out = <TimeMatch>[];
    for (final m in _ampm.allMatches(t)) {
      final h = safeInt(m[1]), min = safeInt(m[2] ?? '0');
      if (h == null || min == null || h < 1 || h > 12 || min > 59) continue;
      final pm = m[3]!.startsWith('p');
      final hour = h % 12 + (pm ? 12 : 0);
      final time = mkTime(hour, min);
      if (time != null) out.add(TimeMatch(m.start, m.end, time));
    }
    for (final m in _h24.allMatches(t)) {
      final time = mkTime(safeInt(m[1]) ?? -1, safeInt(m[2]) ?? -1);
      if (time != null) out.add(TimeMatch(m.start, m.end, time));
    }
    for (final m in _timeWord.allMatches(t)) {
      final time = switch (m[2]) {
        'noon' => const LocalTime(12, 0),
        'midnight' => const LocalTime(0, 0),
        'morning' => const LocalTime(9, 0),
        'afternoon' => const LocalTime(14, 0),
        _ => const LocalTime(18, 0),
      };
      final hasAt = m[1] != null && m[1]!.trim() == 'at';
      out.add(TimeMatch(m.start, m.end, time, needsAnchor: !hasAt));
    }
    return out;
  }

  @override
  int? endMarkerStart(String t, int dateStart) =>
      markerBefore(_endMarker, t, dateStart);

  // ---------------------------------------------------------------- recurrence

  static final _everyDay = rx(
    '$lb'
    r'(?:every|each)\s+(?:(\d+|other|second|third|fourth)\s+)?days?'
    '$la',
  );
  static final _daily = rx('${lb}daily$la');
  static final _weekdays = rx(
    '$lb'
    r'(?:(?:every|each)\s+(?:week\s?days?|work\s?days?|working\s+days?)|on\s+weekdays)'
    '$la',
  );
  static final _everyWeek = rx(
    '$lb'
    r'(?:every|each)\s+(?:(\d+|other|second|third|fourth)\s+)?weeks?'
    r'(?:\s+on\s+('
    '$_wd'
    r'(?:\s*(?:,|and|&|/)\s*'
    '$_wd'
    r')*))?'
    '$la',
  );
  static final _weekly = rx('$lb(weekly|biweekly|fortnightly)$la');
  static final _everyWd = rx(
    '$lb'
    r'(?:every|each)\s+(?:(\d+|other)\s+)?'
    r'('
    '$_wd'
    r's?(?:\s*(?:,|and|&|/)\s*'
    '$_wd'
    r's?)*)'
    '$la',
  );
  static final _monthly = rx(
    '$lb'
    r'(?:monthly|(?:every|each)\s+(?:(\d+|other|second|third|fourth)\s+)?months?'
    r'(?:\s+on\s+(?:the\s+)?(\d{1,2})(?:st|nd|rd|th)?)?)'
    '$la',
  );
  static final _everyNth = rx(
    '$lb'
    r'(?:every|each)\s+(\d{1,2})(?:st|nd|rd|th)'
    r'(?!\s*(?:week|day|month|year|mon|tue|wed|thu|fri|sat|sun))'
    '$la',
  );
  static final _theNthOfEvery = rx(
    '$lb'
    r'(?:on\s+)?the\s+(\d{1,2})(?:st|nd|rd|th)\s+of\s+(?:every|each)\s+month'
    '$la',
  );
  static final _lastDay = rx(
    '$lb'
    r'(?:(?:(?:every|each)\s+)?(?:month\s+)?(?:on\s+)?(?:the\s+)?last\s+day\s+of\s+(?:the\s+|every\s+|each\s+)?month'
    r'|(?:every|each)\s+month\s+(?:on\s+)?(?:the\s+)?last\s+day'
    r'|(?:every|each)\s+last\s+day)'
    '$la',
  );
  static final _ordinalWd = rx(
    '$lb'
    r'(?:(?:every|each)\s+(?:month\s+(?:on\s+)?(?:the\s+)?)?'
    r'(first|second|third|fourth|fifth|last|1st|2nd|3rd|4th|5th)\s+('
    '$_wd'
    r')'
    r'|(?:on\s+)?the\s+(first|second|third|fourth|fifth|last|1st|2nd|3rd|4th|5th)\s+('
    '$_wd'
    r')\s+of\s+(?:every|each|the)\s+month)'
    '$la',
  );
  static final _yearly = rx(
    '$lb'
    r'(?:yearly|annually|annual|(?:every|each)\s+(?:(?:\d+|other)\s+)?years?)'
    '$la',
  );
  static final _completion = rx(
    '$lb'
    r'(?:(?:repeat\s+)?(?:after|when)\s+(?:it(?:\x27s|\s+is)\s+)?'
    r'(?:completion|completed|complete|done|finished|completing)'
    r'|(?:repeat\s+)?on\s+completion)'
    '$la',
  );

  @override
  List<RecurrenceMatch> recurrences(String t, GrammarContext c) {
    final out = <RecurrenceMatch>[];
    void base(Match m, RecurrenceRule? r) {
      if (r != null) {
        out.add(RecurrenceMatch(m.start, m.end, RecurrenceRole.base, r));
      }
    }

    for (final m in _everyDay.allMatches(t)) {
      base(
        m,
        RecurrenceRule(type: RecurrenceType.daily, interval: _num(m[1]) ?? 1),
      );
    }
    for (final m in _daily.allMatches(t)) {
      base(m, RecurrenceRule(type: RecurrenceType.daily));
    }
    for (final m in _weekdays.allMatches(t)) {
      base(m, weeklyRule({1, 2, 3, 4, 5}, 1));
    }
    for (final m in _everyWeek.allMatches(t)) {
      final days = m[2] == null ? <int>{} : _weekdaySet(m[2]!);
      base(m, weeklyRule(days, _num(m[1]) ?? 1));
    }
    for (final m in _weekly.allMatches(t)) {
      base(m, weeklyRule({}, m[1] == 'weekly' ? 1 : 2));
    }
    for (final m in _everyWd.allMatches(t)) {
      final days = _weekdaySet(m[2]!);
      if (days.isEmpty) continue;
      base(m, weeklyRule(days, _num(m[1]) ?? 1));
    }
    for (final m in _monthly.allMatches(t)) {
      final day = safeInt(m[2]);
      if (m[2] != null && (day == null || day < 1 || day > 31)) continue;
      base(
        m,
        RecurrenceRule(
          type: RecurrenceType.monthly,
          interval: _num(m[1]) ?? 1,
          monthDay: day,
        ),
      );
    }
    for (final re in [_everyNth, _theNthOfEvery]) {
      for (final m in re.allMatches(t)) {
        final day = safeInt(m[1]);
        if (day == null || day < 1 || day > 31) continue;
        base(m, RecurrenceRule(type: RecurrenceType.monthly, monthDay: day));
      }
    }
    for (final m in _lastDay.allMatches(t)) {
      base(m, RecurrenceRule(type: RecurrenceType.monthlyLastDay));
    }
    for (final m in _ordinalWd.allMatches(t)) {
      final ord = _ordinals[m[1] ?? m[3]];
      final wd = _wdIndex(m[2] ?? m[4]);
      if (ord == null || wd == null) continue;
      base(
        m,
        RecurrenceRule(
          type: RecurrenceType.monthlyWeekday,
          weekOfMonth: ord,
          weekday: wd,
        ),
      );
    }
    for (final m in _yearly.allMatches(t)) {
      out.add(RecurrenceMatch(m.start, m.end, RecurrenceRole.yearly));
    }
    for (final m in _completion.allMatches(t)) {
      out.add(RecurrenceMatch(m.start, m.end, RecurrenceRole.completion));
    }
    return out;
  }
}
