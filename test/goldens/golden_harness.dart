import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tududa/core/design/app_theme.dart';
import 'package:tududa/core/time/calendar_date.dart';
import 'package:tududa/core/time/date_formatters.dart';
import 'package:tududa/l10n/gen/app_localizations.dart';
import 'package:tududa/settings/providers/settings_provider.dart';
import 'package:tududa/tasks/providers/task_provider.dart';

// Golden tests (alchemist). CI goldens only: font-blocks (Ahem), so they are
// deterministic across operating systems; platform goldens are disabled in
// flutter_test_config.dart. All tests are tagged `golden`.
//
//   flutter test --exclude-tags golden          # skips them
//   flutter test --tags golden                  # compares test/goldens/**/ci/*.png
//   flutter test --tags golden --update-goldens # regenerates (tool/ci/golden_update.sh)

/// The fixed "today" every golden uses.
final goldenToday = CalendarDate(2026, 10, 14);

/// Sets up what each golden test file needs; call from `main()`.
void setUpGoldens() {
  setUpAll(() async {
    await DateFormats.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });
}

late SharedPreferences _prefs;

/// Wraps [child] in the real theme, localization, a fixed text scale and
/// disabled animations (skeleton pulse stays still).
Widget goldenFrame(
  Widget child, {
  required Brightness brightness,
  required Locale locale,
  double textScale = 1,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(_prefs),
      taskDayProvider.overrideWithValue(TaskDay.utc(goldenToday)),
      ...overrides,
    ],
    child: Theme(
      data: buildTheme(
        brightness: brightness,
        contrast: ContrastLevel.standard,
        density: DensityLevel.comfortable,
        reduceMotion: true,
      ),
      child: Localizations(
        locale: locale,
        delegates: AppLocalizations.localizationsDelegates,
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: true,
            ),
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Light and dark in English, plus German (long strings) at 1.3x text scale.
/// [build] receives the locale so a case can use localized sample text.
Future<void> goldenCase(
  String name, {
  required Widget Function(Locale locale) build,
  List<Override> Function(Locale locale)? overrides,
  double width = 360,
  double? height,
}) {
  GoldenTestScenario scenario(
    String label,
    Brightness b,
    Locale l,
    double scale,
  ) => GoldenTestScenario(
    name: label,
    constraints: BoxConstraints.tightFor(width: width, height: height),
    child: goldenFrame(
      build(l),
      brightness: b,
      locale: l,
      textScale: scale,
      overrides: overrides?.call(l) ?? const [],
    ),
  );
  const en = Locale('en'), de = Locale('de');
  return goldenTest(
    name,
    fileName: name,
    constraints: BoxConstraints(maxWidth: width * 2 + 100),
    builder: () => GoldenTestGroup(
      columns: 2,
      children: [
        scenario('en light', Brightness.light, en, 1),
        scenario('en dark', Brightness.dark, en, 1),
        scenario('de light 1.3x', Brightness.light, de, 1.3),
        scenario('de dark 1.3x', Brightness.dark, de, 1.3),
      ],
    ),
  );
}
