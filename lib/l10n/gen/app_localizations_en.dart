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
  String get asyncStateErrorTitle => 'Something went wrong';

  @override
  String get asyncStateLoading => 'Loading';

  @override
  String get asyncStateOfflineHint =>
      'Nothing is saved on this device yet. Connect to load your data.';

  @override
  String get asyncStateOfflineTitle => 'You are offline';

  @override
  String get asyncStateRetry => 'Try again';

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
  String get bulkClear => 'Clear selection';

  @override
  String get bulkComplete => 'Complete';

  @override
  String get bulkDelete => 'Delete';

  @override
  String get bulkMoveProject => 'Move to project';

  @override
  String get bulkNoProject => 'No project';

  @override
  String get bulkPostpone => 'Postpone';

  @override
  String get bulkPriority => 'Priority';

  @override
  String bulkSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get bulkTag => 'Set tag';

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
  String get focusBack => 'Back to Today';

  @override
  String get focusDone => 'Done';

  @override
  String get focusEmptyBody => 'You have no tasks left for today.';

  @override
  String get focusEmptyTitle => 'Nothing to focus on';

  @override
  String focusPosition(int index, int total) {
    return '$index of $total';
  }

  @override
  String get focusPostpone => 'Postpone';

  @override
  String get focusSkip => 'Skip';

  @override
  String get focusSubtasks => 'Subtasks';

  @override
  String get focusTitle => 'Focus';

  @override
  String get inboxEmpty => 'Inbox is empty';

  @override
  String get inboxIgnore => 'Ignore';

  @override
  String get inboxMarkProcessed => 'Mark as Processed';

  @override
  String get inboxTelegramHint => 'Items from Telegram will appear here';

  @override
  String inboxV2AgeDays(int count) {
    return '$count d ago';
  }

  @override
  String inboxV2AgeHours(int count) {
    return '$count h ago';
  }

  @override
  String inboxV2AgeMinutes(int count) {
    return '$count min ago';
  }

  @override
  String get inboxV2AgeNow => 'Just now';

  @override
  String get inboxV2CaptureFailed => 'Could not save the item';

  @override
  String get inboxV2CaptureHint => 'Capture a thought, link or idea…';

  @override
  String get inboxV2CaptureSend => 'Add to inbox';

  @override
  String get inboxV2ConvertNote => 'Convert to note';

  @override
  String get inboxV2ConvertTask => 'Convert to task';

  @override
  String get inboxV2Deleted => 'Item deleted';

  @override
  String get inboxV2EmptyHint =>
      'Capture something above or send it from Telegram';

  @override
  String get inboxV2Ignored => 'Ignored';

  @override
  String get inboxV2ItemActions => 'More actions';

  @override
  String get inboxV2LoadFailed => 'Could not load the inbox';

  @override
  String get inboxV2MarkedProcessed => 'Marked as processed';

  @override
  String get inboxV2OpenNote => 'Open';

  @override
  String get inboxV2SavedAsNote => 'Saved as note';

  @override
  String get inboxV2Undo => 'Undo';

  @override
  String get inboxV2UnsortedHint => 'Give these a home or a due date';

  @override
  String get inboxV2UnsortedTasks => 'Tasks without project or date';

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
  String kanbanV2ColumnSummary(String status, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks',
      one: '1 task',
    );
    return '$status, $_temp0';
  }

  @override
  String get kanbanV2CurrentColumn => 'Current';

  @override
  String get kanbanV2DropHere => 'Drop here';

  @override
  String get kanbanV2EmptyColumn => 'Nothing here';

  @override
  String get kanbanV2MoveTo => 'Move to…';

  @override
  String kanbanV2MoveToStatus(String status) {
    return 'Move to $status';
  }

  @override
  String kanbanV2Moved(String status) {
    return 'Moved to $status';
  }

  @override
  String get listAllTasks => 'All tasks';

  @override
  String get listComingSoon => 'Coming soon';

  @override
  String get listEmptyCompletedHint =>
      'Finished tasks are kept here for 30 days.';

  @override
  String get listEmptyCompletedTitle => 'Nothing completed yet';

  @override
  String get listEmptyOverdueHint => 'No task is past its due date.';

  @override
  String get listEmptyOverdueTitle => 'All caught up';

  @override
  String get listEmptySomedayHint => 'Tasks without a due date live here.';

  @override
  String get listEmptySomedayTitle => 'No someday tasks';

  @override
  String get listEmptyUpcomingHint =>
      'Tasks due in the next 7 days show up here.';

  @override
  String get listEmptyUpcomingTitle => 'Nothing coming up';

  @override
  String get listLoadMore => 'Load more';

  @override
  String get listMoreSection => 'Lists & more';

  @override
  String get listNoDate => 'No date';

  @override
  String get listOverdue => 'Overdue';

  @override
  String get listRescheduleAll => 'Reschedule all to today';

  @override
  String listRescheduled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks moved to today',
      one: '1 task moved to today',
    );
    return '$_temp0';
  }

  @override
  String get listTags => 'Tags';

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
  String get navToday => 'Today';

  @override
  String get navUpcoming => 'Upcoming';

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
  String get noteV2ClearSearch => 'Clear search';

  @override
  String get noteV2Discard => 'Discard';

  @override
  String get noteV2DiscardBody => 'You have unsaved changes that will be lost.';

  @override
  String get noteV2DiscardTitle => 'Discard changes?';

  @override
  String get noteV2KeepEditing => 'Keep editing';

  @override
  String get noteV2ModeEdit => 'Edit';

  @override
  String get noteV2ModePreview => 'Preview';

  @override
  String get noteV2NoResults => 'No notes match your search';

  @override
  String get noteV2PreviewEmpty => 'Nothing to preview yet';

  @override
  String get noteV2Search => 'Search notes';

  @override
  String get noteV2Tags => 'Tags';

  @override
  String get noteV2Untitled => 'Untitled';

  @override
  String get noteV2ViewGrid => 'Grid view';

  @override
  String get noteV2ViewList => 'List view';

  @override
  String get paletteAddTask => 'Add task';

  @override
  String get paletteChangeTheme => 'Change theme';

  @override
  String get paletteEmpty => 'No matching commands';

  @override
  String get paletteGoAreas => 'Go to Areas';

  @override
  String get paletteGoCompleted => 'Go to Completed';

  @override
  String get paletteGoInbox => 'Go to Inbox';

  @override
  String get paletteGoNotes => 'Go to Notes';

  @override
  String get paletteGoOverdue => 'Go to Overdue';

  @override
  String get paletteGoProjects => 'Go to Projects';

  @override
  String get paletteGoSettings => 'Go to Settings';

  @override
  String get paletteGoSomeday => 'Go to Someday';

  @override
  String get paletteGoSync => 'Go to Sync';

  @override
  String get paletteGoToday => 'Go to Today';

  @override
  String get paletteGoUpcoming => 'Go to Upcoming';

  @override
  String get paletteHint => 'Type a command or search…';

  @override
  String paletteItemPosition(String label, int index, int total) {
    return '$label, $index of $total';
  }

  @override
  String get paletteKindNote => 'Note';

  @override
  String get paletteKindProject => 'Project';

  @override
  String get paletteKindTask => 'Task';

  @override
  String paletteResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
    );
    return '$_temp0';
  }

  @override
  String get paletteRunSync => 'Run sync now';

  @override
  String get paletteSearch => 'Search';

  @override
  String get paletteTitle => 'Command palette';

  @override
  String get paletteToggleReduceMotion => 'Toggle reduce motion';

  @override
  String get postponeNextWeek => 'Next week';

  @override
  String get postponePickDate => 'Pick a date…';

  @override
  String get postponeSkipOccurrence => 'Skip this occurrence';

  @override
  String get postponeSomeday => 'Someday (no date)';

  @override
  String get postponeTitle => 'Postpone';

  @override
  String get postponeTomorrow => 'Tomorrow';

  @override
  String get postponeWeekend => 'This weekend';

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
  String get quickAddAddAnother => 'Add another';

  @override
  String quickAddAdded(String name) {
    return 'Added $name';
  }

  @override
  String get quickAddApply => 'Apply';

  @override
  String get quickAddClose => 'Close';

  @override
  String get quickAddHint => 'Task, e.g. Pay rent every month !!';

  @override
  String get quickAddInlineHint => 'Add a task';

  @override
  String get quickAddKeepAsText => 'Tap to keep as plain text';

  @override
  String get quickAddMoreOptions => 'More options';

  @override
  String quickAddNextOccurrences(String dates) {
    return 'Next: $dates';
  }

  @override
  String get quickAddNone => 'None';

  @override
  String get quickAddNoteHint => 'Add a note';

  @override
  String get quickAddPickArea => 'Area';

  @override
  String get quickAddPickDate => 'Due date';

  @override
  String get quickAddPickNote => 'Note';

  @override
  String get quickAddPickPriority => 'Priority';

  @override
  String get quickAddPickProject => 'Project';

  @override
  String get quickAddPickRepeat => 'Repeat';

  @override
  String get quickAddPickTags => 'Tags';

  @override
  String get quickAddPickTime => 'Time';

  @override
  String get quickAddRecurAfterCompletion => 'after completion';

  @override
  String quickAddRecurDaily(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count days',
      one: 'Every day',
    );
    return '$_temp0';
  }

  @override
  String quickAddRecurMonthly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count months',
      one: 'Every month',
    );
    return '$_temp0';
  }

  @override
  String get quickAddRecurMonthlyLastDay => 'Last day of every month';

  @override
  String quickAddRecurMonthlyOnDay(int count, int day) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count months on day $day',
      one: 'Monthly on day $day',
    );
    return '$_temp0';
  }

  @override
  String quickAddRecurMonthlyWeekday(String week, String weekday) {
    String _temp0 = intl.Intl.selectLogic(week, {
      '1': 'first',
      '2': 'second',
      '3': 'third',
      '4': 'fourth',
      'other': 'last',
    });
    return 'Every $_temp0 $weekday of the month';
  }

  @override
  String quickAddRecurUntil(String date) {
    return 'until $date';
  }

  @override
  String get quickAddRecurWeekdays => 'Every weekday';

  @override
  String quickAddRecurWeekly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count weeks',
      one: 'Every week',
    );
    return '$_temp0';
  }

  @override
  String quickAddRecurWeeklyOn(int count, String days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count weeks on $days',
      one: 'Every week on $days',
    );
    return '$_temp0';
  }

  @override
  String get quickAddRepeatNone => 'Does not repeat';

  @override
  String get quickAddSubmit => 'Add task';

  @override
  String get quickAddTagHint => 'Add tag';

  @override
  String get quickAddTitle => 'Quick add';

  @override
  String get quickAddUndo => 'Undo';

  @override
  String get quickAddYearlyUnsupported =>
      'Yearly repeats are not supported by Tududi.';

  @override
  String get reviewClose => 'Back to Today';

  @override
  String get reviewDone => 'Done';

  @override
  String get reviewKeep => 'Keep';

  @override
  String get reviewPickDate => 'Pick date';

  @override
  String reviewProgress(int index, int total) {
    return 'Task $index of $total';
  }

  @override
  String get reviewSomeday => 'Someday';

  @override
  String reviewSummaryDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks completed',
      one: '$count task completed',
    );
    return '$_temp0';
  }

  @override
  String get reviewSummaryEmpty => 'No open tasks to review.';

  @override
  String reviewSummaryKept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks kept',
      one: '$count task kept',
    );
    return '$_temp0';
  }

  @override
  String reviewSummaryMoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks rescheduled',
      one: '$count task rescheduled',
    );
    return '$_temp0';
  }

  @override
  String reviewSummarySomeday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks moved to Someday',
      one: '$count task moved to Someday',
    );
    return '$_temp0';
  }

  @override
  String get reviewSummaryTitle => 'Review complete';

  @override
  String get reviewTitle => 'Daily review';

  @override
  String get reviewTomorrow => 'Tomorrow';

  @override
  String get searchClear => 'Clear';

  @override
  String get searchError => 'Search failed';

  @override
  String get searchHint => 'Search tasks, projects, notes';

  @override
  String get searchIntro =>
      'Search by name, or use #tag, +project, ~area, is:overdue, priority:high';

  @override
  String searchNoResults(String query) {
    return 'No results for “$query”';
  }

  @override
  String get searchOfflineBanner => 'Showing offline results';

  @override
  String get searchRecent => 'Recent searches';

  @override
  String get searchRecentClear => 'Clear all';

  @override
  String get searchRemoveRecent => 'Remove from recent searches';

  @override
  String get searchRetry => 'Try again';

  @override
  String get searchTitle => 'Search';

  @override
  String get searchTypeAll => 'All';

  @override
  String get searchTypeAreas => 'Areas';

  @override
  String get searchTypeNotes => 'Notes';

  @override
  String get searchTypeProjects => 'Projects';

  @override
  String get searchTypeTags => 'Tags';

  @override
  String get searchTypeTasks => 'Tasks';

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
  String get shellQuickAdd => 'Quick add task';

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
  String get taskEditArea => 'Area';

  @override
  String get taskEditDeferAfterDue =>
      'Defer date must not be after the due date';

  @override
  String get taskEditDiscard => 'Discard';

  @override
  String get taskEditDiscardBody =>
      'You have unsaved changes that will be lost.';

  @override
  String get taskEditDiscardTitle => 'Discard changes?';

  @override
  String get taskEditDueTime => 'Due time';

  @override
  String get taskEditEstimate => 'Estimate';

  @override
  String get taskEditEstimateInvalid => 'Enter a whole number of minutes';

  @override
  String get taskEditEstimateLabel => 'Estimate (minutes)';

  @override
  String get taskEditKeepEditing => 'Keep editing';

  @override
  String get taskEditNextOccurrences => 'Next occurrences';

  @override
  String get taskEditNoNote => 'No notes';

  @override
  String get taskEditPendingSync => 'Waiting to sync';

  @override
  String taskEditPreviewDates(String dates) {
    return '$dates';
  }

  @override
  String get taskEditRecurDayOfMonth => 'Day of the month';

  @override
  String get taskEditRecurEndDate => 'End date';

  @override
  String get taskEditRecurFirst => 'First';

  @override
  String get taskEditRecurFourth => 'Fourth';

  @override
  String taskEditRecurFrom(String date) {
    return 'Starting from $date';
  }

  @override
  String get taskEditRecurLast => 'Last';

  @override
  String get taskEditRecurNeedsDue => 'A repeating task needs a due date';

  @override
  String get taskEditRecurNoEnd => 'Never ends';

  @override
  String get taskEditRecurOrdinal => 'Which one';

  @override
  String get taskEditRecurPreview => 'Next 5 occurrences';

  @override
  String get taskEditRecurPreviewEmpty => 'No upcoming occurrences';

  @override
  String get taskEditRecurSecond => 'Second';

  @override
  String get taskEditRecurSummaryChange => 'Change repeat';

  @override
  String get taskEditRecurThird => 'Third';

  @override
  String get taskEditRecurTitle => 'Repeat';

  @override
  String get taskEditRecurType => 'Repeats';

  @override
  String get taskEditRecurWeekdayLabel => 'Weekday';

  @override
  String get taskEditRecurYearlyNote =>
      'Yearly repeats are not supported by the server. Use monthly with an interval of 12 instead.';

  @override
  String get taskEditReminder => 'Reminder';

  @override
  String get taskEditSetTime => 'Set time';

  @override
  String get taskEditSkipOccurrence => 'Skip this occurrence';

  @override
  String get taskEditSkipped => 'Occurrence skipped';

  @override
  String get taskEditSubtaskAdd => 'Add subtask';

  @override
  String get taskEditSubtaskDelete => 'Delete subtask';

  @override
  String get taskEditSubtaskHint => 'Add a subtask';

  @override
  String taskEditSubtaskProgress(int done, int total) {
    return '$done of $total done';
  }

  @override
  String get taskEditSubtaskReorder => 'Drag to reorder';

  @override
  String get taskEditTagAdd => 'Add tag';

  @override
  String get taskEditTagHint => 'Add a tag';

  @override
  String get taskEditTags => 'Tags';

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

  @override
  String get tileBlocked => 'Blocked';

  @override
  String get tileComplete => 'Complete';

  @override
  String tileDueOn(String date) {
    return 'Due $date';
  }

  @override
  String get tileEdit => 'Edit';

  @override
  String get tileEditTitle => 'Edit title';

  @override
  String tileEstimate(int minutes) {
    return '$minutes min';
  }

  @override
  String get tileHasNote => 'Has a note';

  @override
  String get tileMenu => 'More actions';

  @override
  String tileMoreTags(int count) {
    return '$count more tags';
  }

  @override
  String tileOverdueDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days overdue',
      one: '1 day overdue',
    );
    return '$_temp0';
  }

  @override
  String tilePostponedTimes(int count) {
    return 'Postponed ×$count';
  }

  @override
  String tilePriorityLabel(String priority) {
    return 'Priority $priority';
  }

  @override
  String get tileReopen => 'Reopen';

  @override
  String get tileRepeats => 'Repeats';

  @override
  String get tileSelect => 'Select';

  @override
  String get tileSelected => 'Selected';

  @override
  String tileSubtasksDone(int done, int total) {
    return '$done of $total subtasks done';
  }

  @override
  String get tileTitleHint => 'Task title';

  @override
  String todayDurationH(int hours) {
    return '$hours h';
  }

  @override
  String todayDurationHm(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String todayDurationM(int minutes) {
    return '$minutes min';
  }

  @override
  String get todayEmptyBody =>
      'Nothing left on your plate. Enjoy the rest of the day.';

  @override
  String get todayEmptyTitle => 'All done for today';

  @override
  String get todayErrorTitle => 'Could not load today\'s tasks';

  @override
  String get todayFocus => 'Focus mode';

  @override
  String todayMinutesLeft(String duration) {
    return '$duration left';
  }

  @override
  String get todayNoEstimate => 'No time estimates';

  @override
  String todayProgress(int done, int total) {
    return '$done of $total done';
  }

  @override
  String get todayRescheduleAll => 'Reschedule all';

  @override
  String get todayRetry => 'Retry';

  @override
  String get todayReview => 'Daily review';

  @override
  String get todaySearch => 'Search (coming soon)';

  @override
  String get todaySectionAfternoon => 'Afternoon';

  @override
  String get todaySectionAnytime => 'Anytime';

  @override
  String get todaySectionCompleted => 'Completed today';

  @override
  String get todaySectionEvening => 'Evening';

  @override
  String get todaySectionMorning => 'Morning';

  @override
  String get todaySectionOverdue => 'Overdue';

  @override
  String todaySectionToggle(String section) {
    return 'Show or hide $section';
  }

  @override
  String get todayTitle => 'Today';

  @override
  String get undoAction => 'Undo';

  @override
  String undoCompleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks completed',
      one: 'Task completed',
    );
    return '$_temp0';
  }

  @override
  String undoDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks deleted',
      one: 'Task deleted',
    );
    return '$_temp0';
  }

  @override
  String undoPostponed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks postponed',
      one: 'Task postponed',
    );
    return '$_temp0';
  }

  @override
  String undoUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks updated',
      one: 'Task updated',
    );
    return '$_temp0';
  }
}
