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
