import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/ids.dart';
import 'package:tududa/core/time/calendar_date.dart';
import 'package:tududa/core/time/date_formatters.dart';
import 'package:tududa/l10n/gen/app_localizations_en.dart';
import 'package:tududa/tasks/domain/recurrence/recurrence_rule.dart';
import 'package:tududa/tasks/domain/task.dart';
import 'package:tududa/tasks/widgets/recurrence_editor_sheet.dart';

import '../offline_rig.dart';
import 'detail_support.dart';

void main() {
  initDateData();
  final en = AppLocalizationsEn();
  final fmt = DateFormats(const Locale('en'));

  late OfflineRig rig;
  setUp(() => rig = OfflineRig());

  /// Opens the sheet from a button; the chosen rule lands in [result].
  Future<void> openSheet(
    WidgetTester tester, {
    required RecurrenceRule initial,
    required CalendarDate anchor,
    Locale locale = const Locale('en'),
    double textScale = 1,
    required List<RecurrenceRule?> result,
  }) async {
    await tester.runAsync(rig.init);
    await pumpOffline(
      tester,
      rig,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result.add(
              await showRecurrenceEditorSheet(
                context,
                initial: initial,
                anchor: anchor,
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
    await tester.pumpAndSettle();
  }

  String previewText(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(const Key('recurPreview')),
          matching: find.byType(Text),
        ),
      )
      .map((t) => t.data)
      .join('|');

  detailTest('monthly on the 31st clamps to short months', (tester) async {
    final result = <RecurrenceRule?>[];
    await openSheet(
      tester,
      initial: RecurrenceRule(type: RecurrenceType.monthly, monthDay: 31),
      anchor: const CalendarDate(2027, 1, 31),
      result: result,
    );
    final lines = previewText(tester).split('|');
    expect(lines, hasLength(5));
    expect(lines[0], fmt.fullDate(const CalendarDate(2027, 1, 31)));
    expect(lines[1], fmt.fullDate(const CalendarDate(2027, 2, 28)));
    expect(lines[2], fmt.fullDate(const CalendarDate(2027, 3, 31)));
    expect(lines[3], fmt.fullDate(const CalendarDate(2027, 4, 30)));
    expect(tester.takeException(), isNull);
  });

  detailTest('last weekday of the month', (tester) async {
    final result = <RecurrenceRule?>[];
    await openSheet(
      tester,
      initial: RecurrenceRule(
        type: RecurrenceType.monthlyWeekday,
        weekOfMonth: 5,
        weekday: DateTime.friday,
      ),
      anchor: const CalendarDate(2026, 10, 30),
      result: result,
    );
    final lines = previewText(tester).split('|');
    expect(lines[0], fmt.fullDate(const CalendarDate(2026, 10, 30)));
    expect(lines[1], fmt.fullDate(const CalendarDate(2026, 11, 27)));
    expect(lines[2], fmt.fullDate(const CalendarDate(2026, 12, 25)));
    await tester.tap(find.byKey(const Key('recurApply')));
    await tester.pumpAndSettle();
    final fields = result.single!.toBackendFields();
    expect(fields['recurrence_type'], 'monthly_weekday');
    expect(fields['recurrence_week_of_month'], 5);
    expect(fields['recurrence_weekday'], 5);
  });

  detailTest('weekly chips follow the week start and build the rule', (
    tester,
  ) async {
    final result = <RecurrenceRule?>[];
    await openSheet(
      tester,
      initial: RecurrenceRule.none(),
      // A Monday.
      anchor: const CalendarDate(2026, 10, 19),
      result: result,
    );
    expect(find.byKey(const Key('recurPreview')), findsNothing);
    await tester.tap(find.byKey(const Key('recurType')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.taskRecurWeekly).last);
    await tester.pumpAndSettle();
    // English weeks start on Sunday.
    expect(
      tester.getTopLeft(find.byKey(const Key('recurWeekday-7'))).dx,
      lessThan(tester.getTopLeft(find.byKey(const Key('recurWeekday-1'))).dx),
    );
    await tester.tap(find.byKey(const Key('recurWeekday-3')));
    await tester.tap(find.byKey(const Key('recurIntervalPlus')));
    await tester.tap(find.byKey(const Key('recurCompletion')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recurYearlyNote')), findsOneWidget);
    expect(find.text(en.taskEditRecurYearlyNote), findsOneWidget);

    await tester.tap(find.byKey(const Key('recurApply')));
    await tester.pumpAndSettle();
    final rule = result.single!;
    expect(rule.type, RecurrenceType.weekly);
    expect(rule.interval, 2);
    expect(rule.weekdays, {1, 3});
    expect(rule.completionBased, isTrue);
    final fields = rule.toBackendFields();
    expect(fields['recurrence_weekdays'], [1, 3]);
    expect(fields['completion_based'], true);
  });

  detailTest('weekly chips start on Monday in German', (tester) async {
    final result = <RecurrenceRule?>[];
    await openSheet(
      tester,
      initial: RecurrenceRule(type: RecurrenceType.weekly),
      anchor: const CalendarDate(2026, 10, 19),
      locale: const Locale('de'),
      result: result,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('recurWeekday-1'))).dx,
      lessThan(tester.getTopLeft(find.byKey(const Key('recurWeekday-7'))).dx),
    );
  });

  detailTest('end date and switching to none', (tester) async {
    final result = <RecurrenceRule?>[];
    await openSheet(
      tester,
      initial: RecurrenceRule(type: RecurrenceType.daily),
      anchor: const CalendarDate(2026, 10, 19),
      result: result,
    );
    await tester.tap(find.byKey(const Key('recurEnd')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    // Ends on the anchor: a single occurrence.
    expect(previewText(tester).split('|'), hasLength(1));
    await tester.tap(find.byKey(const Key('recurType')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.quickAddRepeatNone).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recurApply')));
    await tester.pumpAndSettle();
    expect(result.single!.isRecurring, isFalse);
    expect(result.single!.toBackendFields()['recurrence_type'], 'none');
  });

  detailTest('text scale 2.0 does not overflow', (tester) async {
    await openSheet(
      tester,
      initial: RecurrenceRule(
        type: RecurrenceType.monthlyWeekday,
        weekOfMonth: 2,
        weekday: 3,
      ),
      anchor: const CalendarDate(2026, 10, 14),
      textScale: 2,
      result: [],
    );
    expect(tester.takeException(), isNull);
  });

  test('ruleFromTask maps the stored fields', () {
    final rule = ruleFromTask(
      const Task(
        uid: TaskUid('t1'),
        name: 'x',
        recurrenceType: 'weekly',
        recurrenceInterval: 2,
        recurrenceWeekdays: [1, 5],
        completionBased: true,
      ),
    );
    expect(rule.type, RecurrenceType.weekly);
    expect(rule.interval, 2);
    expect(rule.weekdays, {1, 5});
    expect(rule.completionBased, isTrue);
    expect(
      ruleFromTask(const Task(uid: TaskUid('t1'), name: 'y')).isRecurring,
      isFalse,
    );
  });
}
