import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tududa/auth/session/session_providers.dart';
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/design/app_theme.dart';
import 'package:tududa/core/sync/sync_engine.dart';
import 'package:tududa/l10n/gen/app_localizations.dart';
import 'package:tududa/settings/providers/settings_provider.dart';

import '../offline_rig.dart';

/// Pumps [home] over the in-memory [rig] with the real theme (tokens).
Future<void> pumpWithRig(
  WidgetTester tester,
  OfflineRig rig, {
  required Widget home,
  Locale locale = const Locale('en'),
  double textScale = 1.0,
  SyncEngine? engine,
  List<Override> overrides = const [],
}) async {
  await initializeDateFormatting();
  SharedPreferences.setMockInitialValues({});
  final sp = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        appDatabaseProvider.overrideWithValue(rig.db),
        syncEngineProvider.overrideWithValue(engine ?? rig.engine),
        userClockProvider.overrideWithValue(rig.clock),
        ...overrides,
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

/// Lets real async work (Drift queries, sync) finish, then rebuilds.
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 150)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// Runs database writes in real time (testWidgets uses fake async).
Future<T> seed<T>(WidgetTester tester, Future<T> Function() body) async =>
    (await tester.runAsync(body)) as T;

/// Unmounts the tree so sync helpers can run without live listeners.
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  // Drift closes query streams on a zero-duration timer.
  await tester.pump(const Duration(milliseconds: 10));
}
