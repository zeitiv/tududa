import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tududa/core/time/calendar_date.dart';
import 'package:tududa/search/data/recent_searches.dart';
import 'package:tududa/search/domain/search_filter.dart';
import 'package:tududa/search/domain/search_query.dart';
import 'package:tududa/search/domain/search_result.dart';
import 'package:tududa/core/ids.dart';

void main() {
  group('ParsedSearch.parse', () {
    test('syntax table', () {
      final cases = <String, void Function(ParsedSearch)>{
        'milk': (p) => expect(p.text, 'milk'),
        '#home #work': (p) => expect(p.tags, ['home', 'work']),
        '#"to do" x': (p) {
          expect(p.tags, ['to do']);
          expect(p.text, 'x');
        },
        '+Garten ~Haus': (p) {
          expect(p.project, 'Garten');
          expect(p.area, 'Haus');
        },
        '+"Home reno"': (p) => expect(p.project, 'Home reno'),
        '#标签 ~领域': (p) {
          expect(p.tags, ['标签']);
          expect(p.area, '领域');
        },
        'IS:Overdue is:done': (p) =>
            expect(p.flags, {SearchIs.overdue, SearchIs.done}),
        'priority:HIGH': (p) => expect(p.priority, 'high'),
        'due:tomorrow': (p) => expect(p.due, SearchDue.tomorrow),
        'due:week': (p) => expect(p.due, SearchDue.week),
        'due:2026-03-04': (p) {
          expect(p.due, SearchDue.date);
          expect(p.dueDate, const CalendarDate(2026, 3, 4));
        },
        // unknown / malformed tokens stay free text
        'is:later': (p) => expect(p.text, 'is:later'),
        'priority:urgent': (p) => expect(p.text, 'priority:urgent'),
        'due:2026-13-45': (p) => expect(p.text, 'due:2026-13-45'),
        'foo:bar # + ~': (p) => expect(p.text, 'foo:bar # + ~'),
        'http://x.y': (p) => expect(p.text, 'http://x.y'),
        'buy #milk is:today bread': (p) {
          expect(p.text, 'buy bread');
          expect(p.tags, ['milk']);
          expect(p.flags, {SearchIs.today});
        },
      };
      cases.forEach((raw, check) => check(ParsedSearch.parse(raw)));
    });

    test('isEmpty and helpers', () {
      expect(ParsedSearch.parse('  ').isEmpty, isTrue);
      expect(ParsedSearch.parse('#a').isEmpty, isFalse);
      expect(ParsedSearch.append('milk ', '#'), 'milk #');
      expect(ParsedSearch.tagToken('to do'), '#"to do"');
      expect(ParsedSearch.tagToken('home'), '#home');
    });
  });

  group('filters', () {
    const today = CalendarDate(2026, 10, 18);
    TaskHit t(
      String id, {
      String? status,
      CalendarDate? due,
      String prio = 'low',
    }) => TaskHit(
      uid: TaskUid(id),
      name: id,
      status: status,
      dueDate: due,
      priority: prio,
    );
    List<String> ids(List<SearchResult> l) => [for (final h in l) h.name];

    test('is:/due:/priority: narrow tasks and drop other types', () {
      final hits = <SearchResult>[
        t('late', status: 'not_started', due: today.addDays(-2), prio: 'high'),
        t('lateDone', status: 'done', due: today.addDays(-2)),
        t('now', due: today),
        t('soon', due: today.addDays(1)),
        t('later', due: today.addDays(9)),
        const TagHit(uid: TagUid('g'), name: 'tag'),
      ];
      List<String> run(String q) =>
          ids(applyTaskFilters(hits, ParsedSearch.parse(q), today));
      expect(run('is:overdue'), ['late']);
      expect(run('is:today'), ['now']);
      expect(run('is:done'), ['lateDone']);
      expect(run('due:tomorrow'), ['soon']);
      expect(run('due:week'), ['now', 'soon']);
      expect(run('due:2026-10-27'), ['later']);
      expect(run('priority:high'), ['late']);
      expect(run('x').length, hits.length);
    });

    test('ranking: prefix, contains, description; grouped by type', () {
      final r = rankResults(const [
        NoteHit(uid: NoteUid('n'), name: 'zzz', description: 'milk'),
        TaskHit(uid: TaskUid('a'), name: 'Buy milk'),
        TaskHit(uid: TaskUid('b'), name: 'Milk run'),
        TaskHit(uid: TaskUid('c'), name: 'other', description: 'milk'),
      ], 'milk');
      expect(ids(r), ['Milk run', 'Buy milk', 'other', 'zzz']);
    });
  });

  group('RecentSearches', () {
    test('keeps 10 newest, de-dups case-insensitively, clears', () async {
      SharedPreferences.setMockInitialValues({});
      final store = RecentSearches(await SharedPreferences.getInstance());
      for (var i = 0; i < 12; i++) {
        await store.add('q$i');
      }
      expect(store.load().length, 10);
      expect(store.load().first, 'q11');
      expect(store.load().last, 'q2');
      await store.add('  Q5 ');
      expect(store.load().first, 'Q5');
      expect(store.load().where((q) => q.toLowerCase() == 'q5').length, 1);
      await store.add('  ');
      expect(store.load().length, 10);
      await store.remove('Q5');
      expect(store.load().length, 9);
      await store.clear();
      expect(store.load(), isEmpty);
    });
  });
}
