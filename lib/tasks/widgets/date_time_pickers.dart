import 'package:flutter/material.dart';

import '../../core/time/calendar_date.dart';
import '../../l10n/l10n_ext.dart';

/// Picks a calendar date; null when cancelled.
Future<CalendarDate?> pickCalendarDate(
  BuildContext context, {
  CalendarDate? initial,
}) async {
  final now = DateTime.now();
  final init = initial?.toLocalDateTime() ?? now;
  final low = init.year < now.year ? init.year : now.year;
  final high = init.year > now.year ? init.year : now.year;
  final picked = await showDatePicker(
    context: context,
    initialDate: init,
    firstDate: DateTime(low - 1),
    lastDate: DateTime(high + 10),
  );
  return picked == null ? null : CalendarDate.fromDateTime(picked);
}

/// Picks a time of day; null when cancelled.
Future<LocalTime?> pickLocalTime(
  BuildContext context, {
  LocalTime? initial,
}) async {
  final picked = await showTimePicker(
    context: context,
    initialTime: initial == null
        ? TimeOfDay.now()
        : TimeOfDay(hour: initial.hour, minute: initial.minute),
  );
  return picked == null ? null : LocalTime(picked.hour, picked.minute);
}

/// Picks a date, then a time, and combines them (local fields). Null when
/// either step is cancelled.
Future<DateTime?> pickDateTime(
  BuildContext context, {
  DateTime? initial,
}) async {
  final date = await pickCalendarDate(
    context,
    initial: initial == null ? null : CalendarDate.fromDateTime(initial),
  );
  if (date == null || !context.mounted) return null;
  final time = await pickLocalTime(
    context,
    initial: initial == null ? null : LocalTime(initial.hour, initial.minute),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

/// A tappable form row: icon, label, current value (or "Not set") and a
/// clear button. Wraps instead of clipping at large text sizes.
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
    this.errorText,
  });

  final IconData icon;
  final String label;

  /// Formatted value; null shows "Not set".
  final String? value;
  final VoidCallback onTap;

  /// Shows a clear button when [value] is set and this is non-null.
  final VoidCallback? onClear;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final hasError = errorText != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(
                icon,
                color: hasError
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.labelMedium),
                    Text(
                      value ?? l.taskFormNotSet,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: value == null
                            ? theme.colorScheme.onSurfaceVariant
                            : null,
                      ),
                    ),
                    if (hasError)
                      Text(
                        errorText!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
              if (value != null && onClear != null)
                IconButton(
                  tooltip: l.taskFormClearTooltip,
                  icon: const Icon(Icons.clear),
                  onPressed: onClear,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
