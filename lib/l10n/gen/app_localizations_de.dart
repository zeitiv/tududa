// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get a11yNoteColorNone => 'Keine Farbe';

  @override
  String a11yNoteColorOption(int index, int count) {
    return 'Farbe $index von $count';
  }

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
  String get asyncStateErrorTitle => 'Etwas ist schiefgelaufen';

  @override
  String get asyncStateLoading => 'Wird geladen';

  @override
  String get asyncStateOfflineHint =>
      'Auf diesem Gerät ist noch nichts gespeichert. Verbinde dich, um Daten zu laden.';

  @override
  String get asyncStateOfflineTitle => 'Du bist offline';

  @override
  String get asyncStateRetry => 'Erneut versuchen';

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
  String get bulkClear => 'Auswahl aufheben';

  @override
  String get bulkComplete => 'Erledigen';

  @override
  String get bulkDelete => 'Löschen';

  @override
  String get bulkMoveProject => 'In Projekt verschieben';

  @override
  String get bulkNoProject => 'Kein Projekt';

  @override
  String get bulkPostpone => 'Verschieben';

  @override
  String get bulkPriority => 'Priorität';

  @override
  String bulkSelectedCount(int count) {
    return '$count ausgewählt';
  }

  @override
  String get bulkTag => 'Tag setzen';

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
  String get focusBack => 'Zurück zu Heute';

  @override
  String get focusDone => 'Erledigt';

  @override
  String get focusEmptyBody => 'Für heute sind keine Aufgaben mehr offen.';

  @override
  String get focusEmptyTitle => 'Nichts zu tun';

  @override
  String focusPosition(int index, int total) {
    return '$index von $total';
  }

  @override
  String get focusPostpone => 'Verschieben';

  @override
  String get focusSkip => 'Überspringen';

  @override
  String get focusSubtasks => 'Unteraufgaben';

  @override
  String get focusTitle => 'Fokus';

  @override
  String get inboxEmpty => 'Posteingang ist leer';

  @override
  String get inboxIgnore => 'Ignorieren';

  @override
  String get inboxMarkProcessed => 'Als erledigt markieren';

  @override
  String get inboxTelegramHint => 'Einträge aus Telegram erscheinen hier';

  @override
  String inboxV2AgeDays(int count) {
    return 'vor $count Tg.';
  }

  @override
  String inboxV2AgeHours(int count) {
    return 'vor $count Std.';
  }

  @override
  String inboxV2AgeMinutes(int count) {
    return 'vor $count Min.';
  }

  @override
  String get inboxV2AgeNow => 'Gerade eben';

  @override
  String get inboxV2CaptureFailed => 'Eintrag konnte nicht gespeichert werden';

  @override
  String get inboxV2CaptureHint => 'Gedanken, Link oder Idee festhalten…';

  @override
  String get inboxV2CaptureSend => 'Zum Posteingang hinzufügen';

  @override
  String get inboxV2ConvertNote => 'In Notiz umwandeln';

  @override
  String get inboxV2ConvertTask => 'In Aufgabe umwandeln';

  @override
  String get inboxV2Deleted => 'Eintrag gelöscht';

  @override
  String get inboxV2EmptyHint =>
      'Erfasse oben etwas oder sende es über Telegram';

  @override
  String get inboxV2Ignored => 'Ignoriert';

  @override
  String get inboxV2ItemActions => 'Weitere Aktionen';

  @override
  String get inboxV2LoadFailed => 'Posteingang konnte nicht geladen werden';

  @override
  String get inboxV2MarkedProcessed => 'Als erledigt markiert';

  @override
  String get inboxV2OpenNote => 'Öffnen';

  @override
  String get inboxV2SavedAsNote => 'Als Notiz gespeichert';

  @override
  String get inboxV2Undo => 'Rückgängig';

  @override
  String get inboxV2UnsortedHint => 'Gib ihnen ein Projekt oder ein Datum';

  @override
  String get inboxV2UnsortedTasks => 'Aufgaben ohne Projekt oder Datum';

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
  String kanbanV2ColumnSummary(String status, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben',
      one: '1 Aufgabe',
    );
    return '$status, $_temp0';
  }

  @override
  String get kanbanV2CurrentColumn => 'Aktuell';

  @override
  String get kanbanV2DropHere => 'Hier ablegen';

  @override
  String get kanbanV2EmptyColumn => 'Nichts hier';

  @override
  String get kanbanV2MoveTo => 'Verschieben nach…';

  @override
  String kanbanV2MoveToStatus(String status) {
    return 'Verschieben nach $status';
  }

  @override
  String kanbanV2Moved(String status) {
    return 'Verschoben nach $status';
  }

  @override
  String get listAllTasks => 'Alle Aufgaben';

  @override
  String get listComingSoon => 'Demnächst';

  @override
  String get listEmptyCompletedHint =>
      'Erledigte Aufgaben bleiben hier 30 Tage erhalten.';

  @override
  String get listEmptyCompletedTitle => 'Noch nichts erledigt';

  @override
  String get listEmptyOverdueHint => 'Keine Aufgabe ist überfällig.';

  @override
  String get listEmptyOverdueTitle => 'Alles erledigt';

  @override
  String get listEmptySomedayHint =>
      'Aufgaben ohne Fälligkeitsdatum stehen hier.';

  @override
  String get listEmptySomedayTitle => 'Keine Irgendwann-Aufgaben';

  @override
  String get listEmptyUpcomingHint =>
      'Aufgaben der nächsten 7 Tage erscheinen hier.';

  @override
  String get listEmptyUpcomingTitle => 'Nichts geplant';

  @override
  String get listLoadMore => 'Mehr laden';

  @override
  String get listMoreSection => 'Listen & mehr';

  @override
  String get listNoDate => 'Ohne Datum';

  @override
  String get listOverdue => 'Überfällig';

  @override
  String get listRescheduleAll => 'Alle auf heute verschieben';

  @override
  String listRescheduled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben auf heute verschoben',
      one: '1 Aufgabe auf heute verschoben',
    );
    return '$_temp0';
  }

  @override
  String get listTags => 'Tags';

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
  String get noteV2ClearSearch => 'Suche löschen';

  @override
  String get noteV2Discard => 'Verwerfen';

  @override
  String get noteV2DiscardBody =>
      'Nicht gespeicherte Änderungen gehen verloren.';

  @override
  String get noteV2DiscardTitle => 'Änderungen verwerfen?';

  @override
  String get noteV2KeepEditing => 'Weiter bearbeiten';

  @override
  String get noteV2ModeEdit => 'Bearbeiten';

  @override
  String get noteV2ModePreview => 'Vorschau';

  @override
  String get noteV2NoResults => 'Keine Notizen passen zur Suche';

  @override
  String get noteV2PreviewEmpty => 'Noch nichts zur Vorschau';

  @override
  String get noteV2Search => 'Notizen durchsuchen';

  @override
  String get noteV2Tags => 'Tags';

  @override
  String get noteV2Untitled => 'Ohne Titel';

  @override
  String get noteV2ViewGrid => 'Rasteransicht';

  @override
  String get noteV2ViewList => 'Listenansicht';

  @override
  String get paletteAddTask => 'Aufgabe hinzufügen';

  @override
  String get paletteChangeTheme => 'Design wechseln';

  @override
  String get paletteEmpty => 'Keine passenden Befehle';

  @override
  String get paletteGoAreas => 'Gehe zu Bereiche';

  @override
  String get paletteGoCompleted => 'Gehe zu Erledigt';

  @override
  String get paletteGoInbox => 'Gehe zu Eingang';

  @override
  String get paletteGoNotes => 'Gehe zu Notizen';

  @override
  String get paletteGoOverdue => 'Gehe zu Überfällig';

  @override
  String get paletteGoProjects => 'Gehe zu Projekte';

  @override
  String get paletteGoSettings => 'Gehe zu Einstellungen';

  @override
  String get paletteGoSomeday => 'Gehe zu Irgendwann';

  @override
  String get paletteGoSync => 'Gehe zu Synchronisierung';

  @override
  String get paletteGoToday => 'Gehe zu Heute';

  @override
  String get paletteGoUpcoming => 'Gehe zu Anstehend';

  @override
  String get paletteHint => 'Befehl eingeben oder suchen…';

  @override
  String paletteItemPosition(String label, int index, int total) {
    return '$label, $index von $total';
  }

  @override
  String get paletteKindNote => 'Notiz';

  @override
  String get paletteKindProject => 'Projekt';

  @override
  String get paletteKindTask => 'Aufgabe';

  @override
  String paletteResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ergebnisse',
      one: '1 Ergebnis',
    );
    return '$_temp0';
  }

  @override
  String get paletteRunSync => 'Jetzt synchronisieren';

  @override
  String get paletteSearch => 'Suchen';

  @override
  String get paletteTitle => 'Befehlspalette';

  @override
  String get paletteToggleReduceMotion => 'Bewegung reduzieren umschalten';

  @override
  String get postponeNextWeek => 'Nächste Woche';

  @override
  String get postponePickDate => 'Datum wählen …';

  @override
  String get postponeSkipOccurrence => 'Diesen Termin überspringen';

  @override
  String get postponeSomeday => 'Irgendwann (ohne Datum)';

  @override
  String get postponeTitle => 'Verschieben';

  @override
  String get postponeTomorrow => 'Morgen';

  @override
  String get postponeWeekend => 'Dieses Wochenende';

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
  String get quickAddAddAnother => 'Weitere hinzufügen';

  @override
  String quickAddAdded(String name) {
    return '$name hinzugefügt';
  }

  @override
  String get quickAddApply => 'Übernehmen';

  @override
  String get quickAddClose => 'Schließen';

  @override
  String get quickAddHint => 'Aufgabe, z. B. Miete zahlen jeden Monat !!';

  @override
  String get quickAddInlineHint => 'Aufgabe hinzufügen';

  @override
  String get quickAddKeepAsText => 'Tippen, um als Text zu behalten';

  @override
  String get quickAddMoreOptions => 'Mehr Optionen';

  @override
  String quickAddNextOccurrences(String dates) {
    return 'Nächste: $dates';
  }

  @override
  String get quickAddNone => 'Keine';

  @override
  String get quickAddNoteHint => 'Notiz hinzufügen';

  @override
  String get quickAddPickArea => 'Bereich';

  @override
  String get quickAddPickDate => 'Fälligkeitsdatum';

  @override
  String get quickAddPickNote => 'Notiz';

  @override
  String get quickAddPickPriority => 'Priorität';

  @override
  String get quickAddPickProject => 'Projekt';

  @override
  String get quickAddPickRepeat => 'Wiederholen';

  @override
  String get quickAddPickTags => 'Tags';

  @override
  String get quickAddPickTime => 'Uhrzeit';

  @override
  String get quickAddRecurAfterCompletion => 'nach Erledigung';

  @override
  String quickAddRecurDaily(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alle $count Tage',
      one: 'Jeden Tag',
    );
    return '$_temp0';
  }

  @override
  String quickAddRecurMonthly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alle $count Monate',
      one: 'Jeden Monat',
    );
    return '$_temp0';
  }

  @override
  String get quickAddRecurMonthlyLastDay => 'Letzter Tag jedes Monats';

  @override
  String quickAddRecurMonthlyOnDay(int count, int day) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alle $count Monate am $day.',
      one: 'Monatlich am $day.',
    );
    return '$_temp0';
  }

  @override
  String quickAddRecurMonthlyWeekday(String week, String weekday) {
    String _temp0 = intl.Intl.selectLogic(week, {
      '1': 'ersten',
      '2': 'zweiten',
      '3': 'dritten',
      '4': 'vierten',
      'other': 'letzten',
    });
    return 'Jeden $_temp0 $weekday im Monat';
  }

  @override
  String quickAddRecurUntil(String date) {
    return 'bis $date';
  }

  @override
  String get quickAddRecurWeekdays => 'Jeden Werktag';

  @override
  String quickAddRecurWeekly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alle $count Wochen',
      one: 'Jede Woche',
    );
    return '$_temp0';
  }

  @override
  String quickAddRecurWeeklyOn(int count, String days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alle $count Wochen am $days',
      one: 'Jede Woche am $days',
    );
    return '$_temp0';
  }

  @override
  String get quickAddRepeatNone => 'Wiederholt sich nicht';

  @override
  String get quickAddSubmit => 'Aufgabe hinzufügen';

  @override
  String get quickAddTagHint => 'Tag hinzufügen';

  @override
  String get quickAddTitle => 'Schnell hinzufügen';

  @override
  String get quickAddUndo => 'Rückgängig';

  @override
  String get quickAddYearlyUnsupported =>
      'Jährliche Wiederholungen werden von Tududi nicht unterstützt.';

  @override
  String get reviewClose => 'Zurück zu Heute';

  @override
  String get reviewDone => 'Erledigt';

  @override
  String get reviewKeep => 'Behalten';

  @override
  String get reviewPickDate => 'Datum wählen';

  @override
  String reviewProgress(int index, int total) {
    return 'Aufgabe $index von $total';
  }

  @override
  String get reviewSomeday => 'Irgendwann';

  @override
  String reviewSummaryDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben erledigt',
      one: '$count Aufgabe erledigt',
    );
    return '$_temp0';
  }

  @override
  String get reviewSummaryEmpty => 'Keine offenen Aufgaben zum Durchsehen.';

  @override
  String reviewSummaryKept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben behalten',
      one: '$count Aufgabe behalten',
    );
    return '$_temp0';
  }

  @override
  String reviewSummaryMoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben verschoben',
      one: '$count Aufgabe verschoben',
    );
    return '$_temp0';
  }

  @override
  String reviewSummarySomeday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben auf Irgendwann gesetzt',
      one: '$count Aufgabe auf Irgendwann gesetzt',
    );
    return '$_temp0';
  }

  @override
  String get reviewSummaryTitle => 'Rückblick abgeschlossen';

  @override
  String get reviewTitle => 'Tagesrückblick';

  @override
  String get reviewTomorrow => 'Morgen';

  @override
  String get searchClear => 'Löschen';

  @override
  String get searchError => 'Suche fehlgeschlagen';

  @override
  String get searchHint => 'Aufgaben, Projekte, Notizen suchen';

  @override
  String get searchIntro =>
      'Nach Namen suchen oder #tag, +projekt, ~bereich, is:overdue, priority:high verwenden';

  @override
  String searchNoResults(String query) {
    return 'Keine Ergebnisse für „$query“';
  }

  @override
  String get searchOfflineBanner => 'Offline-Ergebnisse werden angezeigt';

  @override
  String get searchRecent => 'Letzte Suchen';

  @override
  String get searchRecentClear => 'Alle löschen';

  @override
  String get searchRemoveRecent => 'Aus letzten Suchen entfernen';

  @override
  String get searchRetry => 'Erneut versuchen';

  @override
  String get searchTitle => 'Suche';

  @override
  String get searchTypeAll => 'Alle';

  @override
  String get searchTypeAreas => 'Bereiche';

  @override
  String get searchTypeNotes => 'Notizen';

  @override
  String get searchTypeProjects => 'Projekte';

  @override
  String get searchTypeTags => 'Tags';

  @override
  String get searchTypeTasks => 'Aufgaben';

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
  String get taskEditArea => 'Bereich';

  @override
  String get taskEditDeferAfterDue =>
      'Zurückstellen darf nicht nach dem Fälligkeitsdatum liegen';

  @override
  String get taskEditDiscard => 'Verwerfen';

  @override
  String get taskEditDiscardBody =>
      'Nicht gespeicherte Änderungen gehen verloren.';

  @override
  String get taskEditDiscardTitle => 'Änderungen verwerfen?';

  @override
  String get taskEditDueTime => 'Fälligkeitszeit';

  @override
  String get taskEditEstimate => 'Schätzung';

  @override
  String get taskEditEstimateInvalid => 'Ganze Minutenzahl eingeben';

  @override
  String get taskEditEstimateLabel => 'Schätzung (Minuten)';

  @override
  String get taskEditKeepEditing => 'Weiter bearbeiten';

  @override
  String get taskEditNextOccurrences => 'Nächste Termine';

  @override
  String get taskEditNoNote => 'Keine Notizen';

  @override
  String get taskEditPendingSync => 'Wartet auf Synchronisierung';

  @override
  String taskEditPreviewDates(String dates) {
    return '$dates';
  }

  @override
  String get taskEditRecurDayOfMonth => 'Tag des Monats';

  @override
  String get taskEditRecurEndDate => 'Enddatum';

  @override
  String get taskEditRecurFirst => 'Erster';

  @override
  String get taskEditRecurFourth => 'Vierter';

  @override
  String taskEditRecurFrom(String date) {
    return 'Ab $date';
  }

  @override
  String get taskEditRecurLast => 'Letzter';

  @override
  String get taskEditRecurNeedsDue =>
      'Eine wiederkehrende Aufgabe braucht ein Fälligkeitsdatum';

  @override
  String get taskEditRecurNoEnd => 'Endet nie';

  @override
  String get taskEditRecurOrdinal => 'Welcher';

  @override
  String get taskEditRecurPreview => 'Nächste 5 Termine';

  @override
  String get taskEditRecurPreviewEmpty => 'Keine weiteren Termine';

  @override
  String get taskEditRecurSecond => 'Zweiter';

  @override
  String get taskEditRecurSummaryChange => 'Wiederholung ändern';

  @override
  String get taskEditRecurThird => 'Dritter';

  @override
  String get taskEditRecurTitle => 'Wiederholen';

  @override
  String get taskEditRecurType => 'Wiederholung';

  @override
  String get taskEditRecurWeekdayLabel => 'Wochentag';

  @override
  String get taskEditRecurYearlyNote =>
      'Jährliche Wiederholungen werden vom Server nicht unterstützt. Nutze stattdessen monatlich mit Intervall 12.';

  @override
  String get taskEditReminder => 'Erinnerung';

  @override
  String get taskEditSetTime => 'Zeit festlegen';

  @override
  String get taskEditSkipOccurrence => 'Diesen Termin überspringen';

  @override
  String get taskEditSkipped => 'Termin übersprungen';

  @override
  String get taskEditSubtaskAdd => 'Teilaufgabe hinzufügen';

  @override
  String get taskEditSubtaskDelete => 'Teilaufgabe löschen';

  @override
  String get taskEditSubtaskHint => 'Teilaufgabe hinzufügen';

  @override
  String taskEditSubtaskProgress(int done, int total) {
    return '$done von $total erledigt';
  }

  @override
  String get taskEditSubtaskReorder => 'Zum Sortieren ziehen';

  @override
  String get taskEditTagAdd => 'Tag hinzufügen';

  @override
  String get taskEditTagHint => 'Tag hinzufügen';

  @override
  String get taskEditTags => 'Tags';

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

  @override
  String get tileBlocked => 'Blockiert';

  @override
  String get tileComplete => 'Erledigen';

  @override
  String tileDueOn(String date) {
    return 'Fällig $date';
  }

  @override
  String get tileEdit => 'Bearbeiten';

  @override
  String get tileEditTitle => 'Titel bearbeiten';

  @override
  String tileEstimate(int minutes) {
    return '$minutes Min.';
  }

  @override
  String get tileHasNote => 'Hat eine Notiz';

  @override
  String get tileMenu => 'Weitere Aktionen';

  @override
  String tileMoreTags(int count) {
    return '$count weitere Tags';
  }

  @override
  String tileOverdueDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage überfällig',
      one: '1 Tag überfällig',
    );
    return '$_temp0';
  }

  @override
  String tilePostponedTimes(int count) {
    return '$count× verschoben';
  }

  @override
  String tilePriorityLabel(String priority) {
    return 'Priorität $priority';
  }

  @override
  String get tileReopen => 'Wieder öffnen';

  @override
  String get tileRepeats => 'Wiederholt sich';

  @override
  String get tileSelect => 'Auswählen';

  @override
  String get tileSelected => 'Ausgewählt';

  @override
  String tileSubtasksDone(int done, int total) {
    return '$done von $total Teilaufgaben erledigt';
  }

  @override
  String get tileTitleHint => 'Aufgabentitel';

  @override
  String todayDurationH(int hours) {
    return '$hours Std.';
  }

  @override
  String todayDurationHm(int hours, int minutes) {
    return '$hours Std. $minutes Min.';
  }

  @override
  String todayDurationM(int minutes) {
    return '$minutes Min.';
  }

  @override
  String get todayEmptyBody => 'Nichts mehr offen. Genieße den restlichen Tag.';

  @override
  String get todayEmptyTitle => 'Für heute ist alles erledigt';

  @override
  String get todayErrorTitle => 'Heutige Aufgaben konnten nicht geladen werden';

  @override
  String get todayFocus => 'Fokusmodus';

  @override
  String todayMinutesLeft(String duration) {
    return 'noch $duration';
  }

  @override
  String get todayNoEstimate => 'Keine Zeitschätzung';

  @override
  String todayProgress(int done, int total) {
    return '$done von $total erledigt';
  }

  @override
  String get todayRescheduleAll => 'Alle verschieben';

  @override
  String get todayRetry => 'Erneut versuchen';

  @override
  String get todayReview => 'Tagesrückblick';

  @override
  String get todaySearch => 'Suche (bald verfügbar)';

  @override
  String get todaySectionAfternoon => 'Nachmittags';

  @override
  String get todaySectionAnytime => 'Jederzeit';

  @override
  String get todaySectionCompleted => 'Heute erledigt';

  @override
  String get todaySectionEvening => 'Abends';

  @override
  String get todaySectionMorning => 'Morgens';

  @override
  String get todaySectionOverdue => 'Überfällig';

  @override
  String todaySectionToggle(String section) {
    return '$section ein- oder ausblenden';
  }

  @override
  String get todayTitle => 'Heute';

  @override
  String get undoAction => 'Rückgängig';

  @override
  String undoCompleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben erledigt',
      one: 'Aufgabe erledigt',
    );
    return '$_temp0';
  }

  @override
  String undoDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben gelöscht',
      one: 'Aufgabe gelöscht',
    );
    return '$_temp0';
  }

  @override
  String undoPostponed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben verschoben',
      one: 'Aufgabe verschoben',
    );
    return '$_temp0';
  }

  @override
  String undoUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben aktualisiert',
      one: 'Aufgabe aktualisiert',
    );
    return '$_temp0';
  }
}
