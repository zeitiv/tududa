import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/undo/undo_controller.dart';
import '../../core/api/patch.dart' show Patch;
import '../../core/time/calendar_date.dart';
import '../../core/time/date_formatters.dart';
import '../../l10n/l10n_ext.dart';
import '../data/task_patch.dart';
import '../domain/task.dart';
import '../providers/task_provider.dart';

enum _Choice { tomorrow, weekend, nextWeek, pick, someday, skip }

/// The Saturday after [today] (a week ahead when today is Saturday).
CalendarDate thisWeekend(CalendarDate today) {
  final d = (6 - today.weekday) % 7;
  return today.addDays(d == 0 ? 7 : d);
}

/// First day of the week after the one containing [today].
CalendarDate nextWeekStart(CalendarDate today, DateFormats formats) =>
    formats.startOfWeek(today).addDays(7);

/// Asks when to postpone [tasks] to and applies the choice. Shows an undo
/// snackbar afterwards. Recurring single tasks can also skip an occurrence.
Future<void> showPostponeSheet(
  BuildContext context,
  WidgetRef ref,
  List<Task> tasks,
) async {
  if (tasks.isEmpty) return;
  final today = ref.read(taskDayProvider).date;
  final formats = DateFormats(Localizations.localeOf(context));
  final canSkip = tasks.length == 1 && tasks.first.isRecurring;
  final choice = await showModalBottomSheet<_Choice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final l = ctx.l10n;
      Widget option(IconData icon, String label, String? sub, _Choice c) =>
          ListTile(
            minTileHeight: 48,
            leading: Icon(icon),
            title: Text(label),
            trailing: sub == null ? null : Text(sub),
            onTap: () => Navigator.pop(ctx, c),
          );
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l.postponeTitle,
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              option(
                Icons.wb_sunny_outlined,
                l.postponeTomorrow,
                formats.mediumDate(today.addDays(1)),
                _Choice.tomorrow,
              ),
              option(
                Icons.weekend_outlined,
                l.postponeWeekend,
                formats.mediumDate(thisWeekend(today)),
                _Choice.weekend,
              ),
              option(
                Icons.next_week_outlined,
                l.postponeNextWeek,
                formats.mediumDate(nextWeekStart(today, formats)),
                _Choice.nextWeek,
              ),
              option(
                Icons.calendar_month_outlined,
                l.postponePickDate,
                null,
                _Choice.pick,
              ),
              option(
                Icons.inbox_outlined,
                l.postponeSomeday,
                null,
                _Choice.someday,
              ),
              if (canSkip)
                option(
                  Icons.skip_next_outlined,
                  l.postponeSkipOccurrence,
                  null,
                  _Choice.skip,
                ),
            ],
          ),
        ),
      );
    },
  );
  if (choice == null || !context.mounted) return;

  CalendarDate? date;
  switch (choice) {
    case _Choice.tomorrow:
      date = today.addDays(1);
    case _Choice.weekend:
      date = thisWeekend(today);
    case _Choice.nextWeek:
      date = nextWeekStart(today, formats);
    case _Choice.pick:
      final picked = await showDatePicker(
        context: context,
        initialDate: today.addDays(1).toLocalDateTime(),
        firstDate: today.toLocalDateTime(),
        lastDate: today.addDays(365 * 10).toLocalDateTime(),
      );
      if (picked == null || !context.mounted) return;
      date = CalendarDate.fromDateTime(picked);
    case _Choice.someday:
    case _Choice.skip:
      break;
  }

  final actions = ref.read(taskActionsProvider);
  final tokens = <UndoToken>[];
  for (final t in tasks) {
    final TaskResult<Object?> r;
    if (choice == _Choice.skip) {
      r = await actions.skipOccurrence(t.uid);
    } else if (date == null) {
      r = await actions.update(
        t.uid,
        const TaskPatch(dueDate: Patch.clear(), dueTime: Patch.clear()),
      );
    } else {
      r = await actions.postpone(t, date);
    }
    if (r.undo != null) tokens.add(r.undo!);
  }
  if (!context.mounted) return;
  ref
      .read(undoControllerProvider)
      .showAll(context, context.l10n.undoPostponed(tasks.length), tokens);
}
