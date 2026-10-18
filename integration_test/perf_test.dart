// Runs on an Android emulator/device (NOT part of `flutter test`):
//   flutter test integration_test/perf_test.dart -d emulator-5554 --profile
//
// Scrolls a 1,000-task list of real TaskTile rows up and down and prints the
// frame build / raster percentiles to the console. Run with `--profile` for
// meaningful numbers: debug builds are several times slower. No budget is
// asserted (device speed varies); CI only collects the numbers.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
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

const _rows = 1000;
final _today = CalendarDate(2026, 10, 14);

List<Task> _tasks() => [
  for (var i = 0; i < _rows; i++)
    Task(
      uid: TaskUid('t$i'),
      name: 'Task number $i with a reasonably long title to wrap sometimes',
      dueDate: i % 3 == 0 ? _today.addDays(i % 9 - 4) : null,
      priority: Priority.fromCode(i % 3),
      projectName: i % 4 == 0 ? 'Project ${i % 7}' : null,
      tags: [if (i % 5 == 0) TaskTag(name: 'tag${i % 6}')],
    ),
];

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('scroll a 1,000-task list: frame build/raster percentiles', (
    tester,
  ) async {
    await DateFormats.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final sp = await SharedPreferences.getInstance();
    final tasks = _tasks();

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
              key: const Key('perf-list'),
              itemCount: tasks.length,
              itemBuilder: (_, i) => TaskTile(task: tasks[i]),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final list = find.byKey(const Key('perf-list'));
    await binding.watchPerformance(() async {
      for (var pass = 0; pass < 3; pass++) {
        await tester.fling(list, const Offset(0, -600), 3000);
        await tester.pumpAndSettle();
      }
      for (var pass = 0; pass < 3; pass++) {
        await tester.fling(list, const Offset(0, 600), 3000);
        await tester.pumpAndSettle();
      }
    }, reportKey: 'task_list_scroll');

    final r = binding.reportData!['task_list_scroll'] as Map<String, dynamic>;
    String f(String key) => (r[key] as num?)?.toStringAsFixed(2) ?? 'n/a';
    // ignore: avoid_print
    print(
      'PERF task_list_scroll ($_rows rows)\n'
      '  frames:        ${r['frame_count']}\n'
      '  build  avg/p90/p99/worst ms: ${f('average_frame_build_time_millis')} / '
      '${f('90th_percentile_frame_build_time_millis')} / '
      '${f('99th_percentile_frame_build_time_millis')} / '
      '${f('worst_frame_build_time_millis')}\n'
      '  raster avg/p90/p99/worst ms: ${f('average_frame_rasterizer_time_millis')} / '
      '${f('90th_percentile_frame_rasterizer_time_millis')} / '
      '${f('99th_percentile_frame_rasterizer_time_millis')} / '
      '${f('worst_frame_rasterizer_time_millis')}\n'
      '  missed build budget (16 ms): ${r['missed_frame_build_budget_count']}',
    );
    expect(r['frame_count'], isNonZero);
  });
}
