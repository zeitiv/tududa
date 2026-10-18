import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tududa/settings/providers/settings_provider.dart';

/// Pumps [home] inside a ProviderScope + MaterialApp with mocked prefs.
Future<void> pumpApp(
  WidgetTester tester, {
  Widget? home,
  List<Override> overrides = const [],
  Locale? locale,
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        ...overrides,
      ],
      child: MaterialApp(
        locale: locale,
        home: home ?? const Scaffold(body: SizedBox()),
      ),
    ),
  );
}

/// Builds a ProviderContainer with mocked prefs; disposed on test teardown.
Future<ProviderContainer> makeContainer({
  List<Override> overrides = const [],
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(sp), ...overrides],
  );
  addTearDown(c.dispose);
  return c;
}
