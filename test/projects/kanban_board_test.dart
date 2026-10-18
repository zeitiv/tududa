import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/design/app_theme.dart';
import 'package:tududa/core/ids.dart';
import 'package:tududa/core/time/date_formatters.dart';
import 'package:tududa/l10n/gen/app_localizations.dart';
import 'package:tududa/projects/data/project_tasks_source.dart';
import 'package:tududa/projects/widgets/kanban_board.dart';

ProjectTaskRef ref(String name, {int status = 0, int priority = 0}) =>
    ProjectTaskRef(
      uid: TaskUid(name),
      name: name,
      status: status,
      priority: priority,
    );

Future<List<(String, int)>> pumpBoard(
  WidgetTester tester, {
  required List<ProjectTaskRef> tasks,
  Locale locale = const Locale('en'),
  double textScale = 1,
  Size size = const Size(400, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final moves = <(String, int)>[];
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      theme: buildTheme(
        brightness: Brightness.light,
        contrast: ContrastLevel.standard,
        density: DensityLevel.comfortable,
        reduceMotion: false,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: KanbanBoard(
          tasks: tasks,
          onTaskStatusChanged: (t, s) => moves.add((t.name, s)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return moves;
}

void main() {
  setUpAll(DateFormats.ensureInitialized);

  testWidgets('columns show titles and counts', (tester) async {
    await pumpBoard(
      tester,
      tasks: [ref('A'), ref('B'), ref('C', status: 1, priority: 2)],
    );
    expect(find.text('To Do'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('Planned'), findsOneWidget);
    expect(find.text('Nothing here'), findsWidgets);
  });

  testWidgets('moves a card through the Move to menu', (tester) async {
    final moves = await pumpBoard(tester, tasks: [ref('A')]);
    await tester.tap(find.byTooltip('Move to…'));
    await tester.pumpAndSettle();
    expect(find.text('(Current)'), findsOneWidget);
    await tester.tap(find.text('In Progress').last);
    await tester.pumpAndSettle();
    expect(moves, [('A', 1)]);
    expect(find.text('Moved to In Progress'), findsOneWidget);
  });

  testWidgets('moves a card with a screen reader action', (tester) async {
    final handle = tester.ensureSemantics();
    final moves = await pumpBoard(tester, tasks: [ref('A')]);
    final node = tester.getSemantics(find.text('A'));
    final data = node.getSemanticsData();
    final labels = [
      for (final id in data.customSemanticsActionIds ?? const <int>[])
        CustomSemanticsAction.getAction(id)!.label,
    ];
    expect(labels, contains('Move to In Progress'));
    expect(labels, isNot(contains('Move to To Do')));
    handle.dispose();
    expect(moves, isEmpty);
  });

  testWidgets('dragging a card onto another column moves it', (tester) async {
    final moves = await pumpBoard(
      tester,
      tasks: [ref('A')],
      size: const Size(1200, 800),
    );
    final from = tester.getCenter(find.text('A'));
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(
      tester.getCenter(find.text('Planned')) + const Offset(0, 200),
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(moves, [('A', 6)]);
  });

  testWidgets('empty board shows the empty message', (tester) async {
    await pumpBoard(tester, tasks: const []);
    expect(find.textContaining('No tasks found'), findsOneWidget);
  });

  for (final locale in const [Locale('de'), Locale('zh')]) {
    testWidgets('renders at text scale 2.0 in ${locale.languageCode}', (
      tester,
    ) async {
      await pumpBoard(
        tester,
        tasks: [ref('A long task name that wraps a lot', priority: 1)],
        locale: locale,
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(KanbanBoard), findsOneWidget);
    });
  }
}
