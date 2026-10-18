import '../../l10n/gen/app_localizations.dart';
import 'task.dart';

/// Localized display name of a task status.
String taskStatusLabel(AppLocalizations l, TaskStatus s) => switch (s) {
  TaskStatus.notStarted => l.taskStatusNotStarted,
  TaskStatus.inProgress => l.taskStatusInProgress,
  TaskStatus.done => l.taskStatusDone,
  TaskStatus.archived => l.taskStatusArchived,
  TaskStatus.waiting => l.taskStatusWaiting,
  TaskStatus.cancelled => l.taskStatusCancelled,
  TaskStatus.planned => l.taskStatusPlanned,
  TaskStatus.unknown => l.taskStatusUnknown,
};

/// Localized display name of a task priority.
String taskPriorityLabel(AppLocalizations l, Priority p) => switch (p) {
  Priority.low => l.taskPriorityLow,
  Priority.medium => l.taskPriorityMedium,
  Priority.high => l.taskPriorityHigh,
};
