import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tududa/auth/session/session_providers.dart';
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/sync/sync_engine.dart';
import 'package:tududa/tasks/domain/task.dart';
import 'package:tududa/tasks/domain/task_views.dart';
import 'package:tududa/tasks/providers/task_provider.dart';
import 'package:tududa/tasks/quick_add/inline_add_row.dart';
import 'package:tududa/tasks/quick_add/quick_add_sheet.dart';

import '../../support/pump_app.dart';
import '../offline_rig.dart';

/// Like testWidgets, then unmounts the tree and lets drift's stream cleanup
/// timers run so none is left pending.
void qaTest(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

void main() {
  setUpAll(initializeDateFormatting);

  late OfflineRig rig;

  setUp(() => rig = OfflineRig());

  Future<void> pumpSheet(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    double textScale = 1,
    VoidCallback? onClose,
  }) async {
    await tester.runAsync(rig.init);
    await pumpApp(
      tester,
      locale: locale,
      overrides: [
        appDatabaseProvider.overrideWithValue(rig.db),
        syncEngineProvider.overrideWithValue(rig.engine),
        userClockProvider.overrideWithValue(rig.clock),
      ],
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(body: QuickAddSheet(onClose: onClose)),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('quickAddField')), text);
    await tester.pump();
  }

  Future<List<Task>> allTasks(WidgetTester tester) async {
    // Database work uses timers from the fake clock; keep both moving.
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    return (await tester.runAsync(
      () => rig.dao
          .watchView(TaskView.all, today: rig.today().date, day: rig.today())
          .first,
    ))!;
  }

  group('live chips', () {
    qaTest('en', (tester) async {
      await pumpSheet(tester);
      await type(tester, 'Call Anna tomorrow 5pm !!! #home');
      expect(find.text('Tomorrow'), findsOneWidget);
      expect(find.textContaining('5:00'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
      expect(find.text('home'), findsOneWidget);
    });

    qaTest('de', (tester) async {
      await pumpSheet(tester, locale: const Locale('de'));
      await type(tester, 'Anna anrufen morgen 17:00 !!!');
      expect(find.text('Morgen'), findsOneWidget);
      expect(find.text('17:00'), findsOneWidget);
      expect(find.text('Hoch'), findsOneWidget);
    });

    qaTest('zh', (tester) async {
      await pumpSheet(tester, locale: const Locale('zh'));
      await type(tester, '明天 17:00 买菜 !!!');
      expect(find.text('明天'), findsOneWidget);
      expect(find.text('17:00'), findsOneWidget);
      expect(find.text('高'), findsOneWidget);
    });

    qaTest('recurrence preview and yearly hint', (tester) async {
      await pumpSheet(tester);
      await type(tester, 'Water plants every day');
      expect(find.text('Every day'), findsOneWidget);
      expect(find.byKey(const Key('qaRecurrencePreview')), findsOneWidget);
      await type(tester, 'Birthday every year');
      expect(find.byKey(const Key('qaYearlyHint')), findsOneWidget);
    });
  });

  qaTest('tapping a chip keeps the phrase as plain text', (tester) async {
    await pumpSheet(tester);
    await type(tester, 'Call Anna tomorrow');
    expect(find.byKey(const Key('qaChip-date')), findsOneWidget);
    await tester.tap(find.byKey(const Key('qaChip-date')));
    await tester.pump();
    expect(find.byKey(const Key('qaChip-date')), findsNothing);
    // The text is untouched and the title now includes the phrase.
    expect(find.text('Call Anna tomorrow'), findsOneWidget);
    await tester.tap(find.byKey(const Key('quickAddSubmit')));
    await tester.pump();
    final tasks = await allTasks(tester);
    expect(tasks.single.name, 'Call Anna tomorrow');
    expect(tasks.single.dueDate, isNull);
  });

  qaTest('a manual priority wins over the parsed one', (tester) async {
    await pumpSheet(tester);
    await type(tester, 'Pay rent !!!');
    expect(find.text('High'), findsOneWidget);
    await tester.tap(find.byKey(const Key('qaPick-priority')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Low').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('qaManual-priority')), findsOneWidget);
    expect(find.text('High'), findsNothing);
    await tester.tap(find.byKey(const Key('quickAddSubmit')));
    await tester.pump();
    expect((await allTasks(tester)).single.priority, Priority.low);
  });

  qaTest('save creates the task with the parsed fields', (tester) async {
    var closed = false;
    await pumpSheet(tester, onClose: () => closed = true);
    await type(tester, 'Buy milk tomorrow 5pm !!! #home');
    await tester.tap(find.byKey(const Key('quickAddSubmit')));
    await tester.pump();
    final tasks = await allTasks(tester);
    final t = tasks.single;
    final today = rig.today().date;
    expect(t.name, 'Buy milk');
    expect(t.dueDate, today.addDays(1));
    expect(t.dueTime?.hour, 17);
    expect(t.priority, Priority.high);
    expect(t.tags.map((g) => g.name), ['home']);
    expect(closed, isTrue);
  });

  qaTest('add another clears and stays open', (tester) async {
    var closed = false;
    await pumpSheet(tester, onClose: () => closed = true);
    await tester.tap(find.byKey(const Key('quickAddAnother')));
    await type(tester, 'One');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(closed, isFalse);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('quickAddField')))
          .controller!
          .text,
      isEmpty,
    );
    expect((await allTasks(tester)).single.name, 'One');
  });

  qaTest('text scale 2.0 does not overflow', (tester) async {
    await pumpSheet(tester, textScale: 2);
    await type(tester, 'Call Anna tomorrow 5pm !!! #home every week');
    expect(tester.takeException(), isNull);
  });

  qaTest('InlineAddRow submits with defaults', (tester) async {
    await tester.runAsync(rig.init);
    await pumpApp(
      tester,
      overrides: [
        appDatabaseProvider.overrideWithValue(rig.db),
        syncEngineProvider.overrideWithValue(rig.engine),
        userClockProvider.overrideWithValue(rig.clock),
      ],
      home: Scaffold(
        body: InlineAddRow(defaultDue: rig.today().date.addDays(2)),
      ),
    );
    await tester.enterText(find.byKey(const Key('inlineAddField')), 'Plan !!');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    final t = (await allTasks(tester)).single;
    expect(t.name, 'Plan');
    expect(t.priority, Priority.medium);
    expect(t.dueDate, rig.today().date.addDays(2));
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('inlineAddField')))
          .controller!
          .text,
      isEmpty,
    );
  });
}
