import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/ids.dart';
import 'package:tududa/core/time/calendar_date.dart';
import 'package:tududa/l10n/gen/app_localizations_de.dart';
import 'package:tududa/l10n/gen/app_localizations_en.dart';
import 'package:tududa/l10n/gen/app_localizations_zh.dart';
import 'package:tududa/tasks/domain/new_task.dart';
import 'package:tududa/tasks/domain/task.dart';
import 'package:tududa/tasks/screens/task_detail_screen.dart';

import '../offline_rig.dart';
import 'detail_support.dart';

void main() {
  initDateData();
  final en = AppLocalizationsEn();

  late OfflineRig rig;
  setUp(() => rig = OfflineRig());

  Future<Task> seedFull(WidgetTester tester) async =>
      (await tester.runAsync(() async {
        await rig.init();
        await rig.db
            .into(rig.db.projects)
            .insert(
              ProjectsCompanion.insert(
                localId: 'p1',
                name: const Value('Garden'),
                localUpdatedAt: Value(rig.t),
              ),
            );
        await rig.db
            .into(rig.db.areas)
            .insert(
              AreasCompanion.insert(
                localId: 'a1',
                name: const Value('Health'),
                localUpdatedAt: Value(rig.t),
              ),
            );
        final today = rig.today().date;
        return rig.repo.create(
          NewTask(
            name: 'Water plants',
            note: 'Use **rain** water',
            priority: Priority.high,
            dueDate: today.addDays(2),
            dueTime: const LocalTime(9, 30),
            deferUntil: DateTime(today.year, today.month, today.day + 1),
            reminderAt: DateTime(today.year, today.month, today.day + 2, 8),
            estimatedMinutes: 90,
            projectUid: const ProjectUid('p1'),
            areaUid: const AreaUid('a1'),
            tags: const ['home', 'green'],
            recurrenceType: 'daily',
            recurrenceInterval: 1,
          ),
        );
      }))!;

  Future<void> pumpDetail(
    WidgetTester tester,
    Task task, {
    Locale locale = const Locale('en'),
    double textScale = 1,
  }) async {
    await pumpOffline(
      tester,
      rig,
      TaskDetailScreen(taskId: task.uid.value),
      locale: locale,
      textScale: textScale,
    );
  }

  detailTest('renders every field', (tester) async {
    final task = await seedFull(tester);
    await pumpDetail(tester, task);
    expect(find.byKey(const Key('detailTitle')), findsOneWidget);
    expect(find.text('Water plants'), findsOneWidget);
    expect(find.byKey(const Key('detailStatus')), findsOneWidget);
    expect(find.text(en.taskStatusNotStarted), findsOneWidget);
    expect(find.text(en.taskPriorityHigh), findsOneWidget);
    expect(find.byKey(const Key('detailDue')), findsOneWidget);
    expect(find.textContaining('9:30'), findsOneWidget);
    expect(find.byKey(const Key('detailDefer')), findsOneWidget);
    expect(find.byKey(const Key('detailReminder')), findsOneWidget);
    expect(find.text(en.todayDurationHm(1, 30)), findsOneWidget);
    expect(find.text('Garden'), findsOneWidget);
    expect(find.text('Health'), findsOneWidget);
    expect(find.text('home'), findsOneWidget);
    expect(find.text('green'), findsOneWidget);
    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.byKey(const Key('detailRecurrence')), findsOneWidget);
    expect(find.text('Every day'), findsOneWidget);
    // Next three occurrences.
    final upcoming = tester.widget<Column>(
      find.byKey(const Key('detailUpcoming')),
    );
    expect(upcoming.children, hasLength(3));
    expect(find.byKey(const Key('detailSkip')), findsOneWidget);
    expect(find.text(en.taskDetailSubtasks), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  detailTest('a subtask under an offline parent persists', (tester) async {
    final parent = (await tester.runAsync(() async {
      await rig.init();
      return rig.repo.create(const NewTask(name: 'Parent'));
    }))!;
    // The parent has never been synced: it only has a local id.
    expect(parent.serverId, isNull);
    await pumpDetail(tester, parent);

    await tester.enterText(
      find.byKey(const Key('subtaskAddField')),
      'Child one',
    );
    await tester.tap(find.byKey(const Key('subtaskAddButton')));
    await settle(tester);
    expect(find.text('Child one'), findsOneWidget);

    final tasks = await allTasks(tester, rig);
    final child = tasks.singleWhere((t) => t.name == 'Child one');
    expect(child.parentLocalId, parent.localId);
    final outbox = await tester.runAsync(rig.outbox);
    expect(outbox, hasLength(2));
  });

  detailTest('completing a subtask inline', (tester) async {
    final parent = (await tester.runAsync(() async {
      await rig.init();
      return rig.repo.create(const NewTask(name: 'Parent'));
    }))!;
    await pumpDetail(tester, parent);
    await tester.enterText(find.byKey(const Key('subtaskAddField')), 'A');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(find.byKey(const Key('subtaskCheck-A')), findsOneWidget);

    await tester.tap(find.byKey(const Key('subtaskCheck-A')));
    await settle(tester);
    final tasks = await allTasks(tester, rig);
    expect(tasks.singleWhere((t) => t.name == 'A').isCompleted, isTrue);
    expect(find.text(en.taskEditSubtaskProgress(1, 1)), findsOneWidget);
    // Undo snackbar.
    expect(find.text(en.undoAction), findsOneWidget);
  });

  detailTest('reorder is local and delete removes the subtask', (tester) async {
    final parent = (await tester.runAsync(() async {
      await rig.init();
      return rig.repo.create(const NewTask(name: 'Parent'));
    }))!;
    await pumpDetail(tester, parent);
    for (final n in ['A', 'B']) {
      await tester.enterText(find.byKey(const Key('subtaskAddField')), n);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
    }
    final handles = find.byIcon(Icons.drag_handle);
    expect(handles, findsNWidgets(2));
    final a = tester.getTopLeft(find.text('A')).dy;
    await tester.drag(handles.first, const Offset(0, 120));
    await settle(tester);
    expect(tester.getTopLeft(find.text('A')).dy, greaterThan(a));

    await tester.tap(find.byKey(const Key('subtaskDelete-A')));
    await settle(tester);
    expect(find.text('A'), findsNothing);
  });

  detailTest('text scale 2.0 does not overflow', (tester) async {
    final task = await seedFull(tester);
    await pumpDetail(tester, task, textScale: 2);
    expect(tester.takeException(), isNull);
    expect(find.text('Water plants'), findsOneWidget);
  });

  detailTest('de', (tester) async {
    final task = await seedFull(tester);
    await pumpDetail(tester, task, locale: const Locale('de'));
    expect(find.text(AppLocalizationsDe().taskPriorityHigh), findsOneWidget);
    expect(find.text(AppLocalizationsDe().taskEditNextOccurrences), findsOne);
    expect(tester.takeException(), isNull);
  });

  detailTest('zh', (tester) async {
    final task = await seedFull(tester);
    await pumpDetail(tester, task, locale: const Locale('zh'));
    expect(find.text(AppLocalizationsZh().taskPriorityHigh), findsOneWidget);
    expect(find.text(AppLocalizationsZh().taskEditNextOccurrences), findsOne);
    expect(tester.takeException(), isNull);
  });
}
