import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('zh'),
  ];

  /// App name
  ///
  /// In en, this message translates to:
  /// **'Tududa'**
  String get appName;

  /// Tooltip of the add-area FAB
  ///
  /// In en, this message translates to:
  /// **'New Area'**
  String get areaAddTooltip;

  /// No description provided for @areaCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get areaCancel;

  /// No description provided for @areaCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get areaCreate;

  /// No description provided for @areaDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get areaDeleteAction;

  /// No description provided for @areaDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Projects in this area will be unlinked.'**
  String get areaDeleteMessage;

  /// No description provided for @areaDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Area'**
  String get areaDeleteTitle;

  /// No description provided for @areaDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get areaDescription;

  /// No description provided for @areaDescriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get areaDescriptionOptional;

  /// No description provided for @areaEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Area'**
  String get areaEdit;

  /// No description provided for @areaEditAction.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get areaEditAction;

  /// No description provided for @areaLoadError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String areaLoadError(String error);

  /// No description provided for @areaName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get areaName;

  /// No description provided for @areaNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Work, Personal, Health'**
  String get areaNameHint;

  /// No description provided for @areaNew.
  ///
  /// In en, this message translates to:
  /// **'New Area'**
  String get areaNew;

  /// No description provided for @areaSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get areaSave;

  /// No description provided for @areasEmpty.
  ///
  /// In en, this message translates to:
  /// **'No areas yet'**
  String get areasEmpty;

  /// No description provided for @areasEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Areas help organize your projects'**
  String get areasEmptyHint;

  /// No description provided for @areasTitle.
  ///
  /// In en, this message translates to:
  /// **'Areas'**
  String get areasTitle;

  /// Error state title
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get asyncStateErrorTitle;

  /// Accessibility label of the loading placeholder
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get asyncStateLoading;

  /// Offline state hint
  ///
  /// In en, this message translates to:
  /// **'Nothing is saved on this device yet. Connect to load your data.'**
  String get asyncStateOfflineHint;

  /// Offline state title
  ///
  /// In en, this message translates to:
  /// **'You are offline'**
  String get asyncStateOfflineTitle;

  /// Retry button of the error and offline states
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get asyncStateRetry;

  /// No description provided for @authCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get authCancel;

  /// No description provided for @authChangeServer.
  ///
  /// In en, this message translates to:
  /// **'Change Server'**
  String get authChangeServer;

  /// No description provided for @authConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get authConnect;

  /// No description provided for @authConnectPrompt.
  ///
  /// In en, this message translates to:
  /// **'Connect to your self-hosted Tududa server'**
  String get authConnectPrompt;

  /// No description provided for @authConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get authConnecting;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get authEmailRequired;

  /// No description provided for @authErrorEmailNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Your email address is not verified yet. Check your inbox for the verification link.'**
  String get authErrorEmailNotVerified;

  /// No description provided for @authErrorEnterServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter a server address'**
  String get authErrorEnterServerUrl;

  /// No description provided for @authErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get authErrorGeneric;

  /// No description provided for @authErrorInsecure.
  ///
  /// In en, this message translates to:
  /// **'Plain HTTP connections are not encrypted.'**
  String get authErrorInsecure;

  /// No description provided for @authErrorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password.'**
  String get authErrorInvalidCredentials;

  /// No description provided for @authErrorInvalidServerUrl.
  ///
  /// In en, this message translates to:
  /// **'That is not a valid address'**
  String get authErrorInvalidServerUrl;

  /// No description provided for @authErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. Check your connection and the server address.'**
  String get authErrorNetwork;

  /// No description provided for @authErrorPasswordLoginDisabled.
  ///
  /// In en, this message translates to:
  /// **'Password sign-in is disabled for this account. It uses single sign-on (SSO), which this app does not support yet.'**
  String get authErrorPasswordLoginDisabled;

  /// No description provided for @authErrorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again later.'**
  String get authErrorRateLimited;

  /// No description provided for @authErrorRateLimitedMinutes.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in {minutes, plural, =1{1 minute} other{{minutes} minutes}}.'**
  String authErrorRateLimitedMinutes(int minutes);

  /// No description provided for @authErrorServer.
  ///
  /// In en, this message translates to:
  /// **'The server had a problem ({code}). Try again later.'**
  String authErrorServer(String code);

  /// Tooltip of the password visibility toggle
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get authHidePassword;

  /// No description provided for @authInsecureBody.
  ///
  /// In en, this message translates to:
  /// **'This address does not use HTTPS. Your password and tasks would be sent without encryption and could be read on the network. Only continue on a network you trust.'**
  String get authInsecureBody;

  /// No description provided for @authInsecureConfirm.
  ///
  /// In en, this message translates to:
  /// **'Use insecure HTTP'**
  String get authInsecureConfirm;

  /// No description provided for @authInsecureTitle.
  ///
  /// In en, this message translates to:
  /// **'Use insecure HTTP?'**
  String get authInsecureTitle;

  /// No description provided for @authInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email'**
  String get authInvalidEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get authPasswordRequired;

  /// No description provided for @authServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get authServerUrl;

  /// No description provided for @authServerUrlHelper.
  ///
  /// In en, this message translates to:
  /// **'Enter your Tududa server address'**
  String get authServerUrlHelper;

  /// No description provided for @authServerUrlRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a server URL'**
  String get authServerUrlRequired;

  /// Tooltip of the password visibility toggle
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get authShowPassword;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get authSignIn;

  /// No description provided for @authWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Tududa'**
  String get authWelcome;

  /// Bulk bar: leave selection mode
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get bulkClear;

  /// Bulk bar action
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get bulkComplete;

  /// Bulk bar action
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get bulkDelete;

  /// Bulk bar action
  ///
  /// In en, this message translates to:
  /// **'Move to project'**
  String get bulkMoveProject;

  /// Bulk move: remove from project
  ///
  /// In en, this message translates to:
  /// **'No project'**
  String get bulkNoProject;

  /// Bulk bar action
  ///
  /// In en, this message translates to:
  /// **'Postpone'**
  String get bulkPostpone;

  /// Bulk bar action
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get bulkPriority;

  /// Bulk bar: number of selected tasks
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String bulkSelectedCount(int count);

  /// Bulk bar action: add a tag to all selected tasks
  ///
  /// In en, this message translates to:
  /// **'Set tag'**
  String get bulkTag;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get commonError;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// No description provided for @commonNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get commonNone;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// A date a few days in the past
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String coreDaysAgo(int count);

  /// A date a few days in the future
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{in 1 day} other{in {count} days}}'**
  String coreInDays(int count);

  /// Relative day label for the current date
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get coreToday;

  /// Relative day label for the next date
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get coreTomorrow;

  /// Relative day label for the previous date
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get coreYesterday;

  /// Focus empty state button
  ///
  /// In en, this message translates to:
  /// **'Back to Today'**
  String get focusBack;

  /// Focus button
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get focusDone;

  /// Focus empty state text
  ///
  /// In en, this message translates to:
  /// **'You have no tasks left for today.'**
  String get focusEmptyBody;

  /// Focus empty state title
  ///
  /// In en, this message translates to:
  /// **'Nothing to focus on'**
  String get focusEmptyTitle;

  /// Position in the focus queue
  ///
  /// In en, this message translates to:
  /// **'{index} of {total}'**
  String focusPosition(int index, int total);

  /// Focus button
  ///
  /// In en, this message translates to:
  /// **'Postpone'**
  String get focusPostpone;

  /// Focus button: show the next task
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get focusSkip;

  /// Heading of the subtask list
  ///
  /// In en, this message translates to:
  /// **'Subtasks'**
  String get focusSubtasks;

  /// Title of the focus screen
  ///
  /// In en, this message translates to:
  /// **'Focus'**
  String get focusTitle;

  /// No description provided for @inboxEmpty.
  ///
  /// In en, this message translates to:
  /// **'Inbox is empty'**
  String get inboxEmpty;

  /// No description provided for @inboxIgnore.
  ///
  /// In en, this message translates to:
  /// **'Ignore'**
  String get inboxIgnore;

  /// No description provided for @inboxMarkProcessed.
  ///
  /// In en, this message translates to:
  /// **'Mark as Processed'**
  String get inboxMarkProcessed;

  /// No description provided for @inboxTelegramHint.
  ///
  /// In en, this message translates to:
  /// **'Items from Telegram will appear here'**
  String get inboxTelegramHint;

  /// No description provided for @inboxV2AgeDays.
  ///
  /// In en, this message translates to:
  /// **'{count} d ago'**
  String inboxV2AgeDays(int count);

  /// No description provided for @inboxV2AgeHours.
  ///
  /// In en, this message translates to:
  /// **'{count} h ago'**
  String inboxV2AgeHours(int count);

  /// No description provided for @inboxV2AgeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String inboxV2AgeMinutes(int count);

  /// No description provided for @inboxV2AgeNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get inboxV2AgeNow;

  /// No description provided for @inboxV2CaptureFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the item'**
  String get inboxV2CaptureFailed;

  /// Hint of the inbox capture field
  ///
  /// In en, this message translates to:
  /// **'Capture a thought, link or idea…'**
  String get inboxV2CaptureHint;

  /// Tooltip of the capture send button
  ///
  /// In en, this message translates to:
  /// **'Add to inbox'**
  String get inboxV2CaptureSend;

  /// No description provided for @inboxV2ConvertNote.
  ///
  /// In en, this message translates to:
  /// **'Convert to note'**
  String get inboxV2ConvertNote;

  /// No description provided for @inboxV2ConvertTask.
  ///
  /// In en, this message translates to:
  /// **'Convert to task'**
  String get inboxV2ConvertTask;

  /// No description provided for @inboxV2Deleted.
  ///
  /// In en, this message translates to:
  /// **'Item deleted'**
  String get inboxV2Deleted;

  /// No description provided for @inboxV2EmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Capture something above or send it from Telegram'**
  String get inboxV2EmptyHint;

  /// No description provided for @inboxV2Ignored.
  ///
  /// In en, this message translates to:
  /// **'Ignored'**
  String get inboxV2Ignored;

  /// No description provided for @inboxV2ItemActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get inboxV2ItemActions;

  /// No description provided for @inboxV2LoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the inbox'**
  String get inboxV2LoadFailed;

  /// No description provided for @inboxV2MarkedProcessed.
  ///
  /// In en, this message translates to:
  /// **'Marked as processed'**
  String get inboxV2MarkedProcessed;

  /// No description provided for @inboxV2OpenNote.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get inboxV2OpenNote;

  /// No description provided for @inboxV2SavedAsNote.
  ///
  /// In en, this message translates to:
  /// **'Saved as note'**
  String get inboxV2SavedAsNote;

  /// No description provided for @inboxV2Undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get inboxV2Undo;

  /// No description provided for @inboxV2UnsortedHint.
  ///
  /// In en, this message translates to:
  /// **'Give these a home or a due date'**
  String get inboxV2UnsortedHint;

  /// No description provided for @inboxV2UnsortedTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks without project or date'**
  String get inboxV2UnsortedTasks;

  /// No description provided for @kanbanNoTasks.
  ///
  /// In en, this message translates to:
  /// **'No tasks found.\nTap + to create one.'**
  String get kanbanNoTasks;

  /// Kanban column title
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get kanbanStatusArchived;

  /// Kanban column title
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get kanbanStatusCancelled;

  /// Kanban column title
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get kanbanStatusDone;

  /// Kanban column title
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get kanbanStatusInProgress;

  /// Kanban column title
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get kanbanStatusOther;

  /// Kanban column title
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get kanbanStatusPlanned;

  /// Kanban column title
  ///
  /// In en, this message translates to:
  /// **'To Do'**
  String get kanbanStatusToDo;

  /// Kanban column title
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get kanbanStatusWaiting;

  /// No description provided for @kanbanV2ColumnSummary.
  ///
  /// In en, this message translates to:
  /// **'{status}, {count, plural, =1{1 task} other{{count} tasks}}'**
  String kanbanV2ColumnSummary(String status, int count);

  /// No description provided for @kanbanV2CurrentColumn.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get kanbanV2CurrentColumn;

  /// No description provided for @kanbanV2DropHere.
  ///
  /// In en, this message translates to:
  /// **'Drop here'**
  String get kanbanV2DropHere;

  /// No description provided for @kanbanV2EmptyColumn.
  ///
  /// In en, this message translates to:
  /// **'Nothing here'**
  String get kanbanV2EmptyColumn;

  /// Title of the move menu and accessibility action of a kanban card
  ///
  /// In en, this message translates to:
  /// **'Move to…'**
  String get kanbanV2MoveTo;

  /// No description provided for @kanbanV2MoveToStatus.
  ///
  /// In en, this message translates to:
  /// **'Move to {status}'**
  String kanbanV2MoveToStatus(String status);

  /// No description provided for @kanbanV2Moved.
  ///
  /// In en, this message translates to:
  /// **'Moved to {status}'**
  String kanbanV2Moved(String status);

  /// Link to the all tasks screen
  ///
  /// In en, this message translates to:
  /// **'All tasks'**
  String get listAllTasks;

  /// Subtitle of a disabled link
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get listComingSoon;

  /// Empty Completed list hint
  ///
  /// In en, this message translates to:
  /// **'Finished tasks are kept here for 30 days.'**
  String get listEmptyCompletedHint;

  /// Empty Completed list title
  ///
  /// In en, this message translates to:
  /// **'Nothing completed yet'**
  String get listEmptyCompletedTitle;

  /// Empty Overdue list hint
  ///
  /// In en, this message translates to:
  /// **'No task is past its due date.'**
  String get listEmptyOverdueHint;

  /// Empty Overdue list title
  ///
  /// In en, this message translates to:
  /// **'All caught up'**
  String get listEmptyOverdueTitle;

  /// Empty Someday list hint
  ///
  /// In en, this message translates to:
  /// **'Tasks without a due date live here.'**
  String get listEmptySomedayHint;

  /// Empty Someday list title
  ///
  /// In en, this message translates to:
  /// **'No someday tasks'**
  String get listEmptySomedayTitle;

  /// Empty Upcoming list hint
  ///
  /// In en, this message translates to:
  /// **'Tasks due in the next 7 days show up here.'**
  String get listEmptyUpcomingHint;

  /// Empty Upcoming list title
  ///
  /// In en, this message translates to:
  /// **'Nothing coming up'**
  String get listEmptyUpcomingTitle;

  /// Button that shows older completed tasks
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get listLoadMore;

  /// Section of the More screen linking to lists
  ///
  /// In en, this message translates to:
  /// **'Lists & more'**
  String get listMoreSection;

  /// Group header in Upcoming for tasks without a due day
  ///
  /// In en, this message translates to:
  /// **'No date'**
  String get listNoDate;

  /// Title of the overdue tasks list
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get listOverdue;

  /// Button that moves every overdue task to today
  ///
  /// In en, this message translates to:
  /// **'Reschedule all to today'**
  String get listRescheduleAll;

  /// Snackbar after rescheduling overdue tasks
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 task moved to today} other{{count} tasks moved to today}}'**
  String listRescheduled(int count);

  /// Link to the tags screen
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get listTags;

  /// Bottom navigation label and inbox screen title
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get navInbox;

  /// Bottom navigation label
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// Bottom navigation label and notes screen title
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get navNotes;

  /// Bottom navigation label
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get navProjects;

  /// Bottom navigation label
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get navTasks;

  /// Bottom navigation: today's tasks
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get navToday;

  /// Bottom navigation: upcoming tasks
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get navUpcoming;

  /// No description provided for @noteColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get noteColor;

  /// No description provided for @noteContentHint.
  ///
  /// In en, this message translates to:
  /// **'Jot down your thoughts (Markdown supported)'**
  String get noteContentHint;

  /// No description provided for @noteDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get noteDeleteConfirm;

  /// No description provided for @noteDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Note'**
  String get noteDeleteTitle;

  /// No description provided for @noteEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Note'**
  String get noteEdit;

  /// No description provided for @noteEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notes yet.\nTap + to create one.'**
  String get noteEmpty;

  /// No description provided for @noteNew.
  ///
  /// In en, this message translates to:
  /// **'New Note'**
  String get noteNew;

  /// No description provided for @noteProject.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get noteProject;

  /// No description provided for @noteSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save note'**
  String get noteSaveFailed;

  /// No description provided for @noteTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Note Title'**
  String get noteTitleHint;

  /// No description provided for @noteV2ClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get noteV2ClearSearch;

  /// No description provided for @noteV2Discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get noteV2Discard;

  /// No description provided for @noteV2DiscardBody.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes that will be lost.'**
  String get noteV2DiscardBody;

  /// No description provided for @noteV2DiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get noteV2DiscardTitle;

  /// No description provided for @noteV2KeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get noteV2KeepEditing;

  /// Markdown editor mode
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get noteV2ModeEdit;

  /// Markdown preview mode
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get noteV2ModePreview;

  /// No description provided for @noteV2NoResults.
  ///
  /// In en, this message translates to:
  /// **'No notes match your search'**
  String get noteV2NoResults;

  /// No description provided for @noteV2PreviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to preview yet'**
  String get noteV2PreviewEmpty;

  /// No description provided for @noteV2Search.
  ///
  /// In en, this message translates to:
  /// **'Search notes'**
  String get noteV2Search;

  /// No description provided for @noteV2Tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get noteV2Tags;

  /// No description provided for @noteV2Untitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get noteV2Untitled;

  /// No description provided for @noteV2ViewGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid view'**
  String get noteV2ViewGrid;

  /// No description provided for @noteV2ViewList.
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get noteV2ViewList;

  /// Palette command
  ///
  /// In en, this message translates to:
  /// **'Add task'**
  String get paletteAddTask;

  /// Palette command: cycles system/light/dark
  ///
  /// In en, this message translates to:
  /// **'Change theme'**
  String get paletteChangeTheme;

  /// Command palette: nothing matches
  ///
  /// In en, this message translates to:
  /// **'No matching commands'**
  String get paletteEmpty;

  /// Palette command: navigate
  ///
  /// In en, this message translates to:
  /// **'Go to Areas'**
  String get paletteGoAreas;

  /// Palette command: navigate
  ///
  /// In en, this message translates to:
  /// **'Go to Completed'**
  String get paletteGoCompleted;

  /// Palette command: navigate
  ///
  /// In en, this message translates to:
  /// **'Go to Inbox'**
  String get paletteGoInbox;

  /// Palette command: navigate
  ///
  /// In en, this message translates to:
  /// **'Go to Notes'**
  String get paletteGoNotes;

  /// Palette command: navigate
  ///
  /// In en, this message translates to:
  /// **'Go to Overdue'**
  String get paletteGoOverdue;

  /// Palette command: navigate
  ///
  /// In en, this message translates to:
  /// **'Go to Projects'**
  String get paletteGoProjects;

  /// Palette command: navigate
  ///
  /// In en, this message translates to:
  /// **'Go to Settings'**
  String get paletteGoSettings;

  /// Palette command: navigate
  ///
  /// In en, this message translates to:
  /// **'Go to Someday'**
  String get paletteGoSomeday;

  /// Palette command: navigate
  ///
  /// In en, this message translates to:
  /// **'Go to Sync'**
  String get paletteGoSync;

  /// Palette command: navigate
  ///
  /// In en, this message translates to:
  /// **'Go to Today'**
  String get paletteGoToday;

  /// Palette command: navigate
  ///
  /// In en, this message translates to:
  /// **'Go to Upcoming'**
  String get paletteGoUpcoming;

  /// Command palette text field hint
  ///
  /// In en, this message translates to:
  /// **'Type a command or search…'**
  String get paletteHint;

  /// Screen reader: palette row position
  ///
  /// In en, this message translates to:
  /// **'{label}, {index} of {total}'**
  String paletteItemPosition(String label, int index, int total);

  /// Kind label of an item in the palette
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get paletteKindNote;

  /// Kind label of an item in the palette
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get paletteKindProject;

  /// Kind label of an item in the palette
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get paletteKindTask;

  /// Screen reader: number of palette results
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 result} other{{count} results}}'**
  String paletteResultCount(int count);

  /// Palette command
  ///
  /// In en, this message translates to:
  /// **'Run sync now'**
  String get paletteRunSync;

  /// Palette command: open search with the typed text
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get paletteSearch;

  /// Semantic label of the command palette dialog
  ///
  /// In en, this message translates to:
  /// **'Command palette'**
  String get paletteTitle;

  /// Palette command
  ///
  /// In en, this message translates to:
  /// **'Toggle reduce motion'**
  String get paletteToggleReduceMotion;

  /// Postpone option: first day of next week
  ///
  /// In en, this message translates to:
  /// **'Next week'**
  String get postponeNextWeek;

  /// Postpone option: open a date picker
  ///
  /// In en, this message translates to:
  /// **'Pick a date…'**
  String get postponePickDate;

  /// Postpone option for recurring tasks
  ///
  /// In en, this message translates to:
  /// **'Skip this occurrence'**
  String get postponeSkipOccurrence;

  /// Postpone option: clear the due date
  ///
  /// In en, this message translates to:
  /// **'Someday (no date)'**
  String get postponeSomeday;

  /// Title of the postpone sheet and action
  ///
  /// In en, this message translates to:
  /// **'Postpone'**
  String get postponeTitle;

  /// Postpone option
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get postponeTomorrow;

  /// Postpone option: next Saturday
  ///
  /// In en, this message translates to:
  /// **'This weekend'**
  String get postponeWeekend;

  /// No description provided for @projectAddTask.
  ///
  /// In en, this message translates to:
  /// **'Add Task'**
  String get projectAddTask;

  /// No description provided for @projectArea.
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get projectArea;

  /// No description provided for @projectAreaLabel.
  ///
  /// In en, this message translates to:
  /// **'Area: {name}'**
  String projectAreaLabel(String name);

  /// No description provided for @projectCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get projectCancel;

  /// No description provided for @projectDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get projectDelete;

  /// No description provided for @projectDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'This will delete the project and all its tasks.'**
  String get projectDeleteMessage;

  /// No description provided for @projectDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Project'**
  String get projectDeleteTitle;

  /// No description provided for @projectDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get projectDescription;

  /// No description provided for @projectEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Project'**
  String get projectEdit;

  /// No description provided for @projectLoadError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String projectLoadError(String error);

  /// No description provided for @projectName.
  ///
  /// In en, this message translates to:
  /// **'Project Name'**
  String get projectName;

  /// No description provided for @projectNameHint.
  ///
  /// In en, this message translates to:
  /// **'Max 6 words'**
  String get projectNameHint;

  /// No description provided for @projectNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get projectNameRequired;

  /// No description provided for @projectNew.
  ///
  /// In en, this message translates to:
  /// **'New Project'**
  String get projectNew;

  /// No description provided for @projectNoArea.
  ///
  /// In en, this message translates to:
  /// **'No Area'**
  String get projectNoArea;

  /// No description provided for @projectNotFound.
  ///
  /// In en, this message translates to:
  /// **'Project not found'**
  String get projectNotFound;

  /// No description provided for @projectPinSidebar.
  ///
  /// In en, this message translates to:
  /// **'Pin to Sidebar'**
  String get projectPinSidebar;

  /// No description provided for @projectPinSidebarHint.
  ///
  /// In en, this message translates to:
  /// **'Quick access from navigation'**
  String get projectPinSidebarHint;

  /// No description provided for @projectPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get projectPriority;

  /// No description provided for @projectPriorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get projectPriorityHigh;

  /// No description provided for @projectPriorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get projectPriorityLow;

  /// No description provided for @projectPriorityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get projectPriorityMedium;

  /// No description provided for @projectPriorityNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get projectPriorityNone;

  /// No description provided for @projectRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get projectRetry;

  /// No description provided for @projectSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get projectSave;

  /// No description provided for @projectSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save project: {error}'**
  String projectSaveFailed(String error);

  /// No description provided for @projectStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get projectStatus;

  /// No description provided for @projectStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get projectStatusCancelled;

  /// No description provided for @projectStatusDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get projectStatusDone;

  /// No description provided for @projectStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get projectStatusInProgress;

  /// No description provided for @projectStatusNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not Started'**
  String get projectStatusNotStarted;

  /// No description provided for @projectStatusPlanned.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get projectStatusPlanned;

  /// No description provided for @projectStatusWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get projectStatusWaiting;

  /// No description provided for @projectTaskProgress.
  ///
  /// In en, this message translates to:
  /// **'{done}/{total} tasks'**
  String projectTaskProgress(int done, int total);

  /// No description provided for @projectTasksHeading.
  ///
  /// In en, this message translates to:
  /// **'Project Tasks'**
  String get projectTasksHeading;

  /// No description provided for @projectViewBoard.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get projectViewBoard;

  /// No description provided for @projectViewList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get projectViewList;

  /// No description provided for @projectsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No projects yet.\nTap + to create one.'**
  String get projectsEmpty;

  /// Projects list app bar title
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get projectsTitle;

  /// Switch that keeps quick add open after saving
  ///
  /// In en, this message translates to:
  /// **'Add another'**
  String get quickAddAddAnother;

  /// Snackbar after saving a task
  ///
  /// In en, this message translates to:
  /// **'Added {name}'**
  String quickAddAdded(String name);

  /// Confirms a quick-add picker dialog
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get quickAddApply;

  /// Closes the quick-add sheet
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get quickAddClose;

  /// Hint of the quick-add text field
  ///
  /// In en, this message translates to:
  /// **'Task, e.g. Pay rent every month !!'**
  String get quickAddHint;

  /// Hint of the inline add row at the end of lists
  ///
  /// In en, this message translates to:
  /// **'Add a task'**
  String get quickAddInlineHint;

  /// Tooltip of a recognised-token chip
  ///
  /// In en, this message translates to:
  /// **'Tap to keep as plain text'**
  String get quickAddKeepAsText;

  /// Opens the full task form
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get quickAddMoreOptions;

  /// Preview of the next occurrences of a repeating task
  ///
  /// In en, this message translates to:
  /// **'Next: {dates}'**
  String quickAddNextOccurrences(String dates);

  /// Choice meaning no project, area or priority
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get quickAddNone;

  /// Hint of the note field in quick add
  ///
  /// In en, this message translates to:
  /// **'Add a note'**
  String get quickAddNoteHint;

  /// Quick-add picker
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get quickAddPickArea;

  /// Quick-add picker
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get quickAddPickDate;

  /// Quick-add picker
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get quickAddPickNote;

  /// Quick-add picker
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get quickAddPickPriority;

  /// Quick-add picker
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get quickAddPickProject;

  /// Quick-add picker
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get quickAddPickRepeat;

  /// Quick-add picker
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get quickAddPickTags;

  /// Quick-add picker
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get quickAddPickTime;

  /// Recurrence suffix for completion-based rules
  ///
  /// In en, this message translates to:
  /// **'after completion'**
  String get quickAddRecurAfterCompletion;

  /// Recurrence summary
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every day} other{Every {count} days}}'**
  String quickAddRecurDaily(int count);

  /// Recurrence summary
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every month} other{Every {count} months}}'**
  String quickAddRecurMonthly(int count);

  /// Recurrence summary
  ///
  /// In en, this message translates to:
  /// **'Last day of every month'**
  String get quickAddRecurMonthlyLastDay;

  /// Recurrence summary with day of month
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Monthly on day {day}} other{Every {count} months on day {day}}}'**
  String quickAddRecurMonthlyOnDay(int count, int day);

  /// Recurrence summary for the n-th weekday of a month
  ///
  /// In en, this message translates to:
  /// **'Every {week, select, 1{first} 2{second} 3{third} 4{fourth} other{last}} {weekday} of the month'**
  String quickAddRecurMonthlyWeekday(String week, String weekday);

  /// Recurrence end date suffix
  ///
  /// In en, this message translates to:
  /// **'until {date}'**
  String quickAddRecurUntil(String date);

  /// Recurrence summary for Monday to Friday
  ///
  /// In en, this message translates to:
  /// **'Every weekday'**
  String get quickAddRecurWeekdays;

  /// Recurrence summary
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every week} other{Every {count} weeks}}'**
  String quickAddRecurWeekly(int count);

  /// Recurrence summary with weekday names
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every week on {days}} other{Every {count} weeks on {days}}}'**
  String quickAddRecurWeeklyOn(int count, String days);

  /// Recurrence option
  ///
  /// In en, this message translates to:
  /// **'Does not repeat'**
  String get quickAddRepeatNone;

  /// Submit button of the quick-add sheet
  ///
  /// In en, this message translates to:
  /// **'Add task'**
  String get quickAddSubmit;

  /// Hint of the tag name field
  ///
  /// In en, this message translates to:
  /// **'Add tag'**
  String get quickAddTagHint;

  /// Title of the quick-add sheet
  ///
  /// In en, this message translates to:
  /// **'Quick add'**
  String get quickAddTitle;

  /// Snackbar action that removes the task just added
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get quickAddUndo;

  /// Hint shown when a yearly phrase is recognised
  ///
  /// In en, this message translates to:
  /// **'Yearly repeats are not supported by Tududi.'**
  String get quickAddYearlyUnsupported;

  /// Summary button
  ///
  /// In en, this message translates to:
  /// **'Back to Today'**
  String get reviewClose;

  /// Review button
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get reviewDone;

  /// Review button: leave the task as it is
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get reviewKeep;

  /// Review button
  ///
  /// In en, this message translates to:
  /// **'Pick date'**
  String get reviewPickDate;

  /// Progress in the review
  ///
  /// In en, this message translates to:
  /// **'Task {index} of {total}'**
  String reviewProgress(int index, int total);

  /// Review button
  ///
  /// In en, this message translates to:
  /// **'Someday'**
  String get reviewSomeday;

  /// Summary line
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} task completed} other{{count} tasks completed}}'**
  String reviewSummaryDone(int count);

  /// Summary when nothing was reviewed
  ///
  /// In en, this message translates to:
  /// **'No open tasks to review.'**
  String get reviewSummaryEmpty;

  /// Summary line
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} task kept} other{{count} tasks kept}}'**
  String reviewSummaryKept(int count);

  /// Summary line
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} task rescheduled} other{{count} tasks rescheduled}}'**
  String reviewSummaryMoved(int count);

  /// Summary line
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} task moved to Someday} other{{count} tasks moved to Someday}}'**
  String reviewSummarySomeday(int count);

  /// Summary title
  ///
  /// In en, this message translates to:
  /// **'Review complete'**
  String get reviewSummaryTitle;

  /// Title of the review screen
  ///
  /// In en, this message translates to:
  /// **'Daily review'**
  String get reviewTitle;

  /// Review button
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get reviewTomorrow;

  /// Tooltip of the clear button in the search field
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get searchClear;

  /// Error state of the search screen
  ///
  /// In en, this message translates to:
  /// **'Search failed'**
  String get searchError;

  /// Placeholder of the search field
  ///
  /// In en, this message translates to:
  /// **'Search tasks, projects, notes'**
  String get searchHint;

  /// Hint shown on the empty search screen
  ///
  /// In en, this message translates to:
  /// **'Search by name, or use #tag, +project, ~area, is:overdue, priority:high'**
  String get searchIntro;

  /// Empty state of the search results
  ///
  /// In en, this message translates to:
  /// **'No results for “{query}”'**
  String searchNoResults(String query);

  /// Banner when results come from the local database
  ///
  /// In en, this message translates to:
  /// **'Showing offline results'**
  String get searchOfflineBanner;

  /// Header of the recent searches list
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get searchRecent;

  /// Button that deletes all recent searches
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get searchRecentClear;

  /// Tooltip of the remove button of a recent search
  ///
  /// In en, this message translates to:
  /// **'Remove from recent searches'**
  String get searchRemoveRecent;

  /// Retry button of the search error state
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get searchRetry;

  /// Title and accessibility label of the search screen
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTitle;

  /// Search filter chip for all types
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get searchTypeAll;

  /// Search result group and filter chip
  ///
  /// In en, this message translates to:
  /// **'Areas'**
  String get searchTypeAreas;

  /// Search result group and filter chip
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get searchTypeNotes;

  /// Search result group and filter chip
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get searchTypeProjects;

  /// Search result group and filter chip
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get searchTypeTags;

  /// Search result group and filter chip
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get searchTypeTasks;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About Tududa'**
  String get settingsAbout;

  /// No description provided for @settingsAboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'v1.0.1 • Open Source'**
  String get settingsAboutSubtitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsAreas.
  ///
  /// In en, this message translates to:
  /// **'Areas'**
  String get settingsAreas;

  /// No description provided for @settingsAreasDesc.
  ///
  /// In en, this message translates to:
  /// **'Organize projects into areas'**
  String get settingsAreasDesc;

  /// No description provided for @settingsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsCancel;

  /// No description provided for @settingsContrast.
  ///
  /// In en, this message translates to:
  /// **'Contrast'**
  String get settingsContrast;

  /// No description provided for @settingsContrastHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get settingsContrastHigh;

  /// No description provided for @settingsContrastMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get settingsContrastMedium;

  /// No description provided for @settingsContrastStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get settingsContrastStandard;

  /// No description provided for @settingsDensity.
  ///
  /// In en, this message translates to:
  /// **'Density'**
  String get settingsDensity;

  /// No description provided for @settingsDensityComfortable.
  ///
  /// In en, this message translates to:
  /// **'Comfortable'**
  String get settingsDensityComfortable;

  /// No description provided for @settingsDensityCompact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get settingsDensityCompact;

  /// Switch title: use the wallpaper colors (Material You)
  ///
  /// In en, this message translates to:
  /// **'Dynamic color'**
  String get settingsDynamicColor;

  /// No description provided for @settingsDynamicColorHint.
  ///
  /// In en, this message translates to:
  /// **'Use colors from your wallpaper when available'**
  String get settingsDynamicColorHint;

  /// No description provided for @settingsIntegrations.
  ///
  /// In en, this message translates to:
  /// **'Integrations'**
  String get settingsIntegrations;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// Language option that follows the device language
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get settingsMore;

  /// No description provided for @settingsNavigation.
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get settingsNavigation;

  /// No description provided for @settingsPreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get settingsPreferences;

  /// No description provided for @settingsReduceMotion.
  ///
  /// In en, this message translates to:
  /// **'Reduce motion'**
  String get settingsReduceMotion;

  /// No description provided for @settingsReduceMotionHint.
  ///
  /// In en, this message translates to:
  /// **'Turn off transitions and animations'**
  String get settingsReduceMotionHint;

  /// No description provided for @settingsServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get settingsServer;

  /// No description provided for @settingsServerNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get settingsServerNotConfigured;

  /// No description provided for @settingsServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get settingsServerUrl;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get settingsSignOut;

  /// No description provided for @settingsSignOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get settingsSignOutConfirm;

  /// No description provided for @settingsSignOutUnsynced.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change has} other{{count} changes have}} not synced yet and will be lost.'**
  String settingsSignOutUnsynced(int count);

  /// No description provided for @settingsTelegramConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get settingsTelegramConnected;

  /// No description provided for @settingsTelegramNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get settingsTelegramNotConfigured;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsTimezone.
  ///
  /// In en, this message translates to:
  /// **'Timezone'**
  String get settingsTimezone;

  /// Tooltip of the global add button
  ///
  /// In en, this message translates to:
  /// **'Quick add task'**
  String get shellQuickAdd;

  /// No description provided for @syncCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get syncCancel;

  /// No description provided for @syncDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get syncDiscard;

  /// No description provided for @syncDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'The change will be undone on this device and never sent to the server.'**
  String get syncDiscardBody;

  /// No description provided for @syncDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard this change?'**
  String get syncDiscardTitle;

  /// No description provided for @syncDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get syncDismiss;

  /// No description provided for @syncEntryFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed, will retry'**
  String get syncEntryFailed;

  /// No description provided for @syncEntryLine.
  ///
  /// In en, this message translates to:
  /// **'{state} - {count, plural, =1{1 attempt} other{{count} attempts}}'**
  String syncEntryLine(String state, int count);

  /// No description provided for @syncEntryPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get syncEntryPending;

  /// No description provided for @syncEntrySending.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get syncEntrySending;

  /// No description provided for @syncEntryStuck.
  ///
  /// In en, this message translates to:
  /// **'Stuck'**
  String get syncEntryStuck;

  /// No description provided for @syncLastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last synced {when}'**
  String syncLastSynced(String when);

  /// No description provided for @syncLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load queued changes: {error}'**
  String syncLoadError(String error);

  /// No description provided for @syncNoConflicts.
  ///
  /// In en, this message translates to:
  /// **'No conflicts to review.'**
  String get syncNoConflicts;

  /// No description provided for @syncNothingQueued.
  ///
  /// In en, this message translates to:
  /// **'Nothing queued. All changes are synced.'**
  String get syncNothingQueued;

  /// No description provided for @syncNoticeLine.
  ///
  /// In en, this message translates to:
  /// **'{entity}: {what} - {kept}'**
  String syncNoticeLine(String entity, String what, String kept);

  /// No description provided for @syncNoticeLocalKept.
  ///
  /// In en, this message translates to:
  /// **'your version kept'**
  String get syncNoticeLocalKept;

  /// No description provided for @syncNoticeServerKept.
  ///
  /// In en, this message translates to:
  /// **'server version kept'**
  String get syncNoticeServerKept;

  /// Used in place of a field name when a whole change was rolled back
  ///
  /// In en, this message translates to:
  /// **'change'**
  String get syncNoticeWholeChange;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @syncPhaseError.
  ///
  /// In en, this message translates to:
  /// **'Sync problem'**
  String get syncPhaseError;

  /// No description provided for @syncPhaseIdle.
  ///
  /// In en, this message translates to:
  /// **'Up to date'**
  String get syncPhaseIdle;

  /// No description provided for @syncPhaseOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get syncPhaseOffline;

  /// No description provided for @syncPhaseSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get syncPhaseSignedOut;

  /// No description provided for @syncPhaseSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing'**
  String get syncPhaseSyncing;

  /// No description provided for @syncQueuedChanges.
  ///
  /// In en, this message translates to:
  /// **'Queued changes'**
  String get syncQueuedChanges;

  /// No description provided for @syncRecentConflicts.
  ///
  /// In en, this message translates to:
  /// **'Recent conflicts'**
  String get syncRecentConflicts;

  /// No description provided for @syncRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get syncRetry;

  /// No description provided for @syncRetryAll.
  ///
  /// In en, this message translates to:
  /// **'Retry all'**
  String get syncRetryAll;

  /// No description provided for @syncStatusAllSynced.
  ///
  /// In en, this message translates to:
  /// **'All changes synced'**
  String get syncStatusAllSynced;

  /// No description provided for @syncStatusOfflineIdle.
  ///
  /// In en, this message translates to:
  /// **'Offline, nothing waiting to sync'**
  String get syncStatusOfflineIdle;

  /// No description provided for @syncStatusOfflineWaiting.
  ///
  /// In en, this message translates to:
  /// **'Offline, {count, plural, =1{1 change} other{{count} changes}} waiting to sync'**
  String syncStatusOfflineWaiting(int count);

  /// No description provided for @syncStatusProblem.
  ///
  /// In en, this message translates to:
  /// **'Sync problem, {count, plural, =1{1 change} other{{count} changes}} failed'**
  String syncStatusProblem(int count);

  /// No description provided for @syncStatusSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get syncStatusSignedOut;

  /// No description provided for @syncStatusSignedOutWaiting.
  ///
  /// In en, this message translates to:
  /// **'Signed out, {count, plural, =1{1 change} other{{count} changes}} waiting to sync'**
  String syncStatusSignedOutWaiting(int count);

  /// Screen-reader sync status
  ///
  /// In en, this message translates to:
  /// **'Syncing'**
  String get syncStatusSyncing;

  /// No description provided for @syncStatusWaiting.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change} other{{count} changes}} waiting to sync'**
  String syncStatusWaiting(int count);

  /// No description provided for @syncTimeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}} ago'**
  String syncTimeDaysAgo(int count);

  /// No description provided for @syncTimeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour} other{{count} hours}} ago'**
  String syncTimeHoursAgo(int count);

  /// No description provided for @syncTimeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get syncTimeJustNow;

  /// No description provided for @syncTimeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute} other{{count} minutes}} ago'**
  String syncTimeMinutesAgo(int count);

  /// No description provided for @syncTimeNever.
  ///
  /// In en, this message translates to:
  /// **'never'**
  String get syncTimeNever;

  /// No description provided for @syncTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get syncTitle;

  /// No description provided for @taskCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get taskCancel;

  /// No description provided for @taskDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get taskDelete;

  /// No description provided for @taskDetailCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get taskDetailCompleted;

  /// No description provided for @taskDetailDeferUntil.
  ///
  /// In en, this message translates to:
  /// **'Defer until'**
  String get taskDetailDeferUntil;

  /// No description provided for @taskDetailDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this task?'**
  String get taskDetailDeleteMessage;

  /// No description provided for @taskDetailDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Task'**
  String get taskDetailDeleteTitle;

  /// No description provided for @taskDetailDue.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get taskDetailDue;

  /// No description provided for @taskDetailEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get taskDetailEditTooltip;

  /// No description provided for @taskDetailMarkComplete.
  ///
  /// In en, this message translates to:
  /// **'Mark as Complete'**
  String get taskDetailMarkComplete;

  /// No description provided for @taskDetailMarkIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Mark as Incomplete'**
  String get taskDetailMarkIncomplete;

  /// No description provided for @taskDetailMenuTooltip.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get taskDetailMenuTooltip;

  /// Label of a meta row, followed by its value
  ///
  /// In en, this message translates to:
  /// **'{label}: '**
  String taskDetailMetaLabel(String label);

  /// No description provided for @taskDetailProject.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get taskDetailProject;

  /// No description provided for @taskDetailSubtasks.
  ///
  /// In en, this message translates to:
  /// **'Subtasks'**
  String get taskDetailSubtasks;

  /// Label of the area field
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get taskEditArea;

  /// Validation error of the form
  ///
  /// In en, this message translates to:
  /// **'Defer date must not be after the due date'**
  String get taskEditDeferAfterDue;

  /// Confirms discarding changes
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get taskEditDiscard;

  /// Body of the unsaved-changes dialog
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes that will be lost.'**
  String get taskEditDiscardBody;

  /// Title of the unsaved-changes dialog
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get taskEditDiscardTitle;

  /// Label of the due time field
  ///
  /// In en, this message translates to:
  /// **'Due time'**
  String get taskEditDueTime;

  /// Label of the time estimate field
  ///
  /// In en, this message translates to:
  /// **'Estimate'**
  String get taskEditEstimate;

  /// Validation error for the estimate
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number of minutes'**
  String get taskEditEstimateInvalid;

  /// Label of the estimate input
  ///
  /// In en, this message translates to:
  /// **'Estimate (minutes)'**
  String get taskEditEstimateLabel;

  /// Dismisses the unsaved-changes dialog
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get taskEditKeepEditing;

  /// Heading of the upcoming repeat dates
  ///
  /// In en, this message translates to:
  /// **'Next occurrences'**
  String get taskEditNextOccurrences;

  /// Shown when the note is empty
  ///
  /// In en, this message translates to:
  /// **'No notes'**
  String get taskEditNoNote;

  /// Chip shown on a task with local changes
  ///
  /// In en, this message translates to:
  /// **'Waiting to sync'**
  String get taskEditPendingSync;

  /// List of dates
  ///
  /// In en, this message translates to:
  /// **'{dates}'**
  String taskEditPreviewDates(String dates);

  /// Label of the day-of-month picker
  ///
  /// In en, this message translates to:
  /// **'Day of the month'**
  String get taskEditRecurDayOfMonth;

  /// Label of the recurrence end date
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get taskEditRecurEndDate;

  /// Ordinal for the nth weekday
  ///
  /// In en, this message translates to:
  /// **'First'**
  String get taskEditRecurFirst;

  /// Ordinal for the nth weekday
  ///
  /// In en, this message translates to:
  /// **'Fourth'**
  String get taskEditRecurFourth;

  /// Hint on the recurrence preview
  ///
  /// In en, this message translates to:
  /// **'Starting from {date}'**
  String taskEditRecurFrom(String date);

  /// Ordinal for the nth weekday
  ///
  /// In en, this message translates to:
  /// **'Last'**
  String get taskEditRecurLast;

  /// Validation error of the form
  ///
  /// In en, this message translates to:
  /// **'A repeating task needs a due date'**
  String get taskEditRecurNeedsDue;

  /// Shown when a recurrence has no end date
  ///
  /// In en, this message translates to:
  /// **'Never ends'**
  String get taskEditRecurNoEnd;

  /// Label of the nth-weekday picker
  ///
  /// In en, this message translates to:
  /// **'Which one'**
  String get taskEditRecurOrdinal;

  /// Heading of the recurrence preview
  ///
  /// In en, this message translates to:
  /// **'Next 5 occurrences'**
  String get taskEditRecurPreview;

  /// Shown when the rule yields no dates
  ///
  /// In en, this message translates to:
  /// **'No upcoming occurrences'**
  String get taskEditRecurPreviewEmpty;

  /// Ordinal for the nth weekday
  ///
  /// In en, this message translates to:
  /// **'Second'**
  String get taskEditRecurSecond;

  /// Tooltip that opens the recurrence editor
  ///
  /// In en, this message translates to:
  /// **'Change repeat'**
  String get taskEditRecurSummaryChange;

  /// Ordinal for the nth weekday
  ///
  /// In en, this message translates to:
  /// **'Third'**
  String get taskEditRecurThird;

  /// Title of the recurrence editor
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get taskEditRecurTitle;

  /// Label of the recurrence type
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get taskEditRecurType;

  /// Label of the weekday picker
  ///
  /// In en, this message translates to:
  /// **'Weekday'**
  String get taskEditRecurWeekdayLabel;

  /// Note about yearly recurrence
  ///
  /// In en, this message translates to:
  /// **'Yearly repeats are not supported by the server. Use monthly with an interval of 12 instead.'**
  String get taskEditRecurYearlyNote;

  /// Label of the reminder field
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get taskEditReminder;

  /// Action that picks a time
  ///
  /// In en, this message translates to:
  /// **'Set time'**
  String get taskEditSetTime;

  /// Skips one occurrence of a repeating task
  ///
  /// In en, this message translates to:
  /// **'Skip this occurrence'**
  String get taskEditSkipOccurrence;

  /// Snackbar after skipping an occurrence
  ///
  /// In en, this message translates to:
  /// **'Occurrence skipped'**
  String get taskEditSkipped;

  /// Tooltip of the add-subtask button
  ///
  /// In en, this message translates to:
  /// **'Add subtask'**
  String get taskEditSubtaskAdd;

  /// Tooltip of the delete-subtask button
  ///
  /// In en, this message translates to:
  /// **'Delete subtask'**
  String get taskEditSubtaskDelete;

  /// Hint of the subtask input
  ///
  /// In en, this message translates to:
  /// **'Add a subtask'**
  String get taskEditSubtaskHint;

  /// Progress of the subtasks
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} done'**
  String taskEditSubtaskProgress(int done, int total);

  /// Tooltip of the subtask drag handle
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get taskEditSubtaskReorder;

  /// Tooltip of the add-tag button
  ///
  /// In en, this message translates to:
  /// **'Add tag'**
  String get taskEditTagAdd;

  /// Hint of the tag input
  ///
  /// In en, this message translates to:
  /// **'Add a tag'**
  String get taskEditTagHint;

  /// Label of the tags field
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get taskEditTags;

  /// No description provided for @taskEmptyAll.
  ///
  /// In en, this message translates to:
  /// **'No tasks found.\nTap + to create one.'**
  String get taskEmptyAll;

  /// No description provided for @taskEmptyCompleted.
  ///
  /// In en, this message translates to:
  /// **'No completed tasks yet.'**
  String get taskEmptyCompleted;

  /// No description provided for @taskEmptyToday.
  ///
  /// In en, this message translates to:
  /// **'No tasks for today.\nEnjoy your free time! 🎉'**
  String get taskEmptyToday;

  /// No description provided for @taskErrorCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get taskErrorCancelled;

  /// No description provided for @taskErrorCsrf.
  ///
  /// In en, this message translates to:
  /// **'Security check failed. Please try again.'**
  String get taskErrorCsrf;

  /// No description provided for @taskErrorDecoding.
  ///
  /// In en, this message translates to:
  /// **'Unexpected response from the server'**
  String get taskErrorDecoding;

  /// No description provided for @taskErrorEmailNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Email address not verified'**
  String get taskErrorEmailNotVerified;

  /// No description provided for @taskErrorForbidden.
  ///
  /// In en, this message translates to:
  /// **'You are not allowed to do that'**
  String get taskErrorForbidden;

  /// No description provided for @taskErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get taskErrorGeneric;

  /// No description provided for @taskErrorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password'**
  String get taskErrorInvalidCredentials;

  /// No description provided for @taskErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection to the server'**
  String get taskErrorNetwork;

  /// No description provided for @taskErrorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Task not found'**
  String get taskErrorNotFound;

  /// No description provided for @taskErrorPasswordLoginDisabled.
  ///
  /// In en, this message translates to:
  /// **'Password login is disabled'**
  String get taskErrorPasswordLoginDisabled;

  /// No description provided for @taskErrorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Try again in a moment.'**
  String get taskErrorRateLimited;

  /// No description provided for @taskErrorServer.
  ///
  /// In en, this message translates to:
  /// **'Server error ({statusCode})'**
  String taskErrorServer(int statusCode);

  /// No description provided for @taskErrorTimeout.
  ///
  /// In en, this message translates to:
  /// **'The server took too long to respond'**
  String get taskErrorTimeout;

  /// No description provided for @taskErrorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Session expired. Please sign in again.'**
  String get taskErrorUnauthorized;

  /// No description provided for @taskFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get taskFilterAll;

  /// No description provided for @taskFilterCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get taskFilterCompleted;

  /// No description provided for @taskFilterSomeday.
  ///
  /// In en, this message translates to:
  /// **'Someday'**
  String get taskFilterSomeday;

  /// No description provided for @taskFilterToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get taskFilterToday;

  /// No description provided for @taskFilterUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get taskFilterUpcoming;

  /// No description provided for @taskFormClearTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get taskFormClearTooltip;

  /// No description provided for @taskFormCompletionBased.
  ///
  /// In en, this message translates to:
  /// **'Completion-based'**
  String get taskFormCompletionBased;

  /// No description provided for @taskFormCompletionBasedHint.
  ///
  /// In en, this message translates to:
  /// **'Repeat from completion date'**
  String get taskFormCompletionBasedHint;

  /// No description provided for @taskFormDeferUntil.
  ///
  /// In en, this message translates to:
  /// **'Defer Until'**
  String get taskFormDeferUntil;

  /// No description provided for @taskFormDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due Date'**
  String get taskFormDueDate;

  /// Prefix before the recurrence interval number
  ///
  /// In en, this message translates to:
  /// **'Every'**
  String get taskFormEvery;

  /// No description provided for @taskFormNameHint.
  ///
  /// In en, this message translates to:
  /// **'What needs to be done?'**
  String get taskFormNameHint;

  /// No description provided for @taskFormNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Task Name'**
  String get taskFormNameLabel;

  /// No description provided for @taskFormNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get taskFormNameRequired;

  /// No description provided for @taskFormNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get taskFormNone;

  /// No description provided for @taskFormNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get taskFormNotSet;

  /// No description provided for @taskFormNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Add details (Markdown supported)'**
  String get taskFormNoteHint;

  /// No description provided for @taskFormNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get taskFormNoteLabel;

  /// No description provided for @taskFormPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get taskFormPriority;

  /// No description provided for @taskFormProject.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get taskFormProject;

  /// Fallback when the chosen project's name is unknown
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get taskFormProjectSelected;

  /// No description provided for @taskFormRecurrence.
  ///
  /// In en, this message translates to:
  /// **'Recurrence'**
  String get taskFormRecurrence;

  /// No description provided for @taskFormSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get taskFormSave;

  /// No description provided for @taskFormStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get taskFormStatus;

  /// No description provided for @taskFormTitleEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Task'**
  String get taskFormTitleEdit;

  /// No description provided for @taskFormTitleNew.
  ///
  /// In en, this message translates to:
  /// **'New Task'**
  String get taskFormTitleNew;

  /// Unit after the recurrence interval
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{day} other{days}}'**
  String taskFormUnitDays(int count);

  /// Unit after the recurrence interval
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{month} other{months}}'**
  String taskFormUnitMonths(int count);

  /// Unit after the recurrence interval
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{week} other{weeks}}'**
  String taskFormUnitWeeks(int count);

  /// Title of the tasks screen
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get taskListTitle;

  /// Label of the create-task button
  ///
  /// In en, this message translates to:
  /// **'New Task'**
  String get taskNewButton;

  /// Task priority
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get taskPriorityHigh;

  /// Task priority
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get taskPriorityLow;

  /// Task priority
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get taskPriorityMedium;

  /// No description provided for @taskRecurDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get taskRecurDaily;

  /// No description provided for @taskRecurEveryDays.
  ///
  /// In en, this message translates to:
  /// **'Every {count} days'**
  String taskRecurEveryDays(int count);

  /// No description provided for @taskRecurEveryMonths.
  ///
  /// In en, this message translates to:
  /// **'Every {count} months'**
  String taskRecurEveryMonths(int count);

  /// No description provided for @taskRecurEveryWeeks.
  ///
  /// In en, this message translates to:
  /// **'Every {count} weeks'**
  String taskRecurEveryWeeks(int count);

  /// No description provided for @taskRecurMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get taskRecurMonthly;

  /// No description provided for @taskRecurMonthlyLastDay.
  ///
  /// In en, this message translates to:
  /// **'Monthly (last day)'**
  String get taskRecurMonthlyLastDay;

  /// No description provided for @taskRecurMonthlyWeekday.
  ///
  /// In en, this message translates to:
  /// **'Monthly (weekday)'**
  String get taskRecurMonthlyWeekday;

  /// No description provided for @taskRecurWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get taskRecurWeekly;

  /// No description provided for @taskRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get taskRetry;

  /// No description provided for @taskSortCreated.
  ///
  /// In en, this message translates to:
  /// **'Date Created'**
  String get taskSortCreated;

  /// No description provided for @taskSortDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due Date'**
  String get taskSortDueDate;

  /// No description provided for @taskSortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get taskSortName;

  /// No description provided for @taskSortPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get taskSortPriority;

  /// No description provided for @taskSortTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get taskSortTooltip;

  /// Task status
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get taskStatusArchived;

  /// Task status
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get taskStatusCancelled;

  /// Task status
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get taskStatusDone;

  /// Task status
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get taskStatusInProgress;

  /// Task status
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get taskStatusNotStarted;

  /// Task status
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get taskStatusPlanned;

  /// Task status the app does not recognise
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get taskStatusUnknown;

  /// Task status
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get taskStatusWaiting;

  /// Tooltip: switch to board view
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get taskViewBoard;

  /// Tooltip: switch to list view
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get taskViewList;

  /// Chip: task is blocked by another task
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get tileBlocked;

  /// Action: mark a task done
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get tileComplete;

  /// Accessibility: due date of a task
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String tileDueOn(String date);

  /// Action: open the task editor
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get tileEdit;

  /// Action: rename a task inline
  ///
  /// In en, this message translates to:
  /// **'Edit title'**
  String get tileEditTitle;

  /// Chip: estimated duration
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String tileEstimate(int minutes);

  /// Accessibility label of the note icon
  ///
  /// In en, this message translates to:
  /// **'Has a note'**
  String get tileHasNote;

  /// Tooltip of the task row overflow menu
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get tileMenu;

  /// Accessibility label of the +n tag chip
  ///
  /// In en, this message translates to:
  /// **'{count} more tags'**
  String tileMoreTags(int count);

  /// Due date chip of an overdue task
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 day overdue} other{{count} days overdue}}'**
  String tileOverdueDays(int count);

  /// Chip: how often a task was postponed
  ///
  /// In en, this message translates to:
  /// **'Postponed ×{count}'**
  String tilePostponedTimes(int count);

  /// Accessibility: priority of a task
  ///
  /// In en, this message translates to:
  /// **'Priority {priority}'**
  String tilePriorityLabel(String priority);

  /// Action: mark a done task open again
  ///
  /// In en, this message translates to:
  /// **'Reopen'**
  String get tileReopen;

  /// Accessibility label of the recurrence icon
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get tileRepeats;

  /// Action: start multi-select with this task
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get tileSelect;

  /// Accessibility state of a selected task row
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get tileSelected;

  /// Accessibility: subtask progress
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} subtasks done'**
  String tileSubtasksDone(int done, int total);

  /// Hint of the inline title field
  ///
  /// In en, this message translates to:
  /// **'Task title'**
  String get tileTitleHint;

  /// Duration in whole hours
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String todayDurationH(int hours);

  /// Duration with hours and minutes
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String todayDurationHm(int hours, int minutes);

  /// Duration in minutes
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String todayDurationM(int minutes);

  /// Empty state text
  ///
  /// In en, this message translates to:
  /// **'Nothing left on your plate. Enjoy the rest of the day.'**
  String get todayEmptyBody;

  /// Empty state title
  ///
  /// In en, this message translates to:
  /// **'All done for today'**
  String get todayEmptyTitle;

  /// Error state title
  ///
  /// In en, this message translates to:
  /// **'Could not load today\'s tasks'**
  String get todayErrorTitle;

  /// AppBar action
  ///
  /// In en, this message translates to:
  /// **'Focus mode'**
  String get todayFocus;

  /// Estimated time of the remaining tasks
  ///
  /// In en, this message translates to:
  /// **'{duration} left'**
  String todayMinutesLeft(String duration);

  /// Header text when no task has an estimate
  ///
  /// In en, this message translates to:
  /// **'No time estimates'**
  String get todayNoEstimate;

  /// Progress line in the Today header
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} done'**
  String todayProgress(int done, int total);

  /// Button on the overdue section
  ///
  /// In en, this message translates to:
  /// **'Reschedule all'**
  String get todayRescheduleAll;

  /// Retry button
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get todayRetry;

  /// AppBar action
  ///
  /// In en, this message translates to:
  /// **'Daily review'**
  String get todayReview;

  /// Disabled AppBar action
  ///
  /// In en, this message translates to:
  /// **'Search (coming soon)'**
  String get todaySearch;

  /// Today section: 12:00 to 17:59
  ///
  /// In en, this message translates to:
  /// **'Afternoon'**
  String get todaySectionAfternoon;

  /// Today section: tasks without a time
  ///
  /// In en, this message translates to:
  /// **'Anytime'**
  String get todaySectionAnytime;

  /// Today section
  ///
  /// In en, this message translates to:
  /// **'Completed today'**
  String get todaySectionCompleted;

  /// Today section: from 18:00
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get todaySectionEvening;

  /// Today section: before 12:00
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get todaySectionMorning;

  /// Today section
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get todaySectionOverdue;

  /// Tooltip of a section header
  ///
  /// In en, this message translates to:
  /// **'Show or hide {section}'**
  String todaySectionToggle(String section);

  /// Title of the Today screen
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayTitle;

  /// Snackbar action
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undoAction;

  /// Snackbar after completing tasks
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Task completed} other{{count} tasks completed}}'**
  String undoCompleted(int count);

  /// Snackbar after deleting tasks
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Task deleted} other{{count} tasks deleted}}'**
  String undoDeleted(int count);

  /// Snackbar after postponing tasks
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Task postponed} other{{count} tasks postponed}}'**
  String undoPostponed(int count);

  /// Snackbar after changing tasks
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Task updated} other{{count} tasks updated}}'**
  String undoUpdated(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
