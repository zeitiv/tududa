import '../../../core/time/calendar_date.dart';
import '../recurrence/recurrence_rule.dart';
import 'grammar.dart';

const _zn = '零〇一二两三四五六七八九十';
const _n = r'(?:\d{1,3}|[' + _zn + r']{1,3})';
const _wdc = '一二三四五六日天';
const _wdAlt = '(?:周|星期|礼拜)';
const _per = '(凌晨|清晨|早上|早晨|上午|中午|下午|傍晚|晚上|晚间|夜里|夜间|早|晚)?';

const _digits = {
  '零': 0,
  '〇': 0,
  '一': 1,
  '二': 2,
  '两': 2,
  '三': 3,
  '四': 4,
  '五': 5,
  '六': 6,
  '七': 7,
  '八': 8,
  '九': 9,
};

/// Parses ASCII digits or Chinese numerals up to 99 (一..九十九, 两, 十五).
int? zhNum(String? s) {
  if (s == null || s.isEmpty) return null;
  final asInt = int.tryParse(s);
  if (asInt != null) return asInt;
  final i = s.indexOf('十');
  if (i < 0) return s.length == 1 ? _digits[s] : null;
  if (s.indexOf('十', i + 1) >= 0) return null;
  final before = s.substring(0, i), after = s.substring(i + 1);
  if (before.length > 1 || after.length > 1) return null;
  final tens = before.isEmpty ? 1 : _digits[before];
  final ones = after.isEmpty ? 0 : _digits[after];
  if (tens == null || ones == null) return null;
  return tens * 10 + ones;
}

int? _wdIndex(String? ch) {
  if (ch == null || ch.isEmpty) return null;
  if (ch == '日' || ch == '天') return 7;
  final v = _digits[ch];
  return v != null && v >= 1 && v <= 6 ? v : null;
}

Set<int> _weekdaySet(String chars) {
  final out = <int>{};
  for (final r in chars.split('')) {
    final i = _wdIndex(r);
    if (i != null) out.add(i);
  }
  return out;
}

int? _hour(String? per, int h) {
  if (h > 24) return null;
  int out;
  switch (per) {
    case '下午' || '傍晚':
      out = h < 12 ? h + 12 : h;
    case '晚上' || '晚间' || '晚' || '夜里' || '夜间':
      out = h == 12 ? 0 : (h < 12 ? h + 12 : h);
    case '中午':
      out = (h == 1 || h == 2) ? h + 12 : h;
    case '凌晨':
      out = h == 12 ? 0 : h;
    default:
      out = h;
  }
  if (out == 24) out = 0;
  return out;
}

final _words = rx('(大后天|大後天|后天|後天|今天|今日|明天|明日|昨天|昨日|前天|今晚|明晚|今早|明早)');
final _weekday = rx('(?:(下|这|本|上)(?:个)?)?$_wdAlt([$_wdc])(?!次)');
final _nextWeek = rx('下(?:个)?$_wdAlt(?![$_wdc末])');
final _weekend = rx('(?:(这|本|下)(?:个)?)?周末');
final _nextMonth = rx('下(?:个)?月(?:($_n)(?:号|日))?');
final _rel = rx('($_n)(?:(天|日)|(?:个)?(周|星期|礼拜)|个(月))(?:以)?后');
final _dateMonthDay = rx('(?:(\\d{4})年)?($_n)月($_n)(?:日|号)');
final _dayOnly = rx('(?<![\\p{N}月周期拜$_zn])($_n)(?:日|号)');

final _hourRe = rx(
  '$_per(?<![\\p{N}])($_n)点'
  '(?:(半)|(\\d{1,2})分?(?![\\p{N}号日])|([$_zn]{1,3})分|(整)|(一刻))?',
);
final _colonRe = rx(
  '$_per(?<![\\p{N}:：.])(\\d{1,2})[:：](\\d{2})(?![\\p{N}]|[:：]\\d)',
);
final _weakRe = rx('(凌晨|清晨|早上|早晨|上午|中午|下午|傍晚|晚上|晚间)');

final _endMarker = rx(r'(?:直到|截止到|截止|截至|结束于)\s*$');

class ChineseGrammar implements Grammar {
  const ChineseGrammar();

  @override
  List<DateMatch> dates(String t, GrammarContext c) {
    final out = <DateMatch>[];
    void add(Match m, CalendarDate? d, [LocalTime? time]) {
      if (d != null) out.add(DateMatch(m.start, m.end, d, time));
    }

    for (final m in _words.allMatches(t)) {
      switch (m[1]) {
        case '今天' || '今日':
          add(m, c.today);
        case '今晚':
          add(m, c.today, const LocalTime(19, 0));
        case '今早':
          add(m, c.today, const LocalTime(9, 0));
        case '明天' || '明日':
          add(m, c.today.addDays(1));
        case '明晚':
          add(m, c.today.addDays(1), const LocalTime(19, 0));
        case '明早':
          add(m, c.today.addDays(1), const LocalTime(9, 0));
        case '后天' || '後天':
          add(m, c.today.addDays(2));
        case '大后天' || '大後天':
          add(m, c.today.addDays(3));
        case '昨天' || '昨日':
          add(m, c.today.addDays(-1));
        default:
          add(m, c.today.addDays(-2));
      }
    }
    for (final m in _weekday.allMatches(t)) {
      final wd = _wdIndex(m[2]);
      if (wd == null) continue;
      add(m, switch (m[1]) {
        '下' => c.nextWeekWeekday(wd),
        '这' || '本' => c.thisWeekWeekday(wd),
        '上' => c.lastWeekWeekday(wd),
        _ => c.upcomingWeekday(wd),
      });
    }
    for (final m in _nextWeek.allMatches(t)) {
      add(m, c.nextWeekStart);
    }
    for (final m in _weekend.allMatches(t)) {
      add(m, m[1] == '下' ? c.nextWeekWeekday(6) : c.upcomingWeekend);
    }
    for (final m in _nextMonth.allMatches(t)) {
      final day = zhNum(m[1]);
      if (m[1] == null) {
        add(m, c.addMonths(c.today, 1));
      } else if (day != null) {
        final nm = c.addMonths(CalendarDate(c.today.year, c.today.month, 1), 1);
        add(m, GrammarContext.validDate(nm.year, nm.month, day));
      }
    }
    for (final m in _rel.allMatches(t)) {
      final n = zhNum(m[1]);
      if (n == null || n > 5000) continue;
      if (m[2] != null) {
        add(m, c.today.addDays(n));
      } else if (m[3] != null) {
        add(m, c.today.addDays(7 * n));
      } else {
        add(m, c.addMonths(c.today, n));
      }
    }
    for (final m in _dateMonthDay.allMatches(t)) {
      final mo = zhNum(m[2]), day = zhNum(m[3]);
      if (mo == null || day == null) continue;
      add(m, c.monthDay(mo, day, safeInt(m[1])));
    }
    for (final m in _dayOnly.allMatches(t)) {
      final day = zhNum(m[1]);
      if (day == null || day < 1 || day > 31) continue;
      add(m, c.nextDayOfMonth(day));
    }
    return out;
  }

  @override
  List<TimeMatch> times(String t, GrammarContext c) {
    final out = <TimeMatch>[];
    for (final m in _hourRe.allMatches(t)) {
      final h = zhNum(m[2]);
      if (h == null) continue;
      var minute = 0;
      if (m[3] != null) {
        minute = 30;
      } else if (m[4] != null) {
        minute = safeInt(m[4]) ?? 99;
      } else if (m[5] != null) {
        minute = zhNum(m[5]) ?? 99;
      } else if (m[7] != null) {
        minute = 15;
      }
      final hour = _hour(m[1], h);
      if (hour == null) continue;
      final time = mkTime(hour, minute);
      if (time != null) out.add(TimeMatch(m.start, m.end, time));
    }
    for (final m in _colonRe.allMatches(t)) {
      final h = safeInt(m[2]), min = safeInt(m[3]);
      if (h == null || min == null) continue;
      final hour = _hour(m[1], h);
      if (hour == null) continue;
      final time = mkTime(hour, min);
      if (time != null) out.add(TimeMatch(m.start, m.end, time));
    }
    for (final m in _weakRe.allMatches(t)) {
      final h = switch (m[1]) {
        '凌晨' => 3,
        '清晨' || '早上' || '早晨' => 9,
        '上午' => 10,
        '中午' => 12,
        '下午' => 14,
        '傍晚' => 18,
        _ => 19,
      };
      out.add(TimeMatch(m.start, m.end, LocalTime(h, 0), needsAnchor: true));
    }
    return out;
  }

  @override
  int? endMarkerStart(String t, int dateStart) =>
      markerBefore(_endMarker, t, dateStart);

  // ---------------------------------------------------------------- recurrence

  static final _daily = rx('每($_n)?(?:个)?(?:天|日)|天天');
  static final _everyOtherDay = rx('每隔($_n)?(?:个)?(?:天|日)');
  static final _workdays = rx('(?:每(?:个)?)?工作日');
  static final _weekWd = rx(
    '每(?:个)?$_wdAlt([$_wdc](?:[和与及、,，]?[$_wdc])*)(?!次)',
  );
  static final _everyWeekend = rx('每(?:个)?周末');
  static final _week = rx('每($_n)?(?:个)?$_wdAlt(?![$_wdc末])');
  static final _everyOtherWeek = rx('每隔($_n)?(?:个)?$_wdAlt');
  static final _month = rx('每($_n)?(?:个)?月');
  static final _everyOtherMonth = rx('每隔($_n)?(?:个)?月');
  static final _monthDay = rx('每(?:个)?月(?:的)?($_n)(?:号|日)');
  static final _lastDay = rx('每(?:个)?月(?:的)?(?:最后一天|最后一日|月底|底)');
  static final _ordWd = rx('每(?:个)?月(?:的)?第($_n)个$_wdAlt([$_wdc])');
  static final _lastWd = rx('每(?:个)?月(?:的)?最后一个$_wdAlt([$_wdc])');
  static final _yearly = rx('每年|每($_n)年|年年');
  static final _completion = rx('完成后(?:再)?(?:重复|开始)|按完成时间(?:重复)?');

  @override
  List<RecurrenceMatch> recurrences(String t, GrammarContext c) {
    final out = <RecurrenceMatch>[];
    void base(Match m, RecurrenceRule? r) {
      if (r != null) {
        out.add(RecurrenceMatch(m.start, m.end, RecurrenceRole.base, r));
      }
    }

    int? iv(String? s) => s == null ? 1 : zhNum(s);
    int? skip(String? s) {
      final n = s == null ? 1 : zhNum(s);
      return n == null ? null : n + 1;
    }

    for (final m in _daily.allMatches(t)) {
      final n = iv(m[1]);
      if (n == null || n < 1) continue;
      base(m, RecurrenceRule(type: RecurrenceType.daily, interval: n));
    }
    for (final m in _everyOtherDay.allMatches(t)) {
      final n = skip(m[1]);
      if (n == null) continue;
      base(m, RecurrenceRule(type: RecurrenceType.daily, interval: n));
    }
    for (final m in _workdays.allMatches(t)) {
      base(m, weeklyRule({1, 2, 3, 4, 5}, 1));
    }
    for (final m in _weekWd.allMatches(t)) {
      final days = _weekdaySet(m[1]!);
      if (days.isNotEmpty) base(m, weeklyRule(days, 1));
    }
    for (final m in _everyWeekend.allMatches(t)) {
      base(m, weeklyRule({6, 7}, 1));
    }
    for (final m in _week.allMatches(t)) {
      final n = iv(m[1]);
      if (n == null || n < 1) continue;
      base(m, weeklyRule({}, n));
    }
    for (final m in _everyOtherWeek.allMatches(t)) {
      final n = skip(m[1]);
      if (n != null) base(m, weeklyRule({}, n));
    }
    for (final m in _month.allMatches(t)) {
      final n = iv(m[1]);
      if (n == null || n < 1) continue;
      base(m, RecurrenceRule(type: RecurrenceType.monthly, interval: n));
    }
    for (final m in _everyOtherMonth.allMatches(t)) {
      final n = skip(m[1]);
      if (n != null) {
        base(m, RecurrenceRule(type: RecurrenceType.monthly, interval: n));
      }
    }
    for (final m in _monthDay.allMatches(t)) {
      final day = zhNum(m[1]);
      if (day == null || day < 1 || day > 31) continue;
      base(m, RecurrenceRule(type: RecurrenceType.monthly, monthDay: day));
    }
    for (final m in _lastDay.allMatches(t)) {
      base(m, RecurrenceRule(type: RecurrenceType.monthlyLastDay));
    }
    for (final m in _ordWd.allMatches(t)) {
      final ord = zhNum(m[1]);
      final wd = _wdIndex(m[2]);
      if (ord == null || ord < 1 || ord > 5 || wd == null) continue;
      base(
        m,
        RecurrenceRule(
          type: RecurrenceType.monthlyWeekday,
          weekOfMonth: ord,
          weekday: wd,
        ),
      );
    }
    for (final m in _lastWd.allMatches(t)) {
      final wd = _wdIndex(m[1]);
      if (wd == null) continue;
      base(
        m,
        RecurrenceRule(
          type: RecurrenceType.monthlyWeekday,
          weekOfMonth: 5,
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
