// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Tududa';

  @override
  String get areaAddTooltip => 'New Area';

  @override
  String get areaCancel => 'Cancel';

  @override
  String get areaCreate => 'Create';

  @override
  String get areaDeleteAction => 'Delete';

  @override
  String get areaDeleteMessage => 'Projects in this area will be unlinked.';

  @override
  String get areaDeleteTitle => 'Delete Area';

  @override
  String get areaDescription => 'Description';

  @override
  String get areaDescriptionOptional => 'Description (optional)';

  @override
  String get areaEdit => 'Edit Area';

  @override
  String get areaEditAction => 'Edit';

  @override
  String areaLoadError(String error) {
    return 'Error: $error';
  }

  @override
  String get areaName => 'Name';

  @override
  String get areaNameHint => 'e.g. Work, Personal, Health';

  @override
  String get areaNew => 'New Area';

  @override
  String get areaSave => 'Save';

  @override
  String get areasEmpty => 'No areas yet';

  @override
  String get areasEmptyHint => 'Areas help organize your projects';

  @override
  String get areasTitle => 'Areas';

  @override
  String get authCancel => 'Cancel';

  @override
  String get authChangeServer => 'Change Server';

  @override
  String get authConnect => 'Connect';

  @override
  String get authConnectPrompt => 'Connect to your self-hosted Tududa server';

  @override
  String get authConnecting => 'Connecting...';

  @override
  String get authEmail => 'Email';

  @override
  String get authEmailRequired => 'Email is required';

  @override
  String get authErrorEmailNotVerified =>
      'Your email address is not verified yet. Check your inbox for the verification link.';

  @override
  String get authErrorEnterServerUrl => 'Enter a server address';

  @override
  String get authErrorGeneric => 'Something went wrong.';

  @override
  String get authErrorInsecure => 'Plain HTTP connections are not encrypted.';

  @override
  String get authErrorInvalidCredentials => 'Incorrect email or password.';

  @override
  String get authErrorInvalidServerUrl => 'That is not a valid address';

  @override
  String get authErrorNetwork =>
      'Could not reach the server. Check your connection and the server address.';

  @override
  String get authErrorPasswordLoginDisabled =>
      'Password sign-in is disabled for this account. It uses single sign-on (SSO), which this app does not support yet.';

  @override
  String get authErrorRateLimited => 'Too many attempts. Try again later.';

  @override
  String authErrorRateLimitedMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return 'Too many attempts. Try again in $_temp0.';
  }

  @override
  String authErrorServer(String code) {
    return 'The server had a problem ($code). Try again later.';
  }

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get authInsecureBody =>
      'This address does not use HTTPS. Your password and tasks would be sent without encryption and could be read on the network. Only continue on a network you trust.';

  @override
  String get authInsecureConfirm => 'Use insecure HTTP';

  @override
  String get authInsecureTitle => 'Use insecure HTTP?';

  @override
  String get authInvalidEmail => 'Invalid email';

  @override
  String get authPassword => 'Password';

  @override
  String get authPasswordRequired => 'Password is required';

  @override
  String get authServerUrl => 'Server URL';

  @override
  String get authServerUrlHelper => 'Enter your Tududa server address';

  @override
  String get authServerUrlRequired => 'Please enter a server URL';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authSignIn => 'Sign In';

  @override
  String get authWelcome => 'Welcome to Tududa';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonError => 'Something went wrong';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonNone => 'None';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonSave => 'Save';

  @override
  String get commonSearch => 'Search';

  @override
  String coreDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String coreInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count days',
      one: 'in 1 day',
    );
    return '$_temp0';
  }

  @override
  String get coreToday => 'Today';

  @override
  String get coreTomorrow => 'Tomorrow';

  @override
  String get coreYesterday => 'Yesterday';

  @override
  String get inboxEmpty => 'Inbox is empty';

  @override
  String get inboxIgnore => 'Ignore';

  @override
  String get inboxMarkProcessed => 'Mark as Processed';

  @override
  String get inboxTelegramHint => 'Items from Telegram will appear here';

  @override
  String get kanbanNoTasks => 'No tasks found.\nTap + to create one.';

  @override
  String get kanbanStatusArchived => 'Archived';

  @override
  String get kanbanStatusCancelled => 'Cancelled';

  @override
  String get kanbanStatusDone => 'Done';

  @override
  String get kanbanStatusInProgress => 'In Progress';

  @override
  String get kanbanStatusOther => 'Other';

  @override
  String get kanbanStatusPlanned => 'Planned';

  @override
  String get kanbanStatusToDo => 'To Do';

  @override
  String get kanbanStatusWaiting => 'Waiting';

  @override
  String get navInbox => 'Inbox';

  @override
  String get navMore => 'More';

  @override
  String get navNotes => 'Notes';

  @override
  String get navProjects => 'Projects';

  @override
  String get navTasks => 'Tasks';

  @override
  String get noteColor => 'Color';

  @override
  String get noteContentHint => 'Jot down your thoughts (Markdown supported)';

  @override
  String get noteDeleteConfirm => 'Are you sure?';

  @override
  String get noteDeleteTitle => 'Delete Note';

  @override
  String get noteEdit => 'Edit Note';

  @override
  String get noteEmpty => 'No notes yet.\nTap + to create one.';

  @override
  String get noteNew => 'New Note';

  @override
  String get noteProject => 'Project';

  @override
  String get noteSaveFailed => 'Failed to save note';

  @override
  String get noteTitleHint => 'Note Title';

  @override
  String get projectAddTask => 'Add Task';

  @override
  String get projectArea => 'Area';

  @override
  String projectAreaLabel(String name) {
    return 'Area: $name';
  }

  @override
  String get projectCancel => 'Cancel';

  @override
  String get projectDelete => 'Delete';

  @override
  String get projectDeleteMessage =>
      'This will delete the project and all its tasks.';

  @override
  String get projectDeleteTitle => 'Delete Project';

  @override
  String get projectDescription => 'Description';

  @override
  String get projectEdit => 'Edit Project';

  @override
  String projectLoadError(String error) {
    return 'Error: $error';
  }

  @override
  String get projectName => 'Project Name';

  @override
  String get projectNameHint => 'Max 6 words';

  @override
  String get projectNameRequired => 'Name is required';

  @override
  String get projectNew => 'New Project';

  @override
  String get projectNoArea => 'No Area';

  @override
  String get projectNotFound => 'Project not found';

  @override
  String get projectPinSidebar => 'Pin to Sidebar';

  @override
  String get projectPinSidebarHint => 'Quick access from navigation';

  @override
  String get projectPriority => 'Priority';

  @override
  String get projectPriorityHigh => 'High';

  @override
  String get projectPriorityLow => 'Low';

  @override
  String get projectPriorityMedium => 'Medium';

  @override
  String get projectPriorityNone => 'None';

  @override
  String get projectRetry => 'Retry';

  @override
  String get projectSave => 'Save';

  @override
  String projectSaveFailed(String error) {
    return 'Failed to save project: $error';
  }

  @override
  String get projectStatus => 'Status';

  @override
  String get projectStatusCancelled => 'Cancelled';

  @override
  String get projectStatusDone => 'Done';

  @override
  String get projectStatusInProgress => 'In Progress';

  @override
  String get projectStatusNotStarted => 'Not Started';

  @override
  String get projectStatusPlanned => 'Planned';

  @override
  String get projectStatusWaiting => 'Waiting';

  @override
  String projectTaskProgress(int done, int total) {
    return '$done/$total tasks';
  }

  @override
  String get projectTasksHeading => 'Project Tasks';

  @override
  String get projectViewBoard => 'Board';

  @override
  String get projectViewList => 'List';

  @override
  String get projectsEmpty => 'No projects yet.\nTap + to create one.';

  @override
  String get projectsTitle => 'Projects';

  @override
  String get settingsAbout => 'About Tududa';

  @override
  String get settingsAboutSubtitle => 'v1.0.1 • Open Source';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsAreas => 'Areas';

  @override
  String get settingsAreasDesc => 'Organize projects into areas';

  @override
  String get settingsCancel => 'Cancel';

  @override
  String get settingsContrast => 'Contrast';

  @override
  String get settingsContrastHigh => 'High';

  @override
  String get settingsContrastMedium => 'Medium';

  @override
  String get settingsContrastStandard => 'Standard';

  @override
  String get settingsDensity => 'Density';

  @override
  String get settingsDensityComfortable => 'Comfortable';

  @override
  String get settingsDensityCompact => 'Compact';

  @override
  String get settingsDynamicColor => 'Dynamic color';

  @override
  String get settingsDynamicColorHint =>
      'Use colors from your wallpaper when available';

  @override
  String get settingsIntegrations => 'Integrations';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String get settingsMore => 'More';

  @override
  String get settingsNavigation => 'Navigation';

  @override
  String get settingsPreferences => 'Preferences';

  @override
  String get settingsReduceMotion => 'Reduce motion';

  @override
  String get settingsReduceMotionHint => 'Turn off transitions and animations';

  @override
  String get settingsServer => 'Server';

  @override
  String get settingsServerNotConfigured => 'Not configured';

  @override
  String get settingsServerUrl => 'Server URL';

  @override
  String get settingsSignOut => 'Sign Out';

  @override
  String get settingsSignOutConfirm => 'Are you sure you want to sign out?';

  @override
  String settingsSignOutUnsynced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes have',
      one: '1 change has',
    );
    return '$_temp0 not synced yet and will be lost.';
  }

  @override
  String get settingsTelegramConnected => 'Connected';

  @override
  String get settingsTelegramNotConfigured => 'Not configured';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsTimezone => 'Timezone';

  @override
  String get syncCancel => 'Cancel';

  @override
  String get syncDiscard => 'Discard';

  @override
  String get syncDiscardBody =>
      'The change will be undone on this device and never sent to the server.';

  @override
  String get syncDiscardTitle => 'Discard this change?';

  @override
  String get syncDismiss => 'Dismiss';

  @override
  String get syncEntryFailed => 'Failed, will retry';

  @override
  String syncEntryLine(String state, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attempts',
      one: '1 attempt',
    );
    return '$state - $_temp0';
  }

  @override
  String get syncEntryPending => 'Pending';

  @override
  String get syncEntrySending => 'Sending';

  @override
  String get syncEntryStuck => 'Stuck';

  @override
  String syncLastSynced(String when) {
    return 'Last synced $when';
  }

  @override
  String syncLoadError(String error) {
    return 'Could not load queued changes: $error';
  }

  @override
  String get syncNoConflicts => 'No conflicts to review.';

  @override
  String get syncNothingQueued => 'Nothing queued. All changes are synced.';

  @override
  String syncNoticeLine(String entity, String what, String kept) {
    return '$entity: $what - $kept';
  }

  @override
  String get syncNoticeLocalKept => 'your version kept';

  @override
  String get syncNoticeServerKept => 'server version kept';

  @override
  String get syncNoticeWholeChange => 'change';

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncPhaseError => 'Sync problem';

  @override
  String get syncPhaseIdle => 'Up to date';

  @override
  String get syncPhaseOffline => 'Offline';

  @override
  String get syncPhaseSignedOut => 'Signed out';

  @override
  String get syncPhaseSyncing => 'Syncing';

  @override
  String get syncQueuedChanges => 'Queued changes';

  @override
  String get syncRecentConflicts => 'Recent conflicts';

  @override
  String get syncRetry => 'Retry';

  @override
  String get syncRetryAll => 'Retry all';

  @override
  String get syncStatusAllSynced => 'All changes synced';

  @override
  String get syncStatusOfflineIdle => 'Offline, nothing waiting to sync';

  @override
  String syncStatusOfflineWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes',
      one: '1 change',
    );
    return 'Offline, $_temp0 waiting to sync';
  }

  @override
  String syncStatusProblem(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes',
      one: '1 change',
    );
    return 'Sync problem, $_temp0 failed';
  }

  @override
  String get syncStatusSignedOut => 'Signed out';

  @override
  String syncStatusSignedOutWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes',
      one: '1 change',
    );
    return 'Signed out, $_temp0 waiting to sync';
  }

  @override
  String get syncStatusSyncing => 'Syncing';

  @override
  String syncStatusWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes',
      one: '1 change',
    );
    return '$_temp0 waiting to sync';
  }

  @override
  String syncTimeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0 ago';
  }

  @override
  String syncTimeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0 ago';
  }

  @override
  String get syncTimeJustNow => 'just now';

  @override
  String syncTimeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0 ago';
  }

  @override
  String get syncTimeNever => 'never';

  @override
  String get syncTitle => 'Sync';

  @override
  String get taskCancel => 'Cancel';

  @override
  String get taskDelete => 'Delete';

  @override
  String get taskDetailCompleted => 'Completed';

  @override
  String get taskDetailDeferUntil => 'Defer until';

  @override
  String get taskDetailDeleteMessage =>
      'Are you sure you want to delete this task?';

  @override
  String get taskDetailDeleteTitle => 'Delete Task';

  @override
  String get taskDetailDue => 'Due';

  @override
  String get taskDetailEditTooltip => 'Edit';

  @override
  String get taskDetailMarkComplete => 'Mark as Complete';

  @override
  String get taskDetailMarkIncomplete => 'Mark as Incomplete';

  @override
  String get taskDetailMenuTooltip => 'More actions';

  @override
  String taskDetailMetaLabel(String label) {
    return '$label: ';
  }

  @override
  String get taskDetailProject => 'Project';

  @override
  String get taskDetailSubtasks => 'Subtasks';

  @override
  String get taskEmptyAll => 'No tasks found.\nTap + to create one.';

  @override
  String get taskEmptyCompleted => 'No completed tasks yet.';

  @override
  String get taskEmptyToday => 'No tasks for today.\nEnjoy your free time! 🎉';

  @override
  String get taskErrorCancelled => 'Cancelled';

  @override
  String get taskErrorCsrf => 'Security check failed. Please try again.';

  @override
  String get taskErrorDecoding => 'Unexpected response from the server';

  @override
  String get taskErrorEmailNotVerified => 'Email address not verified';

  @override
  String get taskErrorForbidden => 'You are not allowed to do that';

  @override
  String get taskErrorGeneric => 'Something went wrong';

  @override
  String get taskErrorInvalidCredentials => 'Invalid email or password';

  @override
  String get taskErrorNetwork => 'No connection to the server';

  @override
  String get taskErrorNotFound => 'Task not found';

  @override
  String get taskErrorPasswordLoginDisabled => 'Password login is disabled';

  @override
  String get taskErrorRateLimited =>
      'Too many requests. Try again in a moment.';

  @override
  String taskErrorServer(int statusCode) {
    return 'Server error ($statusCode)';
  }

  @override
  String get taskErrorTimeout => 'The server took too long to respond';

  @override
  String get taskErrorUnauthorized => 'Session expired. Please sign in again.';

  @override
  String get taskFilterAll => 'All';

  @override
  String get taskFilterCompleted => 'Completed';

  @override
  String get taskFilterSomeday => 'Someday';

  @override
  String get taskFilterToday => 'Today';

  @override
  String get taskFilterUpcoming => 'Upcoming';

  @override
  String get taskFormClearTooltip => 'Clear';

  @override
  String get taskFormCompletionBased => 'Completion-based';

  @override
  String get taskFormCompletionBasedHint => 'Repeat from completion date';

  @override
  String get taskFormDeferUntil => 'Defer Until';

  @override
  String get taskFormDueDate => 'Due Date';

  @override
  String get taskFormEvery => 'Every';

  @override
  String get taskFormNameHint => 'What needs to be done?';

  @override
  String get taskFormNameLabel => 'Task Name';

  @override
  String get taskFormNameRequired => 'Name is required';

  @override
  String get taskFormNone => 'None';

  @override
  String get taskFormNotSet => 'Not set';

  @override
  String get taskFormNoteHint => 'Add details (Markdown supported)';

  @override
  String get taskFormNoteLabel => 'Notes';

  @override
  String get taskFormPriority => 'Priority';

  @override
  String get taskFormProject => 'Project';

  @override
  String get taskFormProjectSelected => 'Selected';

  @override
  String get taskFormRecurrence => 'Recurrence';

  @override
  String get taskFormSave => 'Save';

  @override
  String get taskFormStatus => 'Status';

  @override
  String get taskFormTitleEdit => 'Edit Task';

  @override
  String get taskFormTitleNew => 'New Task';

  @override
  String taskFormUnitDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'days',
      one: 'day',
    );
    return '$_temp0';
  }

  @override
  String taskFormUnitMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'months',
      one: 'month',
    );
    return '$_temp0';
  }

  @override
  String taskFormUnitWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'weeks',
      one: 'week',
    );
    return '$_temp0';
  }

  @override
  String get taskListTitle => 'Tasks';

  @override
  String get taskNewButton => 'New Task';

  @override
  String get taskPriorityHigh => 'High';

  @override
  String get taskPriorityLow => 'Low';

  @override
  String get taskPriorityMedium => 'Medium';

  @override
  String get taskRecurDaily => 'Daily';

  @override
  String taskRecurEveryDays(int count) {
    return 'Every $count days';
  }

  @override
  String taskRecurEveryMonths(int count) {
    return 'Every $count months';
  }

  @override
  String taskRecurEveryWeeks(int count) {
    return 'Every $count weeks';
  }

  @override
  String get taskRecurMonthly => 'Monthly';

  @override
  String get taskRecurMonthlyLastDay => 'Monthly (last day)';

  @override
  String get taskRecurMonthlyWeekday => 'Monthly (weekday)';

  @override
  String get taskRecurWeekly => 'Weekly';

  @override
  String get taskRetry => 'Retry';

  @override
  String get taskSortCreated => 'Date Created';

  @override
  String get taskSortDueDate => 'Due Date';

  @override
  String get taskSortName => 'Name';

  @override
  String get taskSortPriority => 'Priority';

  @override
  String get taskSortTooltip => 'Sort';

  @override
  String get taskStatusArchived => 'Archived';

  @override
  String get taskStatusCancelled => 'Cancelled';

  @override
  String get taskStatusDone => 'Done';

  @override
  String get taskStatusInProgress => 'In progress';

  @override
  String get taskStatusNotStarted => 'Not started';

  @override
  String get taskStatusPlanned => 'Planned';

  @override
  String get taskStatusUnknown => 'Unknown';

  @override
  String get taskStatusWaiting => 'Waiting';

  @override
  String get taskViewBoard => 'Board';

  @override
  String get taskViewList => 'List';
}
