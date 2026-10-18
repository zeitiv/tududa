import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/l10n/gen/app_localizations.dart';
import 'package:tududa/tasks/domain/task.dart';
import 'package:tududa/tasks/screens/task_list_screen.dart';
import 'package:tududa/tasks/screens/today_screen.dart';

import 'a11y_cases.dart';
import 'a11y_support.dart';

/// Gestures are never the only way: a swipe or a drag has to have an
/// equivalent screen-reader action and a visible menu entry.

List<String> _customActions(WidgetTester tester, Finder f) {
  final data = tester.getSemantics(f).getSemanticsData();
  return [
    for (final id in data.customSemanticsActionIds ?? const <int>[])
      CustomSemanticsAction.getAction(id)!.label!,
  ];
}

/// Runs the custom accessibility action [label] of the node found by [f].
void _perform(WidgetTester tester, Pattern nodeLabel, String label) {
  final f = find.semantics.byLabel(nodeLabel);
  final node = tester.getSemantics(find.bySemanticsLabel(nodeLabel));
  final id = node.getSemanticsData().customSemanticsActionIds!.firstWhere(
    (id) => CustomSemanticsAction.getAction(id)!.label == label,
  );
  tester.semantics.performAction(f, SemanticsAction.customAction, args: id);
}

void main() {
  for (final locale in a11yLocales) {
    final lang = locale.languageCode;

    a11yTest(
      'task tile: every swipe action has an accessibility action $lang',
      (tester, rig, data) async {
        await pumpA11y(tester, rig, home: const TodayScreen(), locale: locale);
        final l = lookupAppLocalizations(locale);
        final tile = find.bySemanticsLabel(RegExp('^Pay rent'));
        final labels = _customActions(tester, tile);
        // Swipe from the start edge: complete. From the end edge: postpone and
        // priority. Plus the rest of the menu.
        expect(
          labels,
          containsAll([
            l.tileComplete,
            l.postponeTitle,
            l.bulkPriority,
            l.taskDelete,
            l.tileEdit,
          ]),
        );
      },
    );

    a11yTest('task tile: the overflow menu offers the swipe actions $lang', (
      tester,
      rig,
      data,
    ) async {
      await pumpA11y(
        tester,
        rig,
        home: const TaskListScreen(view: TaskListView.upcoming),
        locale: locale,
      );
      final l = lookupAppLocalizations(locale);
      await tester.tap(find.byTooltip(l.tileMenu).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      for (final entry in [
        l.tileComplete,
        l.postponeTitle,
        l.bulkPriority,
        l.taskDelete,
      ]) {
        expect(find.text(entry), findsWidgets, reason: 'menu: $entry');
      }
    });
  }

  a11yTest('task tile: the complete action works without a gesture', (
    tester,
    rig,
    data,
  ) async {
    await pumpA11y(tester, rig, home: const TodayScreen());
    _perform(tester, RegExp('^Pay rent'), 'Complete');
    await settleA11y(tester);
    final row = await tester.runAsync(() => rig.row(data.task.uid.value));
    expect(row!.status, TaskStatus.done.code);
  });

  a11yTest('today: the long-press palette gesture has an action', (
    tester,
    rig,
    data,
  ) async {
    await pumpA11y(tester, rig, home: const TodayScreen());
    final search = find.byTooltip('Search');
    expect(search, findsOneWidget);
    // The custom action sits on the wrapper above the button.
    final wrapper = find.ancestor(
      of: search,
      matching: find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.customSemanticsActions != null,
      ),
    );
    expect(wrapper, findsOneWidget);
    final labels = [
      for (final a in (tester.widget<Semantics>(
        wrapper,
      )).properties.customSemanticsActions!.keys)
        a.label!,
    ];
    expect(labels, ['Command palette']);
  });

  a11yTest('inbox: swipe to process or delete is in the item menu', (
    tester,
    rig,
    data,
  ) async {
    final c = a11yCases.firstWhere((c) => c.name == 'inbox');
    await pumpCase(tester, rig, data, c);
    await tester.tap(find.byTooltip('More actions').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Mark as Processed'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  a11yTest('kanban: dragging a card has a move action per other column', (
    tester,
    rig,
    data,
  ) async {
    final c = a11yCases.firstWhere((c) => c.name == 'all_tasks_kanban');
    await pumpCase(tester, rig, data, c);
    final card = find
        .byWidgetPredicate(
          (w) =>
              w is Semantics &&
              (w.properties.customSemanticsActions?.keys.any(
                    (a) => a.label?.startsWith('Move to') ?? false,
                  ) ??
                  false),
        )
        .first;
    final labels = _customActions(tester, card);
    expect(labels.length, greaterThanOrEqualTo(3));
    expect(labels, everyElement(startsWith('Move to')));
    // The visible menu offers the same move.
    await tester.tap(find.byTooltip('Move to…').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Move to…'), findsWidgets);
  });
}
