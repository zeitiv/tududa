import '../../core/ids.dart';
import '../../core/time/calendar_date.dart';

/// Entity kinds `GET /search` can return; [wire] is the `type` discriminator
/// and the value used in the `filters` parameter.
enum SearchType {
  task('Task'),
  project('Project'),
  area('Area'),
  note('Note'),
  tag('Tag');

  const SearchType(this.wire);
  final String wire;

  static SearchType? fromWire(Object? raw) {
    for (final t in values) {
      if (t.wire == raw) return t;
    }
    return null;
  }
}

/// `status` parameter: narrows tasks to open / finished ones.
enum SearchStatus { active, completed, all }

/// Value class for one search request.
///
/// Backend facts (modules/search, v1.9.4): `q` is a case-insensitive
/// substring match on name/note (title/content for notes, name/description
/// for projects and areas); `filters` is a comma list of [SearchType.wire]
/// (all types when absent); `priority` is `low|medium|high`; `due`/`defer`
/// are `today|tomorrow|next_week|next_month`; `tags` is a comma list of tag
/// names that must ALL match; `task_status` is one of `not_started,
/// in_progress, done, archived, waiting, cancelled, planned` and wins over
/// `status`. Without `limit`/`offset` the server returns up to 20 per type
/// and no `pagination`; NOTE `limit`/`offset` apply to each type separately.
class SearchQuery {
  const SearchQuery({
    this.text = '',
    this.filters = const {},
    this.tags = const [],
    this.status,
    this.taskStatus,
    this.priority,
    this.due,
    this.defer,
    this.projectUid,
    this.areaUid,
    this.limit,
    this.offset,
  });

  final String text;

  /// Empty means every type.
  final Set<SearchType> filters;
  final List<String> tags;
  final SearchStatus? status;
  final String? taskStatus;
  final String? priority;
  final String? due;
  final String? defer;
  final ProjectUid? projectUid;
  final AreaUid? areaUid;
  final int? limit;
  final int? offset;

  /// True when there is nothing to search for.
  bool get isEmpty =>
      text.trim().isEmpty &&
      tags.isEmpty &&
      priority == null &&
      due == null &&
      defer == null &&
      status == null &&
      taskStatus == null &&
      projectUid == null &&
      areaUid == null;

  SearchQuery copyWith({
    String? text,
    Set<SearchType>? filters,
    List<String>? tags,
    SearchStatus? status,
    String? taskStatus,
    String? priority,
    String? due,
    String? defer,
    ProjectUid? projectUid,
    AreaUid? areaUid,
    int? limit,
    int? offset,
  }) => SearchQuery(
    text: text ?? this.text,
    filters: filters ?? this.filters,
    tags: tags ?? this.tags,
    status: status ?? this.status,
    taskStatus: taskStatus ?? this.taskStatus,
    priority: priority ?? this.priority,
    due: due ?? this.due,
    defer: defer ?? this.defer,
    projectUid: projectUid ?? this.projectUid,
    areaUid: areaUid ?? this.areaUid,
    limit: limit ?? this.limit,
    offset: offset ?? this.offset,
  );

  /// Query string map; unset values are omitted. Filters are emitted in
  /// [SearchType] order so equal queries encode identically.
  Map<String, String> toQueryParameters() {
    final types = [
      for (final t in SearchType.values)
        if (filters.contains(t)) t,
    ];
    final cleanTags = [
      for (final t in tags)
        if (t.trim().isNotEmpty) t.trim(),
    ];
    return {
      if (text.trim().isNotEmpty) 'q': text.trim(),
      if (types.isNotEmpty) 'filters': types.map((t) => t.wire).join(','),
      'priority': ?priority,
      'due': ?due,
      'defer': ?defer,
      if (cleanTags.isNotEmpty) 'tags': cleanTags.join(','),
      if (status != null) 'status': status!.name,
      'task_status': ?taskStatus,
      if (projectUid != null) 'project_uid': projectUid!.value,
      if (areaUid != null) 'area_uid': areaUid!.value,
      if (limit != null) 'limit': '$limit',
      if (offset != null) 'offset': '$offset',
    };
  }

  @override
  bool operator ==(Object other) =>
      other is SearchQuery &&
      _eq(toQueryParameters(), other.toQueryParameters());

  @override
  int get hashCode => Object.hashAllUnordered(
    toQueryParameters().entries.map((e) => Object.hash(e.key, e.value)),
  );

  static bool _eq(Map<String, String> a, Map<String, String> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
}

/// `is:` values of the search syntax.
enum SearchIs { overdue, today, done }

/// `due:` values of the search syntax; a concrete day is kept in
/// [ParsedSearch.dueDate] with [SearchDue.date].
enum SearchDue { today, tomorrow, week, date }

/// A raw search string split into its language-neutral syntax tokens:
///
/// - `#tag`, `+project`, `~area` (quote values with spaces: `#"to do"`)
/// - `is:overdue|today|done`
/// - `priority:high|medium|low`
/// - `due:today|tomorrow|week|YYYY-MM-DD`
///
/// Everything else (including unknown `key:value` pairs and bare `#`, `+`,
/// `~`) stays free [text].
class ParsedSearch {
  const ParsedSearch({
    this.text = '',
    this.tags = const [],
    this.project,
    this.area,
    this.flags = const {},
    this.priority,
    this.due,
    this.dueDate,
  });

  final String text;
  final List<String> tags;
  final String? project;
  final String? area;
  final Set<SearchIs> flags;

  /// `low|medium|high`.
  final String? priority;
  final SearchDue? due;
  final CalendarDate? dueDate;

  static final _tokens = RegExp(r'''(?:[#+~]|[A-Za-z]+:)?"[^"]*"|\S+''');

  static ParsedSearch parse(String raw) {
    final free = <String>[];
    final tags = <String>[];
    String? project, area, priority;
    final flags = <SearchIs>{};
    SearchDue? due;
    CalendarDate? dueDate;

    String unquote(String v) =>
        v.length >= 2 && v.startsWith('"') && v.endsWith('"')
        ? v.substring(1, v.length - 1)
        : v;

    for (final m in _tokens.allMatches(raw)) {
      final token = m[0]!;
      final head = token[0];
      final rest = unquote(token.substring(1)).trim();
      if ((head == '#' || head == '+' || head == '~') && rest.isNotEmpty) {
        if (head == '#') {
          if (!tags.contains(rest)) tags.add(rest);
        } else if (head == '+') {
          project = rest;
        } else {
          area = rest;
        }
        continue;
      }
      final colon = token.indexOf(':');
      if (colon > 0) {
        final key = token.substring(0, colon).toLowerCase();
        final value = unquote(token.substring(colon + 1)).trim().toLowerCase();
        var ok = true;
        switch (key) {
          case 'is':
            final f = SearchIs.values.asNameMap()[value];
            f == null ? ok = false : flags.add(f);
          case 'priority':
            if (const {'high', 'medium', 'low'}.contains(value)) {
              priority = value;
            } else {
              ok = false;
            }
          case 'due':
            final d = {
              'today': SearchDue.today,
              'tomorrow': SearchDue.tomorrow,
              'week': SearchDue.week,
            }[value];
            final date = CalendarDate.tryParse(value);
            if (d != null) {
              due = d;
              dueDate = null;
            } else if (date != null && value.length == 10) {
              due = SearchDue.date;
              dueDate = date;
            } else {
              ok = false;
            }
          default:
            ok = false;
        }
        if (ok) continue;
      }
      free.add(token);
    }
    return ParsedSearch(
      text: free.join(' '),
      tags: tags,
      project: project,
      area: area,
      flags: flags,
      priority: priority,
      due: due,
      dueDate: dueDate,
    );
  }

  /// Syntax that only applies to tasks.
  bool get hasTaskFilters =>
      flags.isNotEmpty || priority != null || due != null;

  /// Syntax that narrows by relation (tag, project, area).
  bool get hasRelationFilters =>
      tags.isNotEmpty || project != null || area != null;

  bool get isEmpty =>
      text.trim().isEmpty && !hasTaskFilters && !hasRelationFilters;

  /// Appends [token] to [raw], separated by a single space.
  static String append(String raw, String token) {
    final base = raw.trimRight();
    return base.isEmpty ? token : '$base $token';
  }

  /// `#tag`, quoted when the name has whitespace.
  static String tagToken(String name) =>
      name.contains(RegExp(r'\s')) ? '#"$name"' : '#$name';
}
