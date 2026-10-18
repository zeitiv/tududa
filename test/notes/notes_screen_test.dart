import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tududa/core/design/app_theme.dart';
import 'package:tududa/core/ids.dart';
import 'package:tududa/core/time/date_formatters.dart';
import 'package:tududa/l10n/gen/app_localizations.dart';
import 'package:tududa/notes/domain/note.dart';
import 'package:tududa/notes/providers/note_provider.dart';
import 'package:tududa/notes/screens/notes_screen.dart';
import 'package:tududa/notes/widgets/note_card.dart';
import 'package:tududa/settings/providers/settings_provider.dart';
import 'package:tududa/tags/domain/tag.dart';

class FakeNoteList extends NoteListNotifier {
  FakeNoteList(this.notes);
  final List<Note> notes;

  @override
  Stream<List<Note>> build() => Stream.value(notes);
}

Note note(String id, String title, {String? content, String? color}) => Note(
  uid: NoteUid(id),
  title: title,
  content: content,
  color: color,
  updatedAt: DateTime(2026, 10, 1),
);

Future<void> pumpNotes(
  WidgetTester tester,
  List<Note> notes, {
  Locale locale = const Locale('en'),
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  SharedPreferences.setMockInitialValues({});
  final sp = await SharedPreferences.getInstance();
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const NotesScreen()),
      GoRoute(
        path: '/notes/:id',
        builder: (_, s) =>
            Scaffold(body: Text('editor ${s.pathParameters['id']}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        noteListProvider.overrideWith(() => FakeNoteList(notes)),
      ],
      child: MaterialApp.router(
        locale: locale,
        theme: buildTheme(
          brightness: brightness,
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
}

void main() {
  setUpAll(DateFormats.ensureInitialized);

  test('noteMatches looks at title, content, project and tags', () {
    final n = Note(
      title: 'Groceries',
      content: 'Milk and eggs',
      projectName: 'Home',
      tags: const [Tag(name: 'shopping')],
    );
    for (final q in ['grocer', 'eggs', 'home', 'shop', '']) {
      expect(noteMatches(n, q), isTrue, reason: q);
    }
    expect(noteMatches(n, 'taxes'), isFalse);
  });

  testWidgets('search filters notes locally and can be cleared', (
    tester,
  ) async {
    await pumpNotes(tester, [
      note('1', 'Groceries', content: 'milk'),
      note('2', 'Taxes', content: 'file by April'),
    ]);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Taxes'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'milk');
    await tester.pump();
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Taxes'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('No notes match your search'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    expect(find.text('Taxes'), findsOneWidget);
  });

  testWidgets('toggles between grid and list layout', (tester) async {
    await pumpNotes(tester, [note('1', 'One'), note('2', 'Two')]);
    // Grid: the two cards sit side by side.
    expect(
      tester.getTopLeft(find.text('One')).dy,
      tester.getTopLeft(find.text('Two')).dy,
    );
    await tester.tap(find.byTooltip('List view'));
    await tester.pump();
    expect(
      tester.getTopLeft(find.text('Two')).dy,
      greaterThan(tester.getTopLeft(find.text('One')).dy),
    );
    expect(find.byTooltip('Grid view'), findsOneWidget);
  });

  testWidgets('tapping a note opens it', (tester) async {
    await pumpNotes(tester, [note('abc', 'One')]);
    await tester.tap(find.text('One'));
    await tester.pumpAndSettle();
    expect(find.text('editor abc'), findsOneWidget);
  });

  testWidgets('shows the empty state', (tester) async {
    await pumpNotes(tester, const []);
    expect(find.textContaining('No notes yet'), findsOneWidget);
  });

  test('colored cards keep readable text in both brightnesses', () {
    for (final b in Brightness.values) {
      final scheme = ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: b,
      );
      for (final hex in ['#FFD6D6', '#CCE5FF', '#D6FFD6', '#E8CCFF']) {
        final bg = noteSurfaceColor(scheme, hex);
        final fg = scheme.onSurface;
        final ratio =
            (fg.computeLuminance() + 0.05) / (bg.computeLuminance() + 0.05);
        final contrast = ratio > 1 ? ratio : 1 / ratio;
        expect(contrast, greaterThan(4.5), reason: '$b $hex');
      }
    }
  });

  for (final locale in const [Locale('de'), Locale('zh')]) {
    testWidgets('renders at text scale 2.0 in ${locale.languageCode}', (
      tester,
    ) async {
      await pumpNotes(
        tester,
        [
          note(
            '1',
            'A rather long note title that wraps',
            content: 'Body text ' * 30,
            color: '#CCE5FF',
          ),
          note('2', 'Two', color: '#FFD6D6'),
        ],
        locale: locale,
        textScale: 2,
        brightness: Brightness.dark,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(IconButton).first);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
