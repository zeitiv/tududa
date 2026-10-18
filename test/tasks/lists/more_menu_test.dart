import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tududa/l10n/gen/app_localizations.dart';
import 'package:tududa/settings/providers/settings_provider.dart';
import 'package:tududa/settings/screens/settings_screen.dart';
import 'package:tududa/core/design/app_theme.dart';

void main() {
  const links = {
    'Overdue': '/overdue',
    'Someday': '/someday',
    'Completed': '/completed',
    'All tasks': '/tasks',
    'Notes': '/notes',
    'Areas': '/more/areas',
  };

  for (final e in links.entries) {
    testWidgets('${e.key} opens ${e.value}', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final sp = await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: '/more',
        routes: [
          GoRoute(path: '/more', builder: (_, _) => const SettingsScreen()),
          for (final p in links.values.toSet())
            GoRoute(path: p, builder: (_, _) => Text('page $p')),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(sp)],
          child: MaterialApp.router(
            routerConfig: router,
            theme: buildTheme(
              brightness: Brightness.light,
              contrast: ContrastLevel.standard,
              density: DensityLevel.comfortable,
              reduceMotion: true,
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('LISTS & MORE'), findsOneWidget);
      expect(find.text('Tags'), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, e.key).first);
      await tester.pumpAndSettle();
      expect(find.text('page ${e.value}'), findsOneWidget);
    });
  }
}
