import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../core/time/calendar_date.dart';
import '../../core/time/date_formatters.dart';
import '../../l10n/l10n_ext.dart';
import '../domain/recurrence/describe.dart';
import '../domain/recurrence/recurrence_rule.dart';
import '../domain/task.dart';
import '../quick_add/recurrence_text.dart';
import 'date_time_pickers.dart';

/// Opens the full recurrence editor. Resolves to the edited rule (which may be
/// [RecurrenceRule.none]), or null when dismissed.
///
/// [anchor] is the date the series starts from (the due date, or today); it
/// seeds the defaults and the live preview.
Future<RecurrenceRule?> showRecurrenceEditorSheet(
  BuildContext context, {
  required RecurrenceRule initial,
  required CalendarDate anchor,
}) => showModalBottomSheet<RecurrenceRule>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => RecurrenceEditorSheet(initial: initial, anchor: anchor),
);

/// The recurrence rule stored on [task] ([RecurrenceRule.none] when it does
/// not repeat).
RecurrenceRule ruleFromTask(Task task) {
  final type = RecurrenceType.fromBackend(task.recurrenceType);
  if (type == RecurrenceType.none) return RecurrenceRule.none();
  return RecurrenceRule(
    type: type,
    interval: (task.recurrenceInterval ?? 1) < 1
        ? 1
        : task.recurrenceInterval ?? 1,
    weekdays: {
      for (final d in task.recurrenceWeekdays ?? const <int>[])
        if (d >= 1 && d <= 7) d,
    },
    monthDay: _inRange(task.recurrenceMonthDay, 1, 31),
    weekOfMonth: _inRange(task.recurrenceWeekOfMonth, 1, 5),
    weekday: _inRange(task.recurrenceWeekday, 1, 7),
    endDate: task.recurrenceEndDate,
    completionBased: task.completionBased,
  );
}

int? _inRange(int? v, int lo, int hi) =>
    v != null && v >= lo && v <= hi ? v : null;

/// Number of dates in the live preview.
const int recurrencePreviewCount = 5;

/// Editor for a [RecurrenceRule]: none / daily / weekly (weekday chips) /
/// monthly on a day / monthly on the nth weekday (incl. last) / monthly on the
/// last day, with interval, end date and completion-based repeat. Pops the
/// rule on Apply.
class RecurrenceEditorSheet extends StatefulWidget {
  const RecurrenceEditorSheet({
    super.key,
    required this.initial,
    required this.anchor,
    this.weekStart,
  });

  final RecurrenceRule initial;
  final CalendarDate anchor;

  /// ISO weekday the week chips start on; defaults to the locale's.
  final int? weekStart;

  @override
  State<RecurrenceEditorSheet> createState() => _RecurrenceEditorSheetState();
}

class _RecurrenceEditorSheetState extends State<RecurrenceEditorSheet> {
  late RecurrenceRule _rule = _seed(widget.initial.type, widget.initial);

  int get _anchorNth => ((widget.anchor.day - 1) ~/ 7 + 1).clamp(1, 4);

  /// [rule] with [type] and the defaults that type needs filled in from the
  /// anchor date.
  RecurrenceRule _seed(RecurrenceType type, RecurrenceRule rule) {
    var r = rule.copyWith(type: type);
    switch (type) {
      case RecurrenceType.weekly:
        if (r.weekdays.isEmpty) {
          r = r.copyWith(weekdays: {widget.anchor.weekday});
        }
      case RecurrenceType.monthly:
        r = r.copyWith(monthDay: r.monthDay ?? widget.anchor.day);
      case RecurrenceType.monthlyWeekday:
        r = r.copyWith(
          weekOfMonth: r.weekOfMonth ?? _anchorNth,
          weekday: r.weekday ?? widget.anchor.weekday,
        );
      case RecurrenceType.none:
      case RecurrenceType.daily:
      case RecurrenceType.monthlyLastDay:
        break;
    }
    return r;
  }

  void _set(RecurrenceRule r) => setState(() => _rule = r);

  String _typeLabel(RecurrenceType t) {
    final l = context.l10n;
    return switch (t) {
      RecurrenceType.none => l.quickAddRepeatNone,
      RecurrenceType.daily => l.taskRecurDaily,
      RecurrenceType.weekly => l.taskRecurWeekly,
      RecurrenceType.monthly => l.taskRecurMonthly,
      RecurrenceType.monthlyWeekday => l.taskRecurMonthlyWeekday,
      RecurrenceType.monthlyLastDay => l.taskRecurMonthlyLastDay,
    };
  }

  String _unitLabel() {
    final l = context.l10n;
    return switch (_rule.type) {
      RecurrenceType.daily => l.taskFormUnitDays(_rule.interval),
      RecurrenceType.weekly => l.taskFormUnitWeeks(_rule.interval),
      _ => l.taskFormUnitMonths(_rule.interval),
    };
  }

  String _ordinal(int n) {
    final l = context.l10n;
    return switch (n) {
      1 => l.taskEditRecurFirst,
      2 => l.taskEditRecurSecond,
      3 => l.taskEditRecurThird,
      4 => l.taskEditRecurFourth,
      _ => l.taskEditRecurLast,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final f = DateFormats(Localizations.localeOf(context));
    final weekStart = widget.weekStart ?? f.weekStart;
    final recurring = _rule.isRecurring;
    final dates = previewOccurrences(
      _rule,
      widget.anchor,
      recurrencePreviewCount,
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          t.space4,
          0,
          t.space4,
          t.space4 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.taskEditRecurTitle, style: theme.textTheme.titleMedium),
            SizedBox(height: t.space3),
            DropdownButtonFormField<RecurrenceType>(
              key: const Key('recurType'),
              initialValue: _rule.type,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l.taskEditRecurType,
                prefixIcon: const Icon(Icons.repeat),
              ),
              items: [
                for (final type in RecurrenceType.values)
                  DropdownMenuItem(value: type, child: Text(_typeLabel(type))),
              ],
              onChanged: (type) {
                if (type != null) _set(_seed(type, _rule));
              },
            ),
            if (recurring) ...[
              SizedBox(height: t.space3),
              Row(
                children: [
                  Text(l.taskFormEvery),
                  IconButton(
                    key: const Key('recurIntervalMinus'),
                    onPressed: _rule.interval > 1
                        ? () =>
                              _set(_rule.copyWith(interval: _rule.interval - 1))
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Text(
                    f.number(_rule.interval),
                    key: const Key('recurInterval'),
                    style: theme.textTheme.titleMedium,
                  ),
                  IconButton(
                    key: const Key('recurIntervalPlus'),
                    onPressed: () =>
                        _set(_rule.copyWith(interval: _rule.interval + 1)),
                    icon: const Icon(Icons.add),
                  ),
                  Flexible(child: Text(_unitLabel())),
                ],
              ),
            ],
            if (_rule.type == RecurrenceType.weekly) ...[
              SizedBox(height: t.space2),
              Wrap(
                spacing: t.space2,
                children: [
                  for (var i = 0; i < 7; i++)
                    _weekdayChip(f, ((weekStart - 1 + i) % 7) + 1),
                ],
              ),
            ],
            if (_rule.type == RecurrenceType.monthly) ...[
              SizedBox(height: t.space3),
              DropdownButtonFormField<int>(
                key: const Key('recurMonthDay'),
                initialValue: _rule.monthDay,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l.taskEditRecurDayOfMonth,
                ),
                items: [
                  for (var d = 1; d <= 31; d++)
                    DropdownMenuItem(value: d, child: Text(f.number(d))),
                ],
                onChanged: (d) {
                  if (d != null) _set(_rule.copyWith(monthDay: d));
                },
              ),
            ],
            if (_rule.type == RecurrenceType.monthlyWeekday) ...[
              SizedBox(height: t.space3),
              DropdownButtonFormField<int>(
                key: const Key('recurNth'),
                initialValue: _rule.weekOfMonth,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.taskEditRecurOrdinal),
                items: [
                  for (var n = 1; n <= 5; n++)
                    DropdownMenuItem(value: n, child: Text(_ordinal(n))),
                ],
                onChanged: (n) {
                  if (n != null) _set(_rule.copyWith(weekOfMonth: n));
                },
              ),
              SizedBox(height: t.space3),
              DropdownButtonFormField<int>(
                key: const Key('recurWeekdayPicker'),
                initialValue: _rule.weekday,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l.taskEditRecurWeekdayLabel,
                ),
                items: [
                  for (var i = 0; i < 7; i++)
                    DropdownMenuItem(
                      value: ((weekStart - 1 + i) % 7) + 1,
                      child: Text(
                        f.weekdayName(
                          ((weekStart - 1 + i) % 7) + 1,
                          style: WeekdayStyle.long,
                        ),
                      ),
                    ),
                ],
                onChanged: (d) {
                  if (d != null) _set(_rule.copyWith(weekday: d));
                },
              ),
            ],
            if (recurring) ...[
              SizedBox(height: t.space2),
              PickerField(
                key: const Key('recurEnd'),
                icon: Icons.event_busy_outlined,
                label: l.taskEditRecurEndDate,
                value: _rule.endDate == null
                    ? l.taskEditRecurNoEnd
                    : f.fullDate(_rule.endDate!),
                onTap: () async {
                  final d = await pickCalendarDate(
                    context,
                    initial: _rule.endDate ?? widget.anchor,
                  );
                  if (d != null) _set(_rule.copyWith(endDate: d));
                },
                onClear: _rule.endDate == null
                    ? null
                    : () => _set(_rule.copyWith(clearEndDate: true)),
              ),
              SwitchListTile(
                key: const Key('recurCompletion'),
                contentPadding: EdgeInsets.zero,
                title: Text(l.taskFormCompletionBased),
                subtitle: Text(l.taskFormCompletionBasedHint),
                value: _rule.completionBased,
                onChanged: (v) => _set(_rule.copyWith(completionBased: v)),
              ),
              const Divider(),
              Text(
                recurrenceSummary(l, f, _rule),
                key: const Key('recurSummary'),
                style: theme.textTheme.titleSmall,
              ),
              SizedBox(height: t.space1),
              Text(
                l.taskEditRecurPreview,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: t.space1),
              Column(
                key: const Key('recurPreview'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (dates.isEmpty)
                    Text(l.taskEditRecurPreviewEmpty)
                  else
                    for (final d in dates) Text(f.fullDate(d)),
                ],
              ),
            ],
            SizedBox(height: t.space3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                SizedBox(width: t.space2),
                Expanded(
                  child: Text(
                    l.taskEditRecurYearlyNote,
                    key: const Key('recurYearlyNote'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: t.space4),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: t.space2,
              runSpacing: t.space2,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l.taskCancel),
                ),
                FilledButton(
                  key: const Key('recurApply'),
                  onPressed: () => Navigator.pop(context, _rule),
                  child: Text(l.quickAddApply),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _weekdayChip(DateFormats f, int wd) => FilterChip(
    key: Key('recurWeekday-$wd'),
    label: Text(f.weekdayName(wd)),
    selected: _rule.weekdays.contains(wd),
    onSelected: (on) => _set(
      _rule.copyWith(
        weekdays: {
          for (final d in _rule.weekdays)
            if (d != wd) d,
          if (on) wd,
        },
      ),
    ),
  );
}
