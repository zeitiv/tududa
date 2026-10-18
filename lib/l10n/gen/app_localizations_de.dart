// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appName => 'Tududa';

  @override
  String get areaAddTooltip => 'Neuer Bereich';

  @override
  String get areaCancel => 'Abbrechen';

  @override
  String get areaCreate => 'Erstellen';

  @override
  String get areaDeleteAction => 'Löschen';

  @override
  String get areaDeleteMessage =>
      'Projekte in diesem Bereich werden entkoppelt.';

  @override
  String get areaDeleteTitle => 'Bereich löschen';

  @override
  String get areaDescription => 'Beschreibung';

  @override
  String get areaDescriptionOptional => 'Beschreibung (optional)';

  @override
  String get areaEdit => 'Bereich bearbeiten';

  @override
  String get areaEditAction => 'Bearbeiten';

  @override
  String areaLoadError(String error) {
    return 'Fehler: $error';
  }

  @override
  String get areaName => 'Name';

  @override
  String get areaNameHint => 'z. B. Arbeit, Privat, Gesundheit';

  @override
  String get areaNew => 'Neuer Bereich';

  @override
  String get areaSave => 'Speichern';

  @override
  String get areasEmpty => 'Noch keine Bereiche';

  @override
  String get areasEmptyHint => 'Bereiche helfen dir, deine Projekte zu ordnen';

  @override
  String get areasTitle => 'Bereiche';

  @override
  String get authCancel => 'Abbrechen';

  @override
  String get authChangeServer => 'Server wechseln';

  @override
  String get authConnect => 'Verbinden';

  @override
  String get authConnectPrompt =>
      'Verbinde dich mit deinem selbst gehosteten Tududa-Server';

  @override
  String get authConnecting => 'Verbinde ...';

  @override
  String get authEmail => 'E-Mail';

  @override
  String get authEmailRequired => 'E-Mail ist erforderlich';

  @override
  String get authErrorEmailNotVerified =>
      'Deine E-Mail-Adresse ist noch nicht bestätigt. Prüfe deinen Posteingang auf den Bestätigungslink.';

  @override
  String get authErrorEnterServerUrl => 'Gib eine Serveradresse ein';

  @override
  String get authErrorGeneric => 'Etwas ist schiefgelaufen.';

  @override
  String get authErrorInsecure =>
      'Einfache HTTP-Verbindungen sind nicht verschlüsselt.';

  @override
  String get authErrorInvalidCredentials => 'E-Mail oder Passwort ist falsch.';

  @override
  String get authErrorInvalidServerUrl => 'Das ist keine gültige Adresse';

  @override
  String get authErrorNetwork =>
      'Der Server ist nicht erreichbar. Prüfe deine Verbindung und die Serveradresse.';

  @override
  String get authErrorPasswordLoginDisabled =>
      'Die Anmeldung per Passwort ist für dieses Konto deaktiviert. Es nutzt Single Sign-on (SSO), das diese App noch nicht unterstützt.';

  @override
  String get authErrorRateLimited =>
      'Zu viele Versuche. Versuche es später erneut.';

  @override
  String authErrorRateLimitedMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes Minuten',
      one: '1 Minute',
    );
    return 'Zu viele Versuche. Versuche es in $_temp0 erneut.';
  }

  @override
  String authErrorServer(String code) {
    return 'Auf dem Server ist ein Problem aufgetreten ($code). Versuche es später erneut.';
  }

  @override
  String get authHidePassword => 'Passwort verbergen';

  @override
  String get authInsecureBody =>
      'Diese Adresse verwendet kein HTTPS. Dein Passwort und deine Aufgaben würden unverschlüsselt übertragen und könnten im Netzwerk mitgelesen werden. Fahre nur in einem vertrauenswürdigen Netzwerk fort.';

  @override
  String get authInsecureConfirm => 'Unsicheres HTTP verwenden';

  @override
  String get authInsecureTitle => 'Unsicheres HTTP verwenden?';

  @override
  String get authInvalidEmail => 'Ungültige E-Mail-Adresse';

  @override
  String get authPassword => 'Passwort';

  @override
  String get authPasswordRequired => 'Passwort ist erforderlich';

  @override
  String get authServerUrl => 'Server-URL';

  @override
  String get authServerUrlHelper => 'Gib die Adresse deines Tududa-Servers ein';

  @override
  String get authServerUrlRequired => 'Bitte gib eine Server-URL ein';

  @override
  String get authShowPassword => 'Passwort anzeigen';

  @override
  String get authSignIn => 'Anmelden';

  @override
  String get authWelcome => 'Willkommen bei Tududa';

  @override
  String get commonAdd => 'Hinzufügen';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonClose => 'Schließen';

  @override
  String get commonConfirm => 'Bestätigen';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get commonEdit => 'Bearbeiten';

  @override
  String get commonError => 'Etwas ist schiefgelaufen';

  @override
  String get commonLoading => 'Wird geladen…';

  @override
  String get commonNone => 'Keine';

  @override
  String get commonRetry => 'Erneut versuchen';

  @override
  String get commonSave => 'Speichern';

  @override
  String get commonSearch => 'Suchen';

  @override
  String coreDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Tagen',
      one: 'vor 1 Tag',
    );
    return '$_temp0';
  }

  @override
  String coreInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count Tagen',
      one: 'in 1 Tag',
    );
    return '$_temp0';
  }

  @override
  String get coreToday => 'Heute';

  @override
  String get coreTomorrow => 'Morgen';

  @override
  String get coreYesterday => 'Gestern';

  @override
  String get inboxEmpty => 'Posteingang ist leer';

  @override
  String get inboxIgnore => 'Ignorieren';

  @override
  String get inboxMarkProcessed => 'Als erledigt markieren';

  @override
  String get inboxTelegramHint => 'Einträge aus Telegram erscheinen hier';

  @override
  String get kanbanNoTasks =>
      'Keine Aufgaben gefunden.\nTippe auf +, um eine zu erstellen.';

  @override
  String get kanbanStatusArchived => 'Archiviert';

  @override
  String get kanbanStatusCancelled => 'Abgebrochen';

  @override
  String get kanbanStatusDone => 'Erledigt';

  @override
  String get kanbanStatusInProgress => 'In Arbeit';

  @override
  String get kanbanStatusOther => 'Sonstige';

  @override
  String get kanbanStatusPlanned => 'Geplant';

  @override
  String get kanbanStatusToDo => 'Zu erledigen';

  @override
  String get kanbanStatusWaiting => 'Wartend';

  @override
  String get navInbox => 'Posteingang';

  @override
  String get navMore => 'Mehr';

  @override
  String get navNotes => 'Notizen';

  @override
  String get navProjects => 'Projekte';

  @override
  String get navTasks => 'Aufgaben';

  @override
  String get navToday => 'Heute';

  @override
  String get navUpcoming => 'Anstehend';

  @override
  String get noteColor => 'Farbe';

  @override
  String get noteContentHint =>
      'Halte deine Gedanken fest (Markdown wird unterstützt)';

  @override
  String get noteDeleteConfirm => 'Bist du sicher?';

  @override
  String get noteDeleteTitle => 'Notiz löschen';

  @override
  String get noteEdit => 'Notiz bearbeiten';

  @override
  String get noteEmpty =>
      'Noch keine Notizen.\nTippe auf +, um eine zu erstellen.';

  @override
  String get noteNew => 'Neue Notiz';

  @override
  String get noteProject => 'Projekt';

  @override
  String get noteSaveFailed => 'Notiz konnte nicht gespeichert werden';

  @override
  String get noteTitleHint => 'Titel der Notiz';

  @override
  String get projectAddTask => 'Aufgabe hinzufügen';

  @override
  String get projectArea => 'Bereich';

  @override
  String projectAreaLabel(String name) {
    return 'Bereich: $name';
  }

  @override
  String get projectCancel => 'Abbrechen';

  @override
  String get projectDelete => 'Löschen';

  @override
  String get projectDeleteMessage =>
      'Das Projekt und alle zugehörigen Aufgaben werden gelöscht.';

  @override
  String get projectDeleteTitle => 'Projekt löschen';

  @override
  String get projectDescription => 'Beschreibung';

  @override
  String get projectEdit => 'Projekt bearbeiten';

  @override
  String projectLoadError(String error) {
    return 'Fehler: $error';
  }

  @override
  String get projectName => 'Projektname';

  @override
  String get projectNameHint => 'Höchstens 6 Wörter';

  @override
  String get projectNameRequired => 'Name ist erforderlich';

  @override
  String get projectNew => 'Neues Projekt';

  @override
  String get projectNoArea => 'Kein Bereich';

  @override
  String get projectNotFound => 'Projekt nicht gefunden';

  @override
  String get projectPinSidebar => 'An Seitenleiste anheften';

  @override
  String get projectPinSidebarHint => 'Schneller Zugriff über die Navigation';

  @override
  String get projectPriority => 'Priorität';

  @override
  String get projectPriorityHigh => 'Hoch';

  @override
  String get projectPriorityLow => 'Niedrig';

  @override
  String get projectPriorityMedium => 'Mittel';

  @override
  String get projectPriorityNone => 'Keine';

  @override
  String get projectRetry => 'Erneut versuchen';

  @override
  String get projectSave => 'Speichern';

  @override
  String projectSaveFailed(String error) {
    return 'Projekt konnte nicht gespeichert werden: $error';
  }

  @override
  String get projectStatus => 'Status';

  @override
  String get projectStatusCancelled => 'Abgebrochen';

  @override
  String get projectStatusDone => 'Erledigt';

  @override
  String get projectStatusInProgress => 'In Arbeit';

  @override
  String get projectStatusNotStarted => 'Nicht begonnen';

  @override
  String get projectStatusPlanned => 'Geplant';

  @override
  String get projectStatusWaiting => 'Wartend';

  @override
  String projectTaskProgress(int done, int total) {
    return '$done/$total Aufgaben';
  }

  @override
  String get projectTasksHeading => 'Projektaufgaben';

  @override
  String get projectViewBoard => 'Board';

  @override
  String get projectViewList => 'Liste';

  @override
  String get projectsEmpty =>
      'Noch keine Projekte.\nTippe auf +, um eines zu erstellen.';

  @override
  String get projectsTitle => 'Projekte';

  @override
  String get settingsAbout => 'Über Tududa';

  @override
  String get settingsAboutSubtitle => 'v1.0.1 • Open Source';

  @override
  String get settingsAppearance => 'Darstellung';

  @override
  String get settingsAreas => 'Bereiche';

  @override
  String get settingsAreasDesc => 'Projekte in Bereiche gliedern';

  @override
  String get settingsCancel => 'Abbrechen';

  @override
  String get settingsContrast => 'Kontrast';

  @override
  String get settingsContrastHigh => 'Hoch';

  @override
  String get settingsContrastMedium => 'Mittel';

  @override
  String get settingsContrastStandard => 'Standard';

  @override
  String get settingsDensity => 'Dichte';

  @override
  String get settingsDensityComfortable => 'Komfortabel';

  @override
  String get settingsDensityCompact => 'Kompakt';

  @override
  String get settingsDynamicColor => 'Dynamische Farben';

  @override
  String get settingsDynamicColorHint =>
      'Farben aus dem Hintergrundbild verwenden, wenn verfügbar';

  @override
  String get settingsIntegrations => 'Integrationen';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get settingsLanguageSystem => 'Systemstandard';

  @override
  String get settingsMore => 'Mehr';

  @override
  String get settingsNavigation => 'Navigation';

  @override
  String get settingsPreferences => 'Einstellungen';

  @override
  String get settingsReduceMotion => 'Bewegung reduzieren';

  @override
  String get settingsReduceMotionHint =>
      'Übergänge und Animationen ausschalten';

  @override
  String get settingsServer => 'Server';

  @override
  String get settingsServerNotConfigured => 'Nicht eingerichtet';

  @override
  String get settingsServerUrl => 'Server-URL';

  @override
  String get settingsSignOut => 'Abmelden';

  @override
  String get settingsSignOutConfirm => 'Möchtest du dich wirklich abmelden?';

  @override
  String settingsSignOutUnsynced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Änderungen wurden',
      one: 'Eine Änderung wurde',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'gehen',
      one: 'geht',
    );
    return '$_temp0 noch nicht synchronisiert und $_temp1 verloren.';
  }

  @override
  String get settingsTelegramConnected => 'Verbunden';

  @override
  String get settingsTelegramNotConfigured => 'Nicht eingerichtet';

  @override
  String get settingsThemeDark => 'Dunkel';

  @override
  String get settingsThemeLight => 'Hell';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsTimezone => 'Zeitzone';

  @override
  String get shellQuickAdd => 'Aufgabe schnell hinzufügen';

  @override
  String get syncCancel => 'Abbrechen';

  @override
  String get syncDiscard => 'Verwerfen';

  @override
  String get syncDiscardBody =>
      'Die Änderung wird auf diesem Gerät rückgängig gemacht und nie an den Server gesendet.';

  @override
  String get syncDiscardTitle => 'Diese Änderung verwerfen?';

  @override
  String get syncDismiss => 'Ausblenden';

  @override
  String get syncEntryFailed => 'Fehlgeschlagen, neuer Versuch folgt';

  @override
  String syncEntryLine(String state, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Versuche',
      one: '1 Versuch',
    );
    return '$state - $_temp0';
  }

  @override
  String get syncEntryPending => 'Ausstehend';

  @override
  String get syncEntrySending => 'Wird gesendet';

  @override
  String get syncEntryStuck => 'Hängt fest';

  @override
  String syncLastSynced(String when) {
    return 'Zuletzt synchronisiert: $when';
  }

  @override
  String syncLoadError(String error) {
    return 'Wartende Änderungen konnten nicht geladen werden: $error';
  }

  @override
  String get syncNoConflicts => 'Keine Konflikte zu prüfen.';

  @override
  String get syncNothingQueued =>
      'Nichts in der Warteschlange. Alle Änderungen sind synchronisiert.';

  @override
  String syncNoticeLine(String entity, String what, String kept) {
    return '$entity: $what - $kept';
  }

  @override
  String get syncNoticeLocalKept => 'Deine Version behalten';

  @override
  String get syncNoticeServerKept => 'Serverversion behalten';

  @override
  String get syncNoticeWholeChange => 'Änderung';

  @override
  String get syncNow => 'Jetzt synchronisieren';

  @override
  String get syncPhaseError => 'Synchronisierungsproblem';

  @override
  String get syncPhaseIdle => 'Aktuell';

  @override
  String get syncPhaseOffline => 'Offline';

  @override
  String get syncPhaseSignedOut => 'Abgemeldet';

  @override
  String get syncPhaseSyncing => 'Synchronisiere';

  @override
  String get syncQueuedChanges => 'Wartende Änderungen';

  @override
  String get syncRecentConflicts => 'Letzte Konflikte';

  @override
  String get syncRetry => 'Wiederholen';

  @override
  String get syncRetryAll => 'Alle wiederholen';

  @override
  String get syncStatusAllSynced => 'Alle Änderungen synchronisiert';

  @override
  String get syncStatusOfflineIdle =>
      'Offline, nichts wartet auf Synchronisierung';

  @override
  String syncStatusOfflineWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Änderungen warten',
      one: '1 Änderung wartet',
    );
    return 'Offline, $_temp0 auf Synchronisierung';
  }

  @override
  String syncStatusProblem(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Änderungen',
      one: '1 Änderung',
    );
    return 'Synchronisierungsproblem, $_temp0 fehlgeschlagen';
  }

  @override
  String get syncStatusSignedOut => 'Abgemeldet';

  @override
  String syncStatusSignedOutWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Änderungen warten',
      one: '1 Änderung wartet',
    );
    return 'Abgemeldet, $_temp0 auf Synchronisierung';
  }

  @override
  String get syncStatusSyncing => 'Synchronisiere';

  @override
  String syncStatusWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Änderungen warten',
      one: '1 Änderung wartet',
    );
    return '$_temp0 auf Synchronisierung';
  }

  @override
  String syncTimeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tagen',
      one: '1 Tag',
    );
    return 'vor $_temp0';
  }

  @override
  String syncTimeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Stunden',
      one: '1 Stunde',
    );
    return 'vor $_temp0';
  }

  @override
  String get syncTimeJustNow => 'gerade eben';

  @override
  String syncTimeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Minuten',
      one: '1 Minute',
    );
    return 'vor $_temp0';
  }

  @override
  String get syncTimeNever => 'nie';

  @override
  String get syncTitle => 'Synchronisierung';

  @override
  String get taskCancel => 'Abbrechen';

  @override
  String get taskDelete => 'Löschen';

  @override
  String get taskDetailCompleted => 'Erledigt';

  @override
  String get taskDetailDeferUntil => 'Zurückgestellt bis';

  @override
  String get taskDetailDeleteMessage =>
      'Möchtest du diese Aufgabe wirklich löschen?';

  @override
  String get taskDetailDeleteTitle => 'Aufgabe löschen';

  @override
  String get taskDetailDue => 'Fällig';

  @override
  String get taskDetailEditTooltip => 'Bearbeiten';

  @override
  String get taskDetailMarkComplete => 'Als erledigt markieren';

  @override
  String get taskDetailMarkIncomplete => 'Als unerledigt markieren';

  @override
  String get taskDetailMenuTooltip => 'Weitere Aktionen';

  @override
  String taskDetailMetaLabel(String label) {
    return '$label: ';
  }

  @override
  String get taskDetailProject => 'Projekt';

  @override
  String get taskDetailSubtasks => 'Unteraufgaben';

  @override
  String get taskEmptyAll =>
      'Keine Aufgaben gefunden.\nTippe auf +, um eine zu erstellen.';

  @override
  String get taskEmptyCompleted => 'Noch keine erledigten Aufgaben.';

  @override
  String get taskEmptyToday =>
      'Heute keine Aufgaben.\nGenieße deine freie Zeit! 🎉';

  @override
  String get taskErrorCancelled => 'Abgebrochen';

  @override
  String get taskErrorCsrf =>
      'Sicherheitsprüfung fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String get taskErrorDecoding => 'Unerwartete Antwort vom Server';

  @override
  String get taskErrorEmailNotVerified => 'E-Mail-Adresse nicht bestätigt';

  @override
  String get taskErrorForbidden => 'Dazu hast du keine Berechtigung';

  @override
  String get taskErrorGeneric => 'Etwas ist schiefgelaufen';

  @override
  String get taskErrorInvalidCredentials =>
      'Ungültige E-Mail oder ungültiges Passwort';

  @override
  String get taskErrorNetwork => 'Keine Verbindung zum Server';

  @override
  String get taskErrorNotFound => 'Aufgabe nicht gefunden';

  @override
  String get taskErrorPasswordLoginDisabled =>
      'Die Anmeldung per Passwort ist deaktiviert';

  @override
  String get taskErrorRateLimited =>
      'Zu viele Anfragen. Versuche es gleich noch einmal.';

  @override
  String taskErrorServer(int statusCode) {
    return 'Serverfehler ($statusCode)';
  }

  @override
  String get taskErrorTimeout => 'Der Server hat zu lange nicht geantwortet';

  @override
  String get taskErrorUnauthorized =>
      'Sitzung abgelaufen. Bitte melde dich erneut an.';

  @override
  String get taskFilterAll => 'Alle';

  @override
  String get taskFilterCompleted => 'Erledigt';

  @override
  String get taskFilterSomeday => 'Irgendwann';

  @override
  String get taskFilterToday => 'Heute';

  @override
  String get taskFilterUpcoming => 'Anstehend';

  @override
  String get taskFormClearTooltip => 'Zurücksetzen';

  @override
  String get taskFormCompletionBased => 'Nach Erledigung';

  @override
  String get taskFormCompletionBasedHint =>
      'Ab dem Erledigungsdatum wiederholen';

  @override
  String get taskFormDeferUntil => 'Zurückstellen bis';

  @override
  String get taskFormDueDate => 'Fälligkeitsdatum';

  @override
  String get taskFormEvery => 'Alle';

  @override
  String get taskFormNameHint => 'Was ist zu tun?';

  @override
  String get taskFormNameLabel => 'Aufgabenname';

  @override
  String get taskFormNameRequired => 'Name ist erforderlich';

  @override
  String get taskFormNone => 'Keine';

  @override
  String get taskFormNotSet => 'Nicht festgelegt';

  @override
  String get taskFormNoteHint => 'Details hinzufügen (Markdown unterstützt)';

  @override
  String get taskFormNoteLabel => 'Notizen';

  @override
  String get taskFormPriority => 'Priorität';

  @override
  String get taskFormProject => 'Projekt';

  @override
  String get taskFormProjectSelected => 'Ausgewählt';

  @override
  String get taskFormRecurrence => 'Wiederholung';

  @override
  String get taskFormSave => 'Speichern';

  @override
  String get taskFormStatus => 'Status';

  @override
  String get taskFormTitleEdit => 'Aufgabe bearbeiten';

  @override
  String get taskFormTitleNew => 'Neue Aufgabe';

  @override
  String taskFormUnitDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tage',
      one: 'Tag',
    );
    return '$_temp0';
  }

  @override
  String taskFormUnitMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Monate',
      one: 'Monat',
    );
    return '$_temp0';
  }

  @override
  String taskFormUnitWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Wochen',
      one: 'Woche',
    );
    return '$_temp0';
  }

  @override
  String get taskListTitle => 'Aufgaben';

  @override
  String get taskNewButton => 'Neue Aufgabe';

  @override
  String get taskPriorityHigh => 'Hoch';

  @override
  String get taskPriorityLow => 'Niedrig';

  @override
  String get taskPriorityMedium => 'Mittel';

  @override
  String get taskRecurDaily => 'Täglich';

  @override
  String taskRecurEveryDays(int count) {
    return 'Alle $count Tage';
  }

  @override
  String taskRecurEveryMonths(int count) {
    return 'Alle $count Monate';
  }

  @override
  String taskRecurEveryWeeks(int count) {
    return 'Alle $count Wochen';
  }

  @override
  String get taskRecurMonthly => 'Monatlich';

  @override
  String get taskRecurMonthlyLastDay => 'Monatlich (letzter Tag)';

  @override
  String get taskRecurMonthlyWeekday => 'Monatlich (Wochentag)';

  @override
  String get taskRecurWeekly => 'Wöchentlich';

  @override
  String get taskRetry => 'Erneut versuchen';

  @override
  String get taskSortCreated => 'Erstellungsdatum';

  @override
  String get taskSortDueDate => 'Fälligkeitsdatum';

  @override
  String get taskSortName => 'Name';

  @override
  String get taskSortPriority => 'Priorität';

  @override
  String get taskSortTooltip => 'Sortieren';

  @override
  String get taskStatusArchived => 'Archiviert';

  @override
  String get taskStatusCancelled => 'Abgebrochen';

  @override
  String get taskStatusDone => 'Erledigt';

  @override
  String get taskStatusInProgress => 'In Arbeit';

  @override
  String get taskStatusNotStarted => 'Nicht begonnen';

  @override
  String get taskStatusPlanned => 'Geplant';

  @override
  String get taskStatusUnknown => 'Unbekannt';

  @override
  String get taskStatusWaiting => 'Wartend';

  @override
  String get taskViewBoard => 'Board';

  @override
  String get taskViewList => 'Liste';
}
