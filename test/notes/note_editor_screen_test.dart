import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tududa/core/design/app_theme.dart';
import 'package:tududa/l10n/gen/app_localizations.dart';
import 'package:tududa/notes/domain/note.dart';
import 'package:tududa/notes/providers/note_provider.dart';
import 'package:tududa/notes/screens/note_editor_screen.dart';
import 'package:tududa/projects/models/project_model.dart';
import 'package:tududa/projects/providers/project_provider.dart';
import 'package:tududa/settings/providers/settings_provider.dart';

class FakeNotes extends NoteListNotifier {
  final created = <NoteDraft>[];

  @override
  Stream<List<Note>> build() => Stream.value(const []);

  @override
  Future<Note> create(NoteDraft draft) async {
    created.add(draft);
    return Note(content: draft.content);
  }
}

class NoProjects extends ProjectList {
  @override
  Stream<List<Project>> build() => Stream.value(const []);
}

Future<(GoRouter, FakeNotes)> pumpEditor(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues({});
  final sp = await SharedPreferences.getInstance();
  final notes = FakeNotes();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('home')),
      ),
      GoRoute(path: '/notes/new', builder: (_, _) => const NoteEditorScreen()),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        noteListProvider.overrideWith(() => notes),
        projectListProvider.overrideWith(NoProjects.new),
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
  router.push('/notes/new');
  await tester.pumpAndSettle();
  return (router, notes);
}

Finder get contentField => find.byType(TextFormField).last;

void main() {
  testWidgets('toggles between Markdown edit and preview', (tester) async {
    await pumpEditor(tester);
    await tester.enterText(contentField, '# Heading\n\n**bold** text');
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();

    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.text('Heading'), findsOneWidget);
    expect(find.textContaining('# Heading'), findsNothing);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.byType(MarkdownBody), findsNothing);
    expect(find.textContaining('# Heading'), findsOneWidget);
  });

  testWidgets('preview of an empty note says so', (tester) async {
    await pumpEditor(tester);
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing to preview yet'), findsOneWidget);
  });

  testWidgets('leaving a pristine editor does not ask', (tester) async {
    final (router, _) = await pumpEditor(tester);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(find.text('Discard changes?'), findsNothing);
  });

  testWidgets('unsaved changes ask before leaving; keep editing stays', (
    tester,
  ) async {
    await pumpEditor(tester);
    await tester.enterText(contentField, 'draft');
    await tester.pump();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('draft'), findsOneWidget);
  });

  testWidgets('discarding leaves without saving', (tester) async {
    final (_, notes) = await pumpEditor(tester);
    await tester.enterText(contentField, 'draft');
    await tester.pump();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(notes.created, isEmpty);
  });

  testWidgets('saving leaves without asking', (tester) async {
    final (_, notes) = await pumpEditor(tester);
    await tester.enterText(contentField, 'kept');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(notes.created.single.content, 'kept');
    expect(find.text('home'), findsOneWidget);
    expect(find.text('Discard changes?'), findsNothing);
  });

  for (final locale in const [Locale('de'), Locale('zh')]) {
    testWidgets('renders at text scale 2.0 in ${locale.languageCode}', (
      tester,
    ) async {
      await pumpEditor(tester, locale: locale, textScale: 2);
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.text('Vorschau').evaluate().isNotEmpty
            ? find.text('Vorschau')
            : find.text('预览'),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
