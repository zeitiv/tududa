import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../areas/providers/area_provider.dart';
import '../../core/ids.dart';
import '../../core/time/calendar_date.dart';
import '../../core/time/date_formatters.dart';
import '../../tags/providers/tag_provider.dart';
import '../domain/new_task.dart';
import '../domain/quick_add/quick_add_parser.dart';
import '../domain/recurrence/recurrence_rule.dart';
import '../domain/task.dart';
import '../providers/project_options_provider.dart';
import '../providers/task_provider.dart';

/// The existing projects, areas and tags that quick add can refer to by name.
/// Read from the offline store, so it works without a connection.
class QuickAddLookups {
  const QuickAddLookups({
    this.projects = const [],
    this.areas = const [],
    this.tags = const [],
  });

  final List<ProjectOption> projects;
  final List<({AreaUid uid, String name})> areas;
  final List<String> tags;

  ProjectOption? project(String? name) => name == null
      ? null
      : projects.where((p) => _same(p.name, name)).firstOrNull;

  ({AreaUid uid, String name})? area(String? name) =>
      name == null ? null : areas.where((a) => _same(a.name, name)).firstOrNull;
}

bool _same(String a, String b) =>
    a.trim().toLowerCase() == b.trim().toLowerCase();

final quickAddLookupsProvider = Provider<QuickAddLookups>((ref) {
  final projects = ref.watch(projectOptionsProvider).value ?? const [];
  final areas = ref.watch(areaListProvider).value ?? const [];
  final tags = ref.watch(tagListProvider).value ?? const [];
  return QuickAddLookups(
    projects: projects,
    areas: [for (final a in areas) (uid: a.uid, name: a.name)],
    tags: [for (final t in tags) t.name],
  );
});

/// Week start (ISO weekday) used to resolve phrases like "next week".
int quickAddWeekStart(Locale locale) => DateFormats(locale).weekStart;

/// Parses [text]. Projects and areas that do not exist stay plain text (quick
/// add cannot create them), so no chip promises something that is dropped.
ParseResult parseQuickAdd({
  required String text,
  required CalendarDate today,
  required Locale locale,
  required QuickAddLookups lookups,
  Set<int> disabledStarts = const {},
}) {
  final parser = QuickAddParser(
    today: today,
    weekStart: quickAddWeekStart(locale),
    language: locale.languageCode,
    knownProjects: [for (final p in lookups.projects) p.name],
    knownAreas: [for (final a in lookups.areas) a.name],
    knownTags: lookups.tags,
  );
  final first = parser.parse(text, disabledTokenStarts: disabledStarts);
  final unknown = <int>{
    for (final t in first.tokens)
      if ((t.kind == TokenKind.project &&
              lookups.project(t.value as String?) == null) ||
          (t.kind == TokenKind.area &&
              lookups.area(t.value as String?) == null))
        t.start,
  };
  if (unknown.isEmpty) return first;
  return parser.parse(
    text,
    disabledTokenStarts: {...disabledStarts, ...unknown},
  );
}

Priority priorityOf(QuickPriority p) => switch (p) {
  QuickPriority.low => Priority.low,
  QuickPriority.medium => Priority.medium,
  QuickPriority.high => Priority.high,
};

/// Values the user picked by hand; they win over parsed ones.
class QuickAddManual {
  const QuickAddManual({
    this.date,
    this.time,
    this.priority,
    this.project,
    this.area,
    this.tags = const [],
    this.recurrence,
    this.note = '',
  });

  final CalendarDate? date;
  final LocalTime? time;
  final Priority? priority;
  final ProjectOption? project;
  final ({AreaUid uid, String name})? area;
  final List<String> tags;
  final RecurrenceRule? recurrence;
  final String note;

  QuickAddManual copyWith({
    CalendarDate? date,
    LocalTime? time,
    Priority? priority,
    ProjectOption? project,
    ({AreaUid uid, String name})? area,
    List<String>? tags,
    RecurrenceRule? recurrence,
    String? note,
    bool clearDate = false,
    bool clearTime = false,
    bool clearPriority = false,
    bool clearProject = false,
    bool clearArea = false,
    bool clearRecurrence = false,
  }) => QuickAddManual(
    date: clearDate ? null : (date ?? this.date),
    time: clearTime ? null : (time ?? this.time),
    priority: clearPriority ? null : (priority ?? this.priority),
    project: clearProject ? null : (project ?? this.project),
    area: clearArea ? null : (area ?? this.area),
    tags: tags ?? this.tags,
    recurrence: clearRecurrence ? null : (recurrence ?? this.recurrence),
    note: note ?? this.note,
  );
}

/// The merged result of parsing and manual choices: what will be saved.
class QuickAddDraft {
  const QuickAddDraft({
    required this.name,
    this.note,
    this.date,
    this.time,
    this.priority,
    this.project,
    this.area,
    this.tags = const [],
    this.recurrence,
  });

  final String name;
  final String? note;
  final CalendarDate? date;
  final LocalTime? time;
  final Priority? priority;
  final ProjectOption? project;
  final ({AreaUid uid, String name})? area;
  final List<String> tags;
  final RecurrenceRule? recurrence;

  bool get canSave => name.trim().isNotEmpty;

  NewTask toNewTask({
    required CalendarDate today,
    CalendarDate? defaultDue,
    ProjectUid? defaultProject,
  }) {
    final rule = recurrence != null && recurrence!.isRecurring
        ? recurrence
        : null;
    final due = date ?? defaultDue ?? (rule != null ? today : null);
    return NewTask(
      name: name.trim(),
      note: note == null || note!.trim().isEmpty ? null : note!.trim(),
      priority: priority,
      dueDate: due,
      dueTime: due == null ? null : time,
      projectUid: project?.uid ?? defaultProject,
      areaUid: area?.uid,
      tags: tags,
      recurrenceType: rule?.type.backendValue,
      recurrenceInterval: rule?.interval,
      recurrenceEndDate: rule?.endDate,
      recurrenceWeekday: rule?.type == RecurrenceType.monthlyWeekday
          ? rule?.weekday
          : null,
      recurrenceWeekdays:
          rule?.type == RecurrenceType.weekly && rule!.weekdays.isNotEmpty
          ? (rule.weekdays.toList()..sort())
          : null,
      recurrenceMonthDay: rule?.type == RecurrenceType.monthly
          ? rule?.monthDay
          : null,
      recurrenceWeekOfMonth: rule?.type == RecurrenceType.monthlyWeekday
          ? rule?.weekOfMonth
          : null,
      completionBased: rule?.completionBased,
    );
  }
}

/// Merges [parsed] with [manual] (manual wins) and resolves names to ids.
QuickAddDraft mergeQuickAdd(
  ParseResult parsed,
  QuickAddManual manual,
  QuickAddLookups lookups,
) {
  final tags = <String>[];
  for (final t in [...parsed.tags, ...manual.tags]) {
    if (!tags.any((x) => _same(x, t))) tags.add(t);
  }
  return QuickAddDraft(
    name: parsed.title,
    note: manual.note,
    date: manual.date ?? parsed.dueDate,
    time: manual.time ?? parsed.dueTime,
    priority:
        manual.priority ??
        (parsed.priority == null ? null : priorityOf(parsed.priority!)),
    project: manual.project ?? lookups.project(parsed.projectName),
    area: manual.area ?? lookups.area(parsed.areaName),
    tags: tags,
    recurrence: manual.recurrence ?? parsed.recurrence,
  );
}

/// Saves [draft] through the offline repository (outbox) and returns the
/// result. Used by the sheet and the inline row.
Future<TaskResult<Task>> createFromDraft(
  WidgetRef ref,
  QuickAddDraft draft, {
  CalendarDate? defaultDue,
  ProjectUid? defaultProject,
}) => ref
    .read(taskActionsProvider)
    .create(
      draft.toNewTask(
        today: ref.read(taskDayProvider).date,
        defaultDue: defaultDue,
        defaultProject: defaultProject,
      ),
    );
