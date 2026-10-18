import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tududa/auth/session/session_providers.dart';
import 'package:tududa/core/design/app_theme.dart';
import 'package:tududa/l10n/gen/app_localizations.dart';
import 'package:tududa/settings/providers/settings_provider.dart';
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/sync/sync_engine.dart';
import 'package:tududa/tasks/domain/task.dart';

import '../offline_rig.dart';

/// Like testWidgets, then unmounts the tree and lets drift's stream cleanup
/// timers run so none is left pending.
void detailTest(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

void initDateData() => setUpAll(initializeDateFormatting);

/// Gives database streams (real async) and the widget tree time to settle.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pumps [home] over an in-memory offline stack with the real theme (design
/// tokens). Call `rig.init()` (inside `runAsync`) first.
Future<void> pumpOffline(
  WidgetTester tester,
  OfflineRig rig,
  Widget home, {
  Locale locale = const Locale('en'),
  double textScale = 1,
}) async {
  // Tall enough that lazily built list sections are on screen.
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final sp = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        appDatabaseProvider.overrideWithValue(rig.db),
        syncEngineProvider.overrideWithValue(rig.engine),
        userClockProvider.overrideWithValue(rig.clock),
      ],
      child: MaterialApp(
        locale: locale,
        theme: buildTheme(
          brightness: Brightness.light,
          contrast: ContrastLevel.standard,
          density: DensityLevel.comfortable,
          reduceMotion: true,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: home,
      ),
    ),
  );
  await settle(tester);
}

/// All tasks in the local database (including subtasks).
Future<List<Task>> allTasks(WidgetTester tester, OfflineRig rig) async =>
    (await tester.runAsync(() async {
      final rows = await rig.db.select(rig.db.tasks).get();
      return rig.dao.hydrate(rows, withSubtasks: false);
    }))!;
