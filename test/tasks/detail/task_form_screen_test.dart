import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/ids.dart';
import 'package:tududa/core/time/calendar_date.dart';
import 'package:tududa/l10n/gen/app_localizations_de.dart';
import 'package:tududa/l10n/gen/app_localizations_en.dart';
import 'package:tududa/l10n/gen/app_localizations_zh.dart';
import 'package:tududa/tasks/domain/new_task.dart';
import 'package:tududa/tasks/domain/recurrence/recurrence_rule.dart';
import 'package:tududa/tasks/domain/task.dart';
import 'package:tududa/tasks/providers/project_options_provider.dart';
import 'package:tududa/tasks/quick_add/quick_add_support.dart';
import 'package:tududa/tasks/screens/task_form_screen.dart';

import '../offline_rig.dart';
import 'detail_support.dart';

void main() {
  initDateData();
  final en = AppLocalizationsEn();

  late OfflineRig rig;
  setUp(() => rig = OfflineRig());

  /// Opens the form on top of a home route (so the back button and the dirty
  /// guard behave as in the app).
  Future<void> openForm(
    WidgetTester tester, {
    String? taskId,
    QuickAddDraft? draft,
    Locale locale = const Locale('en'),
    double textScale = 1,
  }) async {
    await pumpOffline(
      tester,
      rig,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TaskFormScreen(taskId: taskId, draft: draft),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
      locale: locale,
      textScale: textScale,
    );
    await tester.tap(find.text('open'));
    // An edit form shows a spinner until the task has loaded.
    await settle(tester);
    await tester.pumpAndSettle();
  }

  detailTest('name is required', (tester) async {
    await tester.runAsync(rig.init);
    await openForm(tester);
    await tester.tap(find.byKey(const Key('formSave')));
    await tester.pumpAndSettle();
    expect(find.text(en.taskFormNameRequired), findsOneWidget);
    expect(await allTasks(tester, rig), isEmpty);
  });

  detailTest('estimate must be a positive number', (tester) async {
    await tester.runAsync(rig.init);
    await openForm(tester);
    await tester.enterText(find.byKey(const Key('formName')), 'X');
    await tester.enterText(find.byKey(const Key('formEstimate')), '0');
    await tester.tap(find.byKey(const Key('formSave')));
    await tester.pumpAndSettle();
    expect(find.text(en.taskEditEstimateInvalid), findsOneWidget);
    expect(await allTasks(tester, rig), isEmpty);
  });

  detailTest('a draft prefills the form and saves with every field', (
    tester,
  ) async {
    await tester.runAsync(rig.init);
    final draft = QuickAddDraft(
      name: 'Pay rent',
      note: 'Landlord',
      date: const CalendarDate(2027, 1, 31),
      time: const LocalTime(9, 0),
      priority: Priority.high,
      project: const ProjectOption(uid: ProjectUid('p9'), name: 'Home'),
      tags: const ['money'],
      recurrence: RecurrenceRule(type: RecurrenceType.monthly, monthDay: 31),
    );
    await openForm(tester, draft: draft);

    final name = tester.widget<TextFormField>(
      find.byKey(const Key('formName')),
    );
    expect(name.controller!.text, 'Pay rent');
    expect(find.byKey(const Key('formTag-money')), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text(en.quickAddRecurMonthlyOnDay(1, 31)), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('formPriority-high')))
          .selected,
      isTrue,
    );
    expect(find.byKey(const Key('formDueTime')), findsOneWidget);

    await tester.tap(find.byKey(const Key('formSave')));
    await settle(tester);
    await tester.pumpAndSettle();
    // The form closed after saving.
    expect(find.byType(TaskFormScreen), findsNothing);

    final t = (await allTasks(tester, rig)).single;
    expect(t.name, 'Pay rent');
    expect(t.note, 'Landlord');
    expect(t.priority, Priority.high);
    expect(t.dueDate, const CalendarDate(2027, 1, 31));
    expect(t.dueTime, const LocalTime(9, 0));
    expect(t.recurrenceType, 'monthly');
    expect(t.recurrenceMonthDay, 31);
    expect(t.tags.map((x) => x.name), ['money']);
  });

  detailTest('a repeating task needs a due date', (tester) async {
    await tester.runAsync(rig.init);
    final draft = QuickAddDraft(
      name: 'Daily',
      recurrence: RecurrenceRule(type: RecurrenceType.daily),
    );
    await openForm(tester, draft: draft);
    // The draft got today as the start date; clearing it is an error.
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('formDue')),
        matching: find.byIcon(Icons.clear),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('formSave')));
    await tester.pumpAndSettle();
    expect(find.text(en.taskEditRecurNeedsDue), findsOneWidget);
    expect(await allTasks(tester, rig), isEmpty);
  });

  detailTest('dirty guard asks before discarding', (tester) async {
    await tester.runAsync(rig.init);
    await openForm(tester);

    // Untouched: leaves at once.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(TaskFormScreen), findsNothing);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('formName')), 'Draft');
    await tester.pump();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text(en.taskEditDiscardTitle), findsOneWidget);

    await tester.tap(find.byKey(const Key('formKeepEditing')));
    await tester.pumpAndSettle();
    expect(find.byType(TaskFormScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('formDiscard')));
    await tester.pumpAndSettle();
    expect(find.byType(TaskFormScreen), findsNothing);
    expect(await allTasks(tester, rig), isEmpty);
  });

  detailTest('editing sends only what changed', (tester) async {
    final task = (await tester.runAsync(() async {
      await rig.init();
      return rig.repo.create(
        const NewTask(name: 'Old', priority: Priority.low, note: 'keep'),
      );
    }))!;
    await openForm(tester, taskId: task.uid.value);
    await tester.enterText(find.byKey(const Key('formName')), 'New');
    await tester.tap(find.byKey(const Key('formPriority-medium')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('formSave')));
    await settle(tester);
    await tester.pumpAndSettle();
    final t = (await allTasks(tester, rig)).single;
    expect(t.name, 'New');
    expect(t.priority, Priority.medium);
    expect(t.note, 'keep');
  });

  detailTest('editing the repeat rule patches the recurrence fields', (
    tester,
  ) async {
    final task = (await tester.runAsync(() async {
      await rig.init();
      return rig.repo.create(NewTask(name: 'Water', dueDate: rig.today().date));
    }))!;
    await openForm(tester, taskId: task.uid.value);
    await tester.tap(find.byKey(const Key('formRecurrence')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recurType')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.taskRecurDaily).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recurIntervalPlus')));
    await tester.tap(find.byKey(const Key('recurApply')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('formSave')));
    await settle(tester);
    await tester.pumpAndSettle();
    final t = (await allTasks(tester, rig)).single;
    expect(t.recurrenceType, 'daily');
    expect(t.recurrenceInterval, 2);
    expect(t.name, 'Water');
  });

  detailTest('note preview renders Markdown', (tester) async {
    await tester.runAsync(rig.init);
    await openForm(tester);
    await tester.enterText(find.byKey(const Key('formNote')), '**bold**');
    await tester.tap(find.text(en.noteV2ModePreview));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('formNotePreview')), findsOneWidget);
    expect(find.text('bold'), findsOneWidget);
  });

  detailTest('text scale 2.0 does not overflow', (tester) async {
    await tester.runAsync(rig.init);
    await openForm(tester, textScale: 2);
    expect(tester.takeException(), isNull);
  });

  detailTest('de', (tester) async {
    await tester.runAsync(rig.init);
    await openForm(tester, locale: const Locale('de'));
    expect(
      find.text(AppLocalizationsDe().taskEditEstimateLabel),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  detailTest('zh', (tester) async {
    await tester.runAsync(rig.init);
    await openForm(tester, locale: const Locale('zh'));
    expect(
      find.text(AppLocalizationsZh().taskEditEstimateLabel),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
