import 'dart:io';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tududa/data/prefs.dart';
import 'package:tududa/data/tududi.dart';
import 'package:tududa/main.dart';
import 'package:tududa/os/kit/controls.dart';
import 'package:tududa/os/os.dart';
import 'package:tududa/os/apps/tasks.dart';

/// The app's own typefaces, so text measures in tests as it does on screen.
Future<void> loadFonts() async {
  for (final (family, file) in [('Archivo', 'Archivo.ttf'), ('JetBrainsMono', 'JetBrainsMono.ttf')]) {
    final bytes = File('assets/fonts/$file').readAsBytesSync();
    final loader = FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }
}

Future<ProviderContainer> boot(WidgetTester tester, Size size) async {
  await tester.runAsync(loadFonts);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'demo_mode': true, 'app_locale': 'en'});
  await initializeDateFormatting();
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const TududaApp()),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 2));
  await tester.pump(const Duration(seconds: 2));
  return container;
}

/// Lets springs and timers run without waiting on the status lamps, which
/// pulse for as long as a link is live.
Future<void> settle(WidgetTester tester, [int ms = 2400]) async {
  for (var t = 0; t < ms; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  for (final (name, size) in [('phone', const Size(390, 844)), ('desktop', const Size(1440, 900))]) {
    testWidgets('$name: the wall shows the demo and lays out without overflow', (tester) async {
      final c = await boot(tester, size);
      expect(find.textContaining('Alex'), findsOneWidget);
      expect(find.text('Send the Q4 invoice to Lena'), findsOneWidget);
      expect(c.read(tasksProvider).todayTasks.length, 4);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('$name: every app opens and closes', (tester) async {
      final c = await boot(tester, size);
      final os = c.read(osProvider.notifier);
      for (final app in AppId.values) {
        os.open(app);
        await settle(tester, 1200);
        expect(c.read(osProvider).isOpen(app), isTrue);
      }
      os.home();
      await settle(tester);
      expect(c.read(osProvider).wins, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('$name: checking a task completes it and can be undone', (tester) async {
      final c = await boot(tester, size);
      c.read(osProvider.notifier).open(AppId.tasks);
      await settle(tester, 1500);
      final row = find.widgetWithText(TaskRow, 'Book the dentist').last;
      final check = find.descendant(of: row, matching: find.byType(Check));
      if (name == 'desktop') {
        // A mouse: it arrives, hovers, then clicks.
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        addTearDown(mouse.removePointer);
        await mouse.moveTo(tester.getCenter(check));
        await tester.pump(const Duration(milliseconds: 16));
        await mouse.down(tester.getCenter(check));
        await mouse.up();
      } else {
        await tester.tap(check);
      }
      await settle(tester, 1500);
      expect(c.read(tasksProvider).open.any((t) => t.name == 'Book the dentist'), isFalse);
      expect(c.read(tasksProvider).done.first.name, 'Book the dentist');
      c.read(osProvider).toast!.onAction!();
      await settle(tester, 600);
      expect(c.read(tasksProvider).open.first.name, 'Book the dentist');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });
  }
}
