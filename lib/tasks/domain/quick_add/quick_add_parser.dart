import '../../../core/time/calendar_date.dart';
import '../recurrence/next_occurrence.dart';
import '../recurrence/recurrence_rule.dart';
import 'grammar.dart';
import 'grammar_de.dart';
import 'grammar_en.dart';
import 'grammar_zh.dart';
import 'parse_result.dart';

export 'parse_result.dart';

const String _sentinel = '';
final RegExp _ws = RegExp(r'\s');
final RegExp _nameRun = RegExp(r'[\p{L}\p{N}_-]+', unicode: true);
final RegExp _wordChar = RegExp(r'[\p{L}\p{N}_]', unicode: true);
final RegExp _hasLetter = RegExp(r'\p{L}', unicode: true);
final RegExp _hasLetterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);
final RegExp _cjk = RegExp(r'[⺀-鿿豈-﫿＀-￯]');
final RegExp _gap = RegExp(r'^[\s,，]*$');
final RegExp _sepOnly = RegExp(r'^[\s,;:，；：、\-–—]*$');
final RegExp _tailOnly = RegExp(r'^[\s.。,;:，；：、\-–—]*$');
final RegExp _trailSep = RegExp(r'[\s,;:，；：、\-–—]+$');
final RegExp _leadSep = RegExp(r'^[\s,;:，；：、\-–—]+');
final RegExp _leadPunct = RegExp(r'^\s*[,;:，；：、]+');

const _quotePairs = {'"': '"', "'": "'", '“': '”', '‘': '’'};

String _collapse(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Natural-language quick-add parser. Pure Dart; deterministic relative to
/// [today] and [weekStart].
class QuickAddParser {
  QuickAddParser({
    required this.today,
    this.weekStart = 1,
    this.language = 'en',
    this.knownProjects = const [],
    this.knownAreas = const [],
    this.knownTags = const [],
  });

  final CalendarDate today;

  /// ISO weekday the week starts on: 1 = Monday ... 7 = Sunday.
  final int weekStart;

  /// 'en' | 'de' | 'zh'. English is always understood in addition.
  final String language;
  final List<String> knownProjects;
  final List<String> knownAreas;
  final List<String> knownTags;

  late final GrammarContext _ctx = GrammarContext(today, weekStart);
  late final List<Grammar> _grammars = () {
    final l = language.toLowerCase();
    if (l.startsWith('de')) {
      return <Grammar>[const GermanGrammar(), const EnglishGrammar()];
    }
    if (l.startsWith('zh')) {
      return <Grammar>[const ChineseGrammar(), const EnglishGrammar()];
    }
    return <Grammar>[const EnglishGrammar()];
  }();

  /// Parses [input]. Never throws.
  ///
  /// [disabled] turns whole token kinds off; [disabledTokenStarts] turns off
  /// the tokens that start at those offsets (a "dismissed chip"). Disabled
  /// phrases stay plain text and are not re-interpreted as smaller tokens.
  ParseResult parse(
    String input, {
    Set<TokenKind>? disabled,
    Set<int>? disabledTokenStarts,
  }) {
    try {
      return _Run(
        this,
        input,
        disabled ?? const {},
        disabledTokenStarts ?? const {},
      ).run();
    } catch (_) {
      return ParseResult(title: _collapse(input));
    }
  }
}

class _Run {
  _Run(this.p, this.input, this.disabled, this.disabledStarts)
    : n = input.length,
      folded = foldCase(input),
      blocked = List<bool>.filled(input.length, false),
      removed = List<bool>.filled(input.length, false);

  final QuickAddParser p;
  final String input;
  final Set<TokenKind> disabled;
  final Set<int> disabledStarts;
  final int n;
  final String folded;
  final List<bool> blocked;
  final List<bool> removed;
  final List<ParsedToken> tokens = [];

  String? project;
  String? area;
  QuickPriority? priority;
  final List<String> tags = [];
  CalendarDate? dueDate;
  LocalTime? dueTime;
  RecurrenceRule? rule;
  String? hint;
  bool impliedDue = false;

  GrammarContext get ctx => p._ctx;
  List<Grammar> get grammars => p._grammars;

  ParseResult run() {
    if (input.trim().isEmpty) return const ParseResult(title: '');
    _scanSyntax();
    _recurrence();
    _dateAndTime();
    _impliedDue();
    final title = _title();
    if (title.isEmpty) {
      return ParseResult(title: _collapse(input), hint: hint);
    }
    tokens.sort((a, b) => a.start.compareTo(b.start));
    return ParseResult(
      title: title,
      dueDate: dueDate,
      dueTime: dueTime,
      priority: priority,
      projectName: project,
      areaName: area,
      tags: List.unmodifiable(tags),
      recurrence: rule,
      tokens: List.unmodifiable(tokens),
      hint: hint,
      dueDateImpliedByRecurrence: impliedDue,
    );
  }

  // ------------------------------------------------------------ bookkeeping

  bool _off(TokenKind k, int start) =>
      disabled.contains(k) || disabledStarts.contains(start);

  bool _anyBlocked(int s, int e) {
    for (var i = s; i < e && i < n; i++) {
      if (blocked[i]) return true;
    }
    return false;
  }

  void _block(int s, int e) {
    for (var i = s; i < e && i < n; i++) {
      blocked[i] = true;
    }
  }

  void _commit(TokenKind kind, int s, int e, Object? value) {
    for (var i = s; i < e; i++) {
      blocked[i] = true;
      removed[i] = true;
    }
    tokens.add(
      ParsedToken(
        kind: kind,
        start: s,
        end: e,
        text: input.substring(s, e),
        value: value,
      ),
    );
  }

  bool _tryClaim(TokenKind kind, int s, int e, Object? value) {
    if (_anyBlocked(s, e)) return false;
    if (_off(kind, s)) {
      _block(s, e);
      return false;
    }
    _commit(kind, s, e, value);
    return true;
  }

  /// Picks the first (earliest, then longest) candidate that is neither
  /// blocked nor disabled; disabled winners are blocked and skipped.
  T? _pick<T>(
    TokenKind kind,
    Iterable<T> cands,
    int Function(T) s,
    int Function(T) e,
  ) {
    var list = cands.toList();
    while (true) {
      list = list.where((c) => !_anyBlocked(s(c), e(c))).toList();
      if (list.isEmpty) return null;
      list.sort((a, b) {
        final c = s(a).compareTo(s(b));
        return c != 0 ? c : (e(b) - s(b)).compareTo(e(a) - s(a));
      });
      var best = list.first;
      for (final c in list) {
        if (s(c) < e(best) &&
            e(c) > s(best) &&
            (e(c) - s(c)) > (e(best) - s(best))) {
          best = c;
        }
      }
      if (!_off(kind, s(best))) return best;
      _block(s(best), e(best));
    }
  }

  // ----------------------------------------------------------- syntax tokens

  bool _isWs(int i) => i >= 0 && i < n && _ws.hasMatch(input[i]);

  void _scanSyntax() {
    var i = 0;
    while (i < n) {
      final ch = input[i];
      if ((ch == '#' || ch == '+' || ch == '~' || ch == '!') &&
          (i == 0 || _isWs(i - 1))) {
        final end = switch (ch) {
          '#' => _tag(i),
          '+' => _named(i, TokenKind.project),
          '~' => _named(i, TokenKind.area),
          _ => _priority(i),
        };
        if (end > i) {
          i = end;
          continue;
        }
      }
      i++;
    }
  }

  int _trimName(int start, int end) {
    var e = end;
    while (e > start && input[e - 1] == '-') {
      e--;
    }
    return e;
  }

  int _tag(int i) {
    final m = _nameRun.matchAsPrefix(input, i + 1);
    if (m == null) return i;
    final e = _trimName(i + 1, m.end);
    if (e <= i + 1) return i;
    final name = input.substring(i + 1, e);
    if (!_hasLetterOrDigit.hasMatch(name)) return i;
    final lower = foldCase(name);
    var canonical = name;
    for (final k in p.knownTags) {
      if (foldCase(k) == lower) {
        canonical = k;
        break;
      }
    }
    if (_tryClaim(TokenKind.tag, i, e, canonical) &&
        !tags.any((t) => foldCase(t) == lower)) {
      tags.add(canonical);
    }
    return e;
  }

  int _named(int i, TokenKind kind) {
    final isProject = kind == TokenKind.project;
    if (isProject ? project != null : area != null) return i;
    final known = isProject ? p.knownProjects : p.knownAreas;

    String canonical(String s) {
      final f = foldCase(s);
      for (final k in known) {
        if (foldCase(k) == f) return k;
      }
      return s;
    }

    void assign(int e, String value) {
      if (_tryClaim(kind, i, e, value)) {
        if (isProject) {
          project = value;
        } else {
          area = value;
        }
      }
    }

    if (i + 1 >= n) return i;
    final open = input[i + 1];
    final close = _quotePairs[open];
    if (close != null) {
      final idx = input.indexOf(close, i + 2);
      if (idx > i + 2) {
        final inner = input.substring(i + 2, idx).trim();
        if (inner.isNotEmpty) {
          assign(idx + 1, canonical(inner));
          return idx + 1;
        }
      }
      return i;
    }

    // Longest known name, case-insensitive, ending at a word boundary.
    String? bestName;
    var bestEnd = i;
    for (final k in known) {
      final name = k.trim();
      final f = foldCase(name);
      if (f.isEmpty || (bestName != null && f.length <= bestEnd - i - 1)) {
        continue;
      }
      if (!folded.startsWith(f, i + 1)) continue;
      final e = i + 1 + f.length;
      if (e < n && _wordChar.hasMatch(input[e])) continue;
      bestName = name;
      bestEnd = e;
    }
    if (bestName != null) {
      assign(bestEnd, bestName);
      return bestEnd;
    }

    final m = _nameRun.matchAsPrefix(input, i + 1);
    if (m == null) return i;
    final e = _trimName(i + 1, m.end);
    if (e <= i + 1) return i;
    final name = input.substring(i + 1, e);
    if (!_hasLetter.hasMatch(name)) return i;
    assign(e, canonical(name));
    return e;
  }

  int _priority(int i) {
    if (priority != null) return i;
    var j = i;
    while (j < n && input[j] == '!' && j - i < 4) {
      j++;
    }
    final run = j - i;
    bool endsWord(int k) => k >= n || _isWs(k) || ',;.)'.contains(input[k]);
    QuickPriority? value;
    var end = j;
    if (run <= 3 && endsWord(j)) {
      value = QuickPriority.values[run - 1];
    } else if (run == 1) {
      final m = RegExp(r'[a-zA-Z]+').matchAsPrefix(input, j);
      if (m != null && endsWord(m.end)) {
        value = switch (m[0]!.toLowerCase()) {
          'low' => QuickPriority.low,
          'med' || 'medium' => QuickPriority.medium,
          'high' => QuickPriority.high,
          _ => null,
        };
        end = m.end;
      }
    }
    if (value == null) return i;
    if (_tryClaim(TokenKind.priority, i, end, value)) priority = value;
    return end;
  }

  // -------------------------------------------------------------- recurrence

  void _recurrence() {
    final all = <RecurrenceMatch>[
      for (final g in grammars) ...g.recurrences(folded, ctx),
    ];
    final base = _pick<RecurrenceMatch>(
      TokenKind.recurrence,
      all.where((m) => m.role == RecurrenceRole.base && m.rule != null),
      (m) => m.start,
      (m) => m.end,
    );
    if (base == null) {
      for (final y in all.where((m) => m.role == RecurrenceRole.yearly)) {
        if (!_anyBlocked(y.start, y.end) &&
            !_off(TokenKind.recurrence, y.start)) {
          hint = 'recurrence.yearly_unsupported';
          break;
        }
      }
      return;
    }
    var r = base.rule!;
    final spans = <(int, int)>[(base.start, base.end)];
    _block(base.start, base.end);

    final completion = _pick<RecurrenceMatch>(
      TokenKind.recurrence,
      all.where((m) => m.role == RecurrenceRole.completion),
      (m) => m.start,
      (m) => m.end,
    );
    if (completion != null) {
      r = r.copyWith(completionBased: true);
      spans.add((completion.start, completion.end));
      _block(completion.start, completion.end);
    }

    // "until <date>" / "ends <date>"
    final dates = <DateMatch>[for (final g in grammars) ...g.dates(folded, ctx)]
      ..sort((a, b) {
        final c = a.start.compareTo(b.start);
        return c != 0 ? c : (b.end - b.start).compareTo(a.end - a.start);
      });
    outer:
    for (final d in dates) {
      if (_anyBlocked(d.start, d.end)) continue;
      for (final g in grammars) {
        final ms = g.endMarkerStart(folded, d.start);
        if (ms == null || _anyBlocked(ms, d.start)) continue;
        if (_off(TokenKind.recurrence, ms)) {
          _block(ms, d.end);
          continue outer;
        }
        r = r.copyWith(endDate: d.date);
        spans.add((ms, d.end));
        _block(ms, d.end);
        break outer;
      }
    }

    rule = r;
    for (final (s, e) in spans) {
      _commit(TokenKind.recurrence, s, e, r);
    }
  }

  // ------------------------------------------------------------ date and time

  void _dateAndTime() {
    final dates = <DateMatch>[
      for (final g in grammars) ...g.dates(folded, ctx),
    ];
    final d = _pick<DateMatch>(
      TokenKind.date,
      dates,
      (m) => m.start,
      (m) => m.end,
    );
    LocalTime? implied;
    if (d != null) {
      _commit(TokenKind.date, d.start, d.end, d.date);
      dueDate = d.date;
      implied = d.impliedTime;
    }

    final times = <TimeMatch>[
      for (final g in grammars) ...g.times(folded, ctx),
    ];
    bool attached(TimeMatch t) {
      if (d == null) return false;
      final String gap;
      if (t.end <= d.start) {
        gap = folded.substring(t.end, d.start);
      } else if (t.start >= d.end) {
        gap = folded.substring(d.end, t.start);
      } else {
        return false;
      }
      return _gap.hasMatch(gap);
    }

    final strong = times.where((t) => !t.needsAnchor);
    final weak = times.where((t) => t.needsAnchor && attached(t));
    final picked =
        _pick<TimeMatch>(
          TokenKind.time,
          strong,
          (t) => t.start,
          (t) => t.end,
        ) ??
        _pick<TimeMatch>(TokenKind.time, weak, (t) => t.start, (t) => t.end);
    if (picked != null) {
      _commit(TokenKind.time, picked.start, picked.end, picked.time);
      dueTime = picked.time;
    } else if (!disabled.contains(TokenKind.time)) {
      dueTime = implied;
    }
  }

  void _impliedDue() {
    final r = rule;
    if (r == null || dueDate != null) return;
    // The first occurrence ignores the interval: "every 2 weeks on monday"
    // starts on the coming Monday.
    final occ = occurrencesBetween(
      r.copyWith(interval: 1),
      ctx.today,
      ctx.today,
      ctx.today.addDays(800),
      limit: 1,
    );
    if (occ.isNotEmpty) {
      dueDate = occ.first;
      impliedDue = true;
    }
  }

  // -------------------------------------------------------------------- title

  String _title() {
    final sb = StringBuffer();
    var i = 0;
    while (i < n) {
      if (removed[i]) {
        while (i < n && removed[i]) {
          i++;
        }
        sb.write(_sentinel);
      } else {
        sb.write(input[i]);
        i++;
      }
    }
    final parts = sb.toString().split(_sentinel);
    var out = parts[0];
    for (var k = 1; k < parts.length; k++) {
      final last = k == parts.length - 1;
      var right = parts[k].replaceFirst(_leadPunct, '');
      if (last && _tailOnly.hasMatch(right)) right = '';
      if (_sepOnly.hasMatch(out)) {
        out = '';
        right = right.replaceFirst(_leadSep, '');
        out = right;
      } else if (right.trim().isEmpty) {
        out = out.replaceFirst(_trailSep, '');
      } else {
        final l = out.trimRight();
        final r = right.trimLeft();
        final joinTight =
            l.isNotEmpty &&
            r.isNotEmpty &&
            ((_cjk.hasMatch(l[l.length - 1]) && _cjk.hasMatch(r[0])) ||
                '.!?,;:)'.contains(r[0]));
        out = l + (joinTight ? '' : ' ') + r;
      }
    }
    return _collapse(out);
  }
}
