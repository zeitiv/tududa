import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tududa/core/design/app_theme.dart';
import 'package:tududa/core/ids.dart';
import 'package:tududa/core/time/calendar_date.dart';
import 'package:tududa/core/time/date_formatters.dart';
import 'package:tududa/l10n/gen/app_localizations.dart';
import 'package:tududa/settings/providers/settings_provider.dart';
import 'package:tududa/tasks/domain/task.dart';
import 'package:tududa/tasks/providers/task_provider.dart';
import 'package:tududa/tasks/widgets/task_tile.dart';

/// Build / scroll budget for a 1,000-row task list (plain widget test, no
/// device). The budgets are deliberately generous (shared CI runners are
/// slow and noisy); they exist to catch order-of-magnitude regressions such
/// as a tile that does I/O or an O(n^2) list build, not to benchmark.
/// Real frame timings come from `integration_test/perf_test.dart`.
const _rows = 1000;
const _firstScreenBudget = Duration(milliseconds: 1500);
const _scrollBudget = Duration(seconds: 10);

final _today = CalendarDate(2026, 10, 14);

List<Task> _tasks() => [
  for (var i = 0; i < _rows; i++)
    Task(
      uid: TaskUid('t$i'),
      name: 'Task number $i with a reasonably long title to wrap sometimes',
      dueDate: i % 3 == 0 ? _today.addDays(i % 9 - 4) : null,
      priority: Priority.fromCode(i % 3),
      projectName: i % 4 == 0 ? 'Project ${i % 7}' : null,
      tags: [
        if (i % 5 == 0) TaskTag(name: 'tag${i % 6}'),
        if (i % 11 == 0) TaskTag(name: 'urgent'),
      ],
    ),
];

void main() {
  setUpAll(DateFormats.ensureInitialized);

  testWidgets('1,000 TaskTile rows: first screen and 5 screens of scroll', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final sp = await SharedPreferences.getInstance();
    final tasks = _tasks();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    // Frame timings are not reported by the test engine, so the real-time
    // `Stopwatch` (not affected by the fake clock) around pumps is the measure.
    final buildWatch = Stopwatch()..start();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sp),
          taskDayProvider.overrideWithValue(TaskDay.utc(_today)),
        ],
        child: MaterialApp(
          theme: buildTheme(
            brightness: Brightness.light,
            contrast: ContrastLevel.standard,
            density: DensityLevel.comfortable,
            reduceMotion: false,
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (_, i) => TaskTile(task: tasks[i]),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    buildWatch.stop();
    // ignore: avoid_print
    print(
      'PERF first screen of $_rows-row list: '
      '${buildWatch.elapsedMilliseconds} ms '
      '(${find.byType(TaskTile).evaluate().length} tiles built)',
    );
    expect(find.byType(TaskTile), findsWidgets);
    expect(buildWatch.elapsed, lessThan(_firstScreenBudget));

    final scroll = Stopwatch()..start();
    final frames = <int>[];
    final height =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    for (var screen = 0; screen < 5; screen++) {
      final f = Stopwatch()..start();
      await tester.drag(find.byType(ListView), Offset(0, -height * 0.9));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      f.stop();
      frames.add(f.elapsedMilliseconds);
    }
    scroll.stop();
    // ignore: avoid_print
    print(
      'PERF scroll 5 screens: ${scroll.elapsedMilliseconds} ms total, '
      'per screen (drag + settle) $frames ms',
    );
    expect(tester.takeException(), isNull);
    expect(scroll.elapsed, lessThan(_scrollBudget));
  });
}
