import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tududa/app.dart';
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/settings/providers/settings_provider.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: const TududiApp(),
      ),
    );
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Unmount first so the engine and drift streams stop,
    await tester.pumpWidget(const SizedBox());
    // Drift schedules a zero-length timer when its streams are cancelled.
    await tester.pump(const Duration(milliseconds: 1));
  });
}
