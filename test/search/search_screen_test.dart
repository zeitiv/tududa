import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tududa/core/design/app_theme.dart';
import 'package:tududa/core/ids.dart';
import 'package:tududa/l10n/gen/app_localizations.dart';
import 'package:tududa/search/data/recent_searches.dart';
import 'package:tududa/search/domain/search_query.dart';
import 'package:tududa/search/domain/search_result.dart';
import 'package:tududa/search/providers/search_provider.dart';
import 'package:tududa/search/screens/search_screen.dart';
import 'package:tududa/settings/providers/settings_provider.dart';

class _FakeController extends SearchNotifier {
  _FakeController(this.initial);
  final SearchState initial;
  final texts = <String>[];

  @override
  SearchState build() => initial;

  @override
  void setText(String text, {bool immediate = false}) {
    texts.add(text);
    state = state.copyWith(text: text);
  }
}

const _hits = <SearchResult>[
  TaskHit(uid: TaskUid('t1'), name: 'Buy milk', projectName: 'Home'),
  ProjectHit(uid: ProjectUid('p1'), name: 'Milk run'),
  AreaHit(uid: AreaUid('a1'), name: 'Kitchen'),
  NoteHit(uid: NoteUid('n1'), name: 'Groceries', description: 'milk, eggs'),
  TagHit(uid: TagUid('g1'), name: 'milky'),
];

Future<({GoRouter router, _FakeController ctl})> pump(
  WidgetTester tester, {
  SearchState state = const SearchState(
    text: 'milk',
    phase: SearchPhase.data,
    results: _hits,
  ),
  Locale locale = const Locale('en'),
  double textScale = 1,
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final ctl = _FakeController(state);
  final router = GoRouter(
    initialLocation: '/search',
    routes: [
      GoRoute(path: '/search', builder: (_, _) => const SearchScreen()),
      GoRoute(
        path: '/:a/:b',
        builder: (_, s) => Scaffold(body: Text('went ${s.uri.path}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        searchControllerProvider.overrideWith(() => ctl),
      ],
      child: MaterialApp.router(
        locale: locale,
        theme: buildTheme(
          brightness: Brightness.light,
          contrast: ContrastLevel.standard,
          density: DensityLevel.comfortable,
          reduceMotion: false,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return (router: router, ctl: ctl);
}

void main() {
  testWidgets('results are grouped by type with headers', (tester) async {
    await pump(tester);
    for (final t in SearchType.values) {
      expect(find.byKey(Key('search.group.${t.name}')), findsOneWidget);
    }
    expect(find.text('Tasks (1)'), findsOneWidget);
    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.byKey(const Key('search.offline')), findsNothing);
    expect(
      tester.widget<TextField>(find.byKey(const Key('search.field'))).autofocus,
      isTrue,
    );
  });

  testWidgets('taps route to the entity; tag fills the query', (tester) async {
    final r = await pump(tester);
    await tester.tap(find.byKey(const Key('search.hit.t1')));
    await tester.pumpAndSettle();
    expect(find.text('went /tasks/t1'), findsOneWidget);
    r.router.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('search.hit.p1')));
    await tester.pumpAndSettle();
    expect(find.text('went /projects/p1'), findsOneWidget);
    r.router.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('search.hit.n1')));
    await tester.pumpAndSettle();
    expect(find.text('went /notes/n1'), findsOneWidget);
    r.router.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('search.hit.a1')));
    await tester.pumpAndSettle();
    expect(find.text('went /more/areas'), findsOneWidget);
    r.router.pop();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('search.hit.g1')),
      100,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const Key('search.hit.g1')));
    await tester.pump();
    expect(r.ctl.texts.last, '#milky');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('search.field')))
          .controller!
          .text,
      '#milky',
    );
  });

  testWidgets('offline banner, clear button, suggestion chip', (tester) async {
    final r = await pump(
      tester,
      state: const SearchState(
        text: 'milk',
        phase: SearchPhase.data,
        results: _hits,
        offline: true,
      ),
    );
    expect(find.text('Showing offline results'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('search.field')), 'milk');
    await tester.pump();
    await tester.tap(find.byKey(const Key('search.suggestion.is:overdue')));
    await tester.pump();
    expect(r.ctl.texts.last, 'milk is:overdue');
    await tester.tap(find.byKey(const Key('search.clear')));
    await tester.pump();
    expect(r.ctl.texts.last, '');
  });

  testWidgets('empty query shows recent searches', (tester) async {
    final r = await pump(
      tester,
      state: const SearchState(),
      prefs: {
        RecentSearches.prefsKey: ['alpha', 'beta'],
      },
    );
    expect(find.byKey(const Key('search.recent')), findsOneWidget);
    await tester.tap(find.text('alpha'));
    await tester.pump();
    expect(r.ctl.texts.last, 'alpha');
  });

  testWidgets('recent searches can be cleared', (tester) async {
    await pump(
      tester,
      state: const SearchState(),
      prefs: {
        RecentSearches.prefsKey: ['alpha', 'beta'],
      },
    );
    await tester.tap(find.byKey(const Key('search.recentClear')));
    await tester.pump();
    expect(find.text('beta'), findsNothing);
  });

  testWidgets('no results and error states', (tester) async {
    await pump(
      tester,
      state: const SearchState(text: 'zzz', phase: SearchPhase.data),
    );
    expect(find.text('No results for “zzz”'), findsOneWidget);
  });

  testWidgets('error state', (tester) async {
    await pump(
      tester,
      state: const SearchState(text: 'zzz', phase: SearchPhase.error),
    );
    expect(find.byKey(const Key('search.retry')), findsOneWidget);
  });

  testWidgets('text scale 2.0 does not overflow', (tester) async {
    await pump(
      tester,
      textScale: 2,
      state: const SearchState(
        text: 'milk',
        phase: SearchPhase.data,
        results: _hits,
        offline: true,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  for (final locale in const [Locale('de'), Locale('zh')]) {
    testWidgets('smoke ${locale.languageCode}', (tester) async {
      await pump(tester, locale: locale, textScale: 2);
      expect(tester.takeException(), isNull);
      expect(find.text('Tasks (1)'), findsNothing);
      expect(find.byKey(const Key('search.group.task')), findsOneWidget);
    });
  }
}
