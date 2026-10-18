import '../../../core/time/calendar_date.dart';
import '../recurrence/recurrence_rule.dart';
import 'grammar.dart';

const _wdFull =
    r'(?:montag|dienstag|mittwoch|donnerstag|freitag|samstag|sonnabend|sonntag)';
const _wdAbbr = r'(?:mo|di|mi|do|fr|sa|so)\.?';
const _wdAdv =
    r'(?:montags|dienstags|mittwochs|donnerstags|freitags|samstags|sonntags)';
const _mon =
    r'(?:januar|jänner|februar|märz|maerz|april|mai|juni|juli|august|'
    r'september|oktober|november|dezember|jan|feb|mär|mrz|apr|jun|jul|aug|'
    r'sept|sep|okt|nov|dez)';
const _numW =
    r'(?:\d+|ein|einen|eine|einem|einer|zwei|drei|vier|fünf|sechs|sieben|'
    r'acht|neun|zehn|zwölf)';
const _ordW = r'(?:zweiten?|dritten?|vierten?|fünften?|sechsten?)';
const _next = r'n(?:ä|ae)chste[nmrs]?';

const _nums = {
  'ein': 1,
  'einen': 1,
  'eine': 1,
  'einem': 1,
  'einer': 1,
  'zwei': 2,
  'drei': 3,
  'vier': 4,
  'fünf': 5,
  'sechs': 6,
  'sieben': 7,
  'acht': 8,
  'neun': 9,
  'zehn': 10,
  'zwölf': 12,
  'zweite': 2,
  'zweiten': 2,
  'dritte': 3,
  'dritten': 3,
  'vierte': 4,
  'vierten': 4,
  'fünfte': 5,
  'fünften': 5,
  'sechste': 6,
  'sechsten': 6,
};

const _ordinals = {
  'ersten': 1,
  'zweiten': 2,
  'dritten': 3,
  'vierten': 4,
  'fünften': 5,
  'letzten': 5,
};

int? _num(String? s) => s == null ? null : (safeInt(s) ?? _nums[s]);

int? _wdIndex(String? raw) {
  if (raw == null) return null;
  final s = raw.replaceAll('.', '');
  if (s.startsWith('sonnab')) return 6;
  if (s.length < 2) return null;
  return const {'mo': 1, 'di': 2, 'mi': 3, 'do': 4, 'fr': 5, 'sa': 6, 'so': 7}[s
      .substring(0, 2)];
}

int? _monIndex(String? s) {
  if (s == null || s.length < 3) return null;
  return const {
    'jan': 1,
    'jän': 1,
    'feb': 2,
    'mär': 3,
    'mae': 3,
    'mrz': 3,
    'apr': 4,
    'mai': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'okt': 10,
    'nov': 11,
    'dez': 12,
  }[s.substring(0, 3)];
}

Set<int> _weekdaySet(String text) {
  final out = <int>{};
  for (final m in rx('$lb($_wdFull|$_wdAdv|$_wdAbbr)$la').allMatches(text)) {
    final i = _wdIndex(m[1]);
    if (i != null) out.add(i);
  }
  return out;
}

final _words = rx(
  '$lb'
  r'(heute\s+abend|heute|morgen|übermorgen|ubermorgen|gestern|vorgestern)'
  '$la',
);
final _weekday = rx(
  '$lb'
  r'(?:(am|'
  '$_next'
  r'|kommende[nmrs]?|diese[nmrs]?)\s+)?'
  '($_wdFull|$_wdAbbr)$la',
);
final _nextWeekMonth = rx(
  '$lb'
  r'(?:'
  '$_next'
  r')\s+(woche|monat)'
  '$la',
);
final _weekend = rx(
  '$lb'
  r'(?:(?:am|an)\s+)?(?:(diese[nmrs]?|'
  '$_next'
  r')\s+)?wochenende'
  '$la',
);
final _inN = rx(
  '$lb'
  r'in\s+('
  '$_numW'
  r')\s+(tag|tagen|woche|wochen|monat|monaten|monate)'
  '$la',
);
final _numeric = rx(
  '(?:$lb'
  r'am\s+)?(?<![\p{N}.:])(\d{1,2})\.(\d{1,2})\.(\d{4})?(?!\p{N})',
);
final _textual = rx(
  '(?:$lb'
  r'am\s+)?(?<![\p{N}.:])(\d{1,2})\.?\s*'
  '($_mon)'
  r'\.?'
  '$la'
  r'(?:\s+(\d{4})(?!\p{N}))?',
);

final _clock = rx(
  r'(?:(?<![\p{L}\p{N}_])um\s+)?(?<![\p{L}\p{N}:.])'
  r'(\d{1,2})(?:[:.](\d{2}))?\s*uhr'
  '$la',
);
final _clockColon = rx(
  r'(?:(?<![\p{L}\p{N}_])um\s+)?(?<![\p{L}\p{N}:.])'
  r'(\d{1,2}):(\d{2})(?![\p{N}]|:\d)(?!\s*uhr)',
);
final _weakTime = rx(
  '(?:$lb'
  r'am\s+)?'
  '$lb'
  r'(morgens|vormittags?|mittags?|nachmittags?|abends?)'
  '$la',
);

final _endMarker = rx(
  '$lb'
  r'(?:bis(?:\s+zum)?|endet(?:\s+am)?)\s+$',
);

class GermanGrammar implements Grammar {
  const GermanGrammar();

  @override
  List<DateMatch> dates(String t, GrammarContext c) {
    final out = <DateMatch>[];
    void add(Match m, CalendarDate? d, [LocalTime? time]) {
      if (d != null) out.add(DateMatch(m.start, m.end, d, time));
    }

    for (final m in _words.allMatches(t)) {
      final w = m[1]!;
      if (w.startsWith('heute') && w.length > 5) {
        add(m, c.today, const LocalTime(19, 0));
      } else {
        add(m, switch (w) {
          'heute' => c.today,
          'morgen' => c.today.addDays(1),
          'übermorgen' || 'ubermorgen' => c.today.addDays(2),
          'gestern' => c.today.addDays(-1),
          _ => c.today.addDays(-2),
        });
      }
    }
    for (final m in _weekday.allMatches(t)) {
      final word = m[2]!;
      final mod = m[1];
      final abbr = word.replaceAll('.', '').length <= 2;
      if (abbr && mod == null && !word.endsWith('.')) continue;
      final wd = _wdIndex(word);
      if (wd == null) continue;
      if (mod == null || mod == 'am') {
        add(m, c.upcomingWeekday(wd));
      } else if (mod.startsWith('kommend')) {
        add(m, c.upcomingWeekday(wd));
      } else if (mod.startsWith('diese')) {
        add(m, c.thisWeekWeekday(wd));
      } else {
        add(m, c.nextWeekWeekday(wd));
      }
    }
    for (final m in _nextWeekMonth.allMatches(t)) {
      add(m, m[1] == 'woche' ? c.nextWeekStart : c.addMonths(c.today, 1));
    }
    for (final m in _weekend.allMatches(t)) {
      final mod = m[1];
      add(
        m,
        mod != null && mod.startsWith('n')
            ? c.nextWeekWeekday(6)
            : c.upcomingWeekend,
      );
    }
    for (final m in _inN.allMatches(t)) {
      final n = _num(m[1]);
      if (n == null || n > 5000) continue;
      final unit = m[2]!;
      if (unit.startsWith('tag')) {
        add(m, c.today.addDays(n));
      } else if (unit.startsWith('woche')) {
        add(m, c.today.addDays(7 * n));
      } else {
        add(m, c.addMonths(c.today, n));
      }
    }
    for (final m in _numeric.allMatches(t)) {
      final d = safeInt(m[1]), mo = safeInt(m[2]);
      if (d == null || mo == null) continue;
      add(m, c.monthDay(mo, d, safeInt(m[3])));
    }
    for (final m in _textual.allMatches(t)) {
      final d = safeInt(m[1]);
      final mo = _monIndex(m[2]);
      if (d == null || mo == null) continue;
      add(m, c.monthDay(mo, d, safeInt(m[3])));
    }
    return out;
  }

  @override
  List<TimeMatch> times(String t, GrammarContext c) {
    final out = <TimeMatch>[];
    for (final m in _clock.allMatches(t)) {
      final time = mkTime(safeInt(m[1]) ?? -1, safeInt(m[2] ?? '0') ?? -1);
      if (time != null) out.add(TimeMatch(m.start, m.end, time));
    }
    for (final m in _clockColon.allMatches(t)) {
      final time = mkTime(safeInt(m[1]) ?? -1, safeInt(m[2]) ?? -1);
      if (time != null) out.add(TimeMatch(m.start, m.end, time));
    }
    for (final m in _weakTime.allMatches(t)) {
      final w = m[1]!;
      final h = w.startsWith('morgens')
          ? 9
          : w.startsWith('vormittag')
          ? 10
          : w.startsWith('mittag')
          ? 12
          : w.startsWith('nachmittag')
          ? 15
          : 18;
      out.add(TimeMatch(m.start, m.end, LocalTime(h, 0), needsAnchor: true));
    }
    return out;
  }

  @override
  int? endMarkerStart(String t, int dateStart) =>
      markerBefore(_endMarker, t, dateStart);

  // ---------------------------------------------------------------- recurrence

  static final _list =
      '(?:$_wdFull|$_wdAdv|$_wdAbbr)'
      r'(?:\s*(?:,|und|&|/)\s*'
      '(?:$_wdFull|$_wdAdv|$_wdAbbr))*';

  static final _everyDay = rx(
    '$lb'
    r'(?:jeden\s+(?:('
    '$_ordW'
    r')\s+)?tag|alle\s+(?:('
    '$_numW'
    r')\s+)?tage)'
    '$la',
  );
  static final _daily = rx('$lb(?:täglich|taeglich)$la');
  static final _weekdays = rx(
    '$lb'
    r'(?:werktags|wochentags|(?:jeden|an)\s+werktag(?:en)?)'
    '$la',
  );
  static final _weekly = rx(
    '$lb'
    r'(?:(wöchentlich|woechentlich|zweiwöchentlich|14-tägig)|'
    r'(?:jede|alle)\s+(?:('
    '$_numW|$_ordW'
    r')\s+)?woch(?:e|en)(?:\s+am\s+('
    '$_list'
    r'))?)'
    '$la',
  );
  static final _everyWd = rx(
    '$lb'
    r'(?:jeden|jede)\s+('
    '$_list'
    r')'
    '$la',
  );
  static final _adverbWd = rx(
    '$lb'
    r'((?:montags|dienstags|mittwochs|donnerstags|freitags|samstags|sonntags)'
    r'(?:\s*(?:,|und|&)\s*(?:montags|dienstags|mittwochs|donnerstags|freitags|samstags|sonntags))*)'
    '$la',
  );
  static final _monthly = rx(
    '$lb'
    r'(?:monatlich|(?:jeden|jeder|alle)\s+(?:('
    '$_numW|$_ordW'
    r')\s+)?monate?n?(?:\s+am\s+(\d{1,2})\.)?)'
    '$la',
  );
  static final _everyNth = rx(
    '$lb'
    r'jeden\s+(\d{1,2})\.(?!\s*'
    '$_mon'
    r')',
  );
  static final _lastDay = rx(
    '$lb'
    r'(?:(?:jeden\s+monat\s+)?(?:am\s+)?(?:monatsletzten|monatsende)'
    r'|(?:am\s+|jeden\s+)?letzten\s+tag\s+(?:des|im|jedes)\s+monats?)'
    '$la',
  );
  static final _ordinalWd = rx(
    '$lb'
    r'jeden\s+(ersten|zweiten|dritten|vierten|fünften|letzten)\s+('
    '$_wdFull|$_wdAbbr'
    r')'
    '$la',
  );
  static final _yearly = rx(
    '$lb'
    r'(?:jährlich|jaehrlich|(?:jedes|alle)\s+(?:('
    '$_numW'
    r')\s+)?jahre?)'
    '$la',
  );
  static final _completion = rx(
    '$lb'
    r'nach\s+(?:dem\s+)?(?:erledigung|abschluss|fertigstellung|erledigen|erledigt)'
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
        RecurrenceRule(
          type: RecurrenceType.daily,
          interval: _num(m[1] ?? m[2]) ?? 1,
        ),
      );
    }
    for (final m in _daily.allMatches(t)) {
      base(m, RecurrenceRule(type: RecurrenceType.daily));
    }
    for (final m in _weekdays.allMatches(t)) {
      base(m, weeklyRule({1, 2, 3, 4, 5}, 1));
    }
    for (final m in _weekly.allMatches(t)) {
      final days = m[3] == null ? <int>{} : _weekdaySet(m[3]!);
      final interval = m[1] != null
          ? (m[1]!.startsWith('zwei') || m[1]!.startsWith('14') ? 2 : 1)
          : (_num(m[2]) ?? 1);
      base(m, weeklyRule(days, interval));
    }
    for (final m in _everyWd.allMatches(t)) {
      final days = _weekdaySet(m[1]!);
      if (days.isNotEmpty) base(m, weeklyRule(days, 1));
    }
    for (final m in _adverbWd.allMatches(t)) {
      final days = _weekdaySet(m[1]!);
      if (days.isNotEmpty) base(m, weeklyRule(days, 1));
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
    for (final m in _everyNth.allMatches(t)) {
      final day = safeInt(m[1]);
      if (day == null || day < 1 || day > 31) continue;
      base(m, RecurrenceRule(type: RecurrenceType.monthly, monthDay: day));
    }
    for (final m in _lastDay.allMatches(t)) {
      base(m, RecurrenceRule(type: RecurrenceType.monthlyLastDay));
    }
    for (final m in _ordinalWd.allMatches(t)) {
      final ord = _ordinals[m[1]];
      final wd = _wdIndex(m[2]);
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
