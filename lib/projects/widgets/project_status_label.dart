import '../../l10n/l10n_ext.dart';

/// Localized label for a project status key (`in_progress`, ...).
String projectStatusLabel(AppLocalizations l10n, String status) {
  switch (status) {
    case 'not_started':
      return l10n.projectStatusNotStarted;
    case 'planned':
      return l10n.projectStatusPlanned;
    case 'in_progress':
      return l10n.projectStatusInProgress;
    case 'waiting':
      return l10n.projectStatusWaiting;
    case 'done':
      return l10n.projectStatusDone;
    case 'cancelled':
      return l10n.projectStatusCancelled;
    default:
      return status;
  }
}
