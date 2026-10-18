import 'package:flutter/material.dart';

import '../../core/time/date_formatters.dart';
import '../../l10n/l10n_ext.dart';
import '../domain/recurrence/recurrence_rule.dart';

/// A small recurrence editor (type, interval, weekdays, completion based).
/// Resolves to the edited rule, or null when cancelled.
Future<RecurrenceRule?> showRecurrenceEditor(
  BuildContext context, {
  RecurrenceRule? initial,
}) => showDialog<RecurrenceRule>(
  context: context,
  builder: (_) => _RecurrenceDialog(initial: initial ?? RecurrenceRule.none()),
);

class _RecurrenceDialog extends StatefulWidget {
  const _RecurrenceDialog({required this.initial});
  final RecurrenceRule initial;

  @override
  State<_RecurrenceDialog> createState() => _RecurrenceDialogState();
}

class _RecurrenceDialogState extends State<_RecurrenceDialog> {
  late RecurrenceRule _rule = widget.initial;

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

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = DateFormats(Localizations.localeOf(context));
    final types = [
      RecurrenceType.none,
      RecurrenceType.daily,
      RecurrenceType.weekly,
      RecurrenceType.monthly,
      RecurrenceType.monthlyLastDay,
      // A rule parsed from text may already be month-weekday based.
      if (widget.initial.type == RecurrenceType.monthlyWeekday)
        RecurrenceType.monthlyWeekday,
    ];
    return AlertDialog(
      title: Text(l.quickAddPickRepeat),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButton<RecurrenceType>(
              isExpanded: true,
              value: _rule.type,
              items: [
                for (final t in types)
                  DropdownMenuItem(value: t, child: Text(_typeLabel(t))),
              ],
              onChanged: (t) => setState(() => _rule = _rule.copyWith(type: t)),
            ),
            if (_rule.isRecurring &&
                _rule.type != RecurrenceType.monthlyLastDay)
              Row(
                children: [
                  Flexible(child: Text(l.taskFormEvery)),
                  IconButton(
                    onPressed: _rule.interval > 1
                        ? () => setState(
                            () => _rule = _rule.copyWith(
                              interval: _rule.interval - 1,
                            ),
                          )
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Text(f.number(_rule.interval)),
                  IconButton(
                    onPressed: () => setState(
                      () =>
                          _rule = _rule.copyWith(interval: _rule.interval + 1),
                    ),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            if (_rule.type == RecurrenceType.weekly)
              Wrap(
                spacing: 6,
                children: [
                  for (var i = 0; i < 7; i++)
                    FilterChip(
                      label: Text(
                        f.weekdayName(((f.weekStart - 1 + i) % 7) + 1),
                      ),
                      selected: _rule.weekdays.contains(
                        ((f.weekStart - 1 + i) % 7) + 1,
                      ),
                      onSelected: (on) {
                        final wd = ((f.weekStart - 1 + i) % 7) + 1;
                        setState(
                          () => _rule = _rule.copyWith(
                            weekdays: {
                              for (final d in _rule.weekdays)
                                if (d != wd) d,
                              if (on) wd,
                            },
                          ),
                        );
                      },
                    ),
                ],
              ),
            if (_rule.isRecurring)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.taskFormCompletionBased),
                value: _rule.completionBased,
                onChanged: (v) =>
                    setState(() => _rule = _rule.copyWith(completionBased: v)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.taskCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _rule),
          child: Text(l.quickAddApply),
        ),
      ],
    );
  }
}
