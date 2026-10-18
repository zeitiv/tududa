import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tududa/core/design/app_theme.dart';
import 'package:tududa/core/ids.dart';
import 'package:tududa/core/time/date_formatters.dart';
import 'package:tududa/inbox/domain/inbox_item.dart';
import 'package:tududa/inbox/providers/inbox_provider.dart';
import 'package:tududa/inbox/screens/inbox_screen.dart';
import 'package:tududa/l10n/gen/app_localizations.dart';
import 'package:tududa/notes/domain/note.dart';
import 'package:tududa/notes/providers/note_provider.dart';
import 'package:tududa/settings/providers/settings_provider.dart';
import 'package:tududa/tasks/domain/task.dart';
import 'package:tududa/tasks/providers/task_provider.dart';
import 'package:tududa/core/time/calendar_date.dart';

/// In-memory inbox: no database, so no drift streams under fake async.
class FakeInbox extends InboxNotifier {
  FakeInbox(this.initial);
  final List<InboxItem> initial;
  final captured = <String>[];
  final processed = <String>[];
  final targets = <String?>[];
  final deleted = <String>[];
  final ignored = <String>[];

  @override
  Future<InboxList> build() async => InboxList(items: initial);

  void _set(List<InboxItem> items) =>
      state = AsyncData(InboxList(items: items));

  @override
  Future<bool> capture(String text, {String source = 'mobile'}) async {
    captured.add(text);
    _set([
      InboxItem(
        uid: InboxUid('new${captured.length}'),
        content: text,
        createdAt: DateTime.now(),
      ),
      ...state.value!.items,
    ]);
    return true;
  }

  @override
  Future<bool> process(InboxUid uid, {InboxProcessTarget? target}) async {
    processed.add(uid.value);
    targets.add(target?.uid);
    _set([
      for (final i in state.value!.items)
        if (i.uid != uid) i,
    ]);
    return true;
  }

  @override
  Future<bool> delete(InboxUid uid) async {
    deleted.add(uid.value);
    _set([
      for (final i in state.value!.items)
        if (i.uid != uid) i,
    ]);
    return true;
  }

  @override
  Future<bool> ignore(InboxUid uid) async {
    ignored.add(uid.value);
    return true;
  }

  @override
  Future<void> loadMore() async {}
}

class FakeNotes extends NoteListNotifier {
  final created = <NoteDraft>[];

  @override
  Stream<List<Note>> build() => Stream.value(const []);

  @override
  Future<Note> create(NoteDraft draft) async {
    created.add(draft);
    return Note(uid: const NoteUid('n1'), content: draft.content);
  }
}

InboxItem item(String uid, String content, {Duration age = Duration.zero}) =>
    InboxItem(
      uid: InboxUid(uid),
      content: content,
      createdAt: DateTime.now().subtract(age),
    );

Task task(String name, {ProjectUid? project, CalendarDate? due}) =>
    Task(uid: TaskUid(name), name: name, projectUid: project, dueDate: due);

Future<(FakeInbox, FakeNotes)> pumpInbox(
  WidgetTester tester, {
  List<InboxItem> items = const [],
  List<Task> tasks = const [],
  Locale locale = const Locale('en'),
  double textScale = 1,
  Future<Task?> Function(BuildContext, String)? openQuickAdd,
}) async {
  SharedPreferences.setMockInitialValues({});
  final sp = await SharedPreferences.getInstance();
  final inbox = FakeInbox(items);
  final notes = FakeNotes();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => openQuickAdd == null
            ? const InboxScreen()
            : InboxScreen(openQuickAdd: openQuickAdd),
      ),
      GoRoute(
        path: '/tasks/new',
        builder: (_, _) => const Scaffold(body: Text('task form')),
      ),
      GoRoute(
        path: '/notes/:id',
        builder: (_, s) =>
            Scaffold(body: Text('note ${s.pathParameters['id']}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        inboxProvider.overrideWith(() => inbox),
        noteListProvider.overrideWith(() => notes),
        taskViewListProvider.overrideWith((ref, view) => Stream.value(tasks)),
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
  return (inbox, notes);
}

void main() {
  setUpAll(DateFormats.ensureInitialized);

  test('unsortedTasks keeps only tasks without project and date', () {
    final out = unsortedTasks([
      task('a'),
      task('b', project: const ProjectUid('p')),
      task('c', due: const CalendarDate(2026, 1, 1)),
    ]);
    expect([for (final t in out) t.name], ['a']);
  });

  testWidgets('captures a thought and shows it as a card', (tester) async {
    final (inbox, _) = await pumpInbox(tester);
    expect(find.text('Inbox is empty'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Buy milk');
    await tester.tap(find.byTooltip('Add to inbox'));
    await tester.pump();
    await tester.pump();

    expect(inbox.captured, ['Buy milk']);
    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.text('Just now'), findsOneWidget);
  });

  testWidgets('shows the age of an item', (tester) async {
    await pumpInbox(
      tester,
      items: [item('1', 'Old', age: const Duration(hours: 3))],
    );
    expect(find.text('3 h ago'), findsOneWidget);
  });

  testWidgets('convert to note creates the note and processes the item', (
    tester,
  ) async {
    final (inbox, notes) = await pumpInbox(
      tester,
      items: [item('1', 'Remember this')],
    );
    await tester.tap(find.text('Convert to note'));
    await tester.pump();
    await tester.pump();

    expect(notes.created.single.content, 'Remember this');
    expect(inbox.processed, ['1']);
    expect(inbox.targets, ['n1']);
    expect(find.text('Saved as note'), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('note n1'), findsOneWidget);
  });

  testWidgets('convert to task processes the item once a task was saved', (
    tester,
  ) async {
    Task? result = task('t1');
    String? seenText;
    final (inbox, _) = await pumpInbox(
      tester,
      items: [item('1', 'Call Bob')],
      openQuickAdd: (context, text) async {
        seenText = text;
        return result;
      },
    );
    await tester.tap(find.text('Convert to task'));
    await tester.pumpAndSettle();
    expect(seenText, 'Call Bob');
    expect(inbox.processed, ['1']);
    expect(inbox.targets, ['t1']);
  });

  testWidgets('closing quick add without saving keeps the item', (
    tester,
  ) async {
    final (inbox, _) = await pumpInbox(
      tester,
      items: [item('1', 'Call Bob')],
      openQuickAdd: (context, text) async => null,
    );
    await tester.tap(find.text('Convert to task'));
    await tester.pumpAndSettle();
    expect(inbox.processed, isEmpty);
    expect(find.text('Call Bob'), findsOneWidget);
  });

  testWidgets('swipe processes after the undo window; undo restores', (
    tester,
  ) async {
    final (inbox, _) = await pumpInbox(
      tester,
      items: [item('1', 'First'), item('2', 'Second')],
    );
    await tester.drag(find.text('First'), const Offset(800, 0));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('First'), findsNothing);
    expect(find.text('Marked as processed'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('First'), findsOneWidget);
    expect(inbox.processed, isEmpty);

    await tester.drag(find.text('First'), const Offset(800, 0));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(inbox.processed, ['1']);
  });

  testWidgets('swipe left deletes after the undo window', (tester) async {
    final (inbox, _) = await pumpInbox(tester, items: [item('1', 'First')]);
    await tester.drag(find.text('First'), const Offset(-800, 0));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(inbox.deleted, ['1']);
    expect(find.text('Inbox is empty'), findsOneWidget);
  });

  testWidgets('lists tasks without project or date', (tester) async {
    await pumpInbox(
      tester,
      tasks: [
        task('Loose task'),
        task('Planned', due: const CalendarDate(2030, 1, 1)),
      ],
    );
    await tester.scrollUntilVisible(
      find.text('Loose task'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Tasks without project or date'), findsOneWidget);
    expect(find.text('Loose task'), findsOneWidget);
    expect(find.text('Planned'), findsNothing);
  });

  for (final locale in const [Locale('de'), Locale('zh')]) {
    testWidgets('renders at text scale 2.0 in ${locale.languageCode}', (
      tester,
    ) async {
      await pumpInbox(
        tester,
        items: [item('1', 'A fairly long inbox entry that wraps over lines')],
        tasks: [task('Loose task')],
        locale: locale,
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(InboxScreen), findsOneWidget);
    });
  }
}
