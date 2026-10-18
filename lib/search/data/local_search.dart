import '../../core/db/app_database.dart';
import '../../core/ids.dart';
import '../../core/time/calendar_date.dart';
import '../domain/search_filter.dart';
import '../domain/search_query.dart';
import '../domain/search_result.dart';

const _statusNames = [
  'not_started',
  'in_progress',
  'done',
  'archived',
  'waiting',
  'cancelled',
  'planned',
];
const _priorityNames = ['low', 'medium', 'high'];

/// Offline search over the Drift tables (tasks, projects, areas, notes,
/// tags). Matching is a case-insensitive substring match done in Dart, so it
/// is correct for German and Chinese text too (SQLite `LIKE`/`lower` only fold
/// ASCII); every word of the text must occur in the name or description.
/// Results go through the same filters and ranking as server results.
///
/// The FTS5 index is not used: it matches word prefixes only, which would
/// make the offline result set differ from the server's substring search.
class LocalSearch {
  LocalSearch(this.db);
  final AppDatabase db;

  Future<ProjectUid?> projectUidByName(String name) async {
    final n = name.toLowerCase();
    for (final p in await _projects()) {
      if (p.name.toLowerCase() == n) return ProjectUid(p.uid ?? p.localId);
    }
    return null;
  }

  Future<AreaUid?> areaUidByName(String name) async {
    final n = name.toLowerCase();
    for (final a in await _areas()) {
      if (a.name.toLowerCase() == n) return AreaUid(a.uid ?? a.localId);
    }
    return null;
  }

  Future<List<ProjectRow>> _projects() => (db.select(
    db.projects,
  )..where((t) => t.pendingDelete.equals(false))).get();

  Future<List<AreaRow>> _areas() =>
      (db.select(db.areas)..where((t) => t.pendingDelete.equals(false))).get();

  /// Runs [p] against the local data. [types] empty means every type.
  Future<List<SearchResult>> search(
    ParsedSearch p, {
    Set<SearchType> types = const {},
    required CalendarDate today,
    int limitPerType = 20,
  }) async {
    final words = [
      for (final w in p.text.toLowerCase().split(RegExp(r'\s+')))
        if (w.isNotEmpty) w,
    ];
    bool matches(String name, String? desc) {
      final n = name.toLowerCase();
      final d = (desc ?? '').toLowerCase();
      return words.every((w) => n.contains(w) || d.contains(w));
    }

    bool wants(SearchType t) => types.isEmpty || types.contains(t);

    final tagNames = [for (final t in p.tags) t.toLowerCase()];
    final projectRows = await _projects();
    final areaRows = await _areas();

    String? projectLocalId;
    if (p.project != null) {
      final n = p.project!.toLowerCase();
      projectLocalId = projectRows
          .where((r) => r.name.toLowerCase() == n)
          .firstOrNull
          ?.localId;
      if (projectLocalId == null) return const [];
    }
    String? areaLocalId;
    if (p.area != null) {
      final n = p.area!.toLowerCase();
      areaLocalId = areaRows
          .where((r) => r.name.toLowerCase() == n)
          .firstOrNull
          ?.localId;
      if (areaLocalId == null) return const [];
    }
    final projectById = {for (final r in projectRows) r.localId: r};

    // local_id -> lower-cased tag names, only loaded when filtering by tag.
    Future<Map<String, Set<String>>> tagsOf(
      Iterable<({String owner, String tag})> links,
    ) async {
      final names = {
        for (final t in await db.select(db.tags).get())
          t.localId: t.name.toLowerCase(),
      };
      final out = <String, Set<String>>{};
      for (final l in links) {
        final n = names[l.tag];
        if (n != null) out.putIfAbsent(l.owner, () => {}).add(n);
      }
      return out;
    }

    bool hasAllTags(Map<String, Set<String>> m, String id) =>
        tagNames.every((t) => m[id]?.contains(t) ?? false);

    final out = <SearchResult>[];

    if (wants(SearchType.task)) {
      final tagMap = tagNames.isEmpty
          ? const <String, Set<String>>{}
          : await tagsOf([
              for (final l in await db.select(db.taskTags).get())
                (owner: l.taskLocalId, tag: l.tagLocalId),
            ]);
      final rows = await (db.select(
        db.tasks,
      )..where((t) => t.pendingDelete.equals(false))).get();
      final hits = <SearchResult>[];
      for (final r in rows) {
        if (!matches(r.name, r.note)) continue;
        if (!hasAllTags(tagMap, r.localId)) continue;
        if (projectLocalId != null && r.projectLocalId != projectLocalId) {
          continue;
        }
        if (areaLocalId != null &&
            r.areaLocalId != areaLocalId &&
            projectById[r.projectLocalId]?.areaLocalId != areaLocalId) {
          continue;
        }
        hits.add(
          TaskHit(
            uid: TaskUid(r.uid ?? r.localId),
            name: r.name,
            status: r.status >= 0 && r.status < _statusNames.length
                ? _statusNames[r.status]
                : null,
            dueDate: CalendarDate.tryParse(r.dueDate),
            projectName: projectById[r.projectLocalId]?.name,
            description: r.note,
            priority: _priorityNames[r.priority.clamp(0, 2)],
          ),
        );
      }
      out.addAll(
        _top(
          rankResults(applyTaskFilters(hits, p, today), p.text),
          limitPerType,
        ),
      );
    }

    if (p.hasTaskFilters) return out;

    if (wants(SearchType.project) && p.tags.isEmpty && p.project == null) {
      final hits = <SearchResult>[
        for (final r in projectRows)
          if (matches(r.name, r.description) &&
              (areaLocalId == null || r.areaLocalId == areaLocalId))
            ProjectHit(
              uid: ProjectUid(r.uid ?? r.localId),
              name: r.name,
              description: r.description,
            ),
      ];
      out.addAll(_top(rankResults(hits, p.text), limitPerType));
    }

    if (wants(SearchType.area) && !p.hasRelationFilters) {
      final hits = <SearchResult>[
        for (final r in areaRows)
          if (matches(r.name, r.description))
            AreaHit(
              uid: AreaUid(r.uid ?? r.localId),
              name: r.name,
              description: r.description,
            ),
      ];
      out.addAll(_top(rankResults(hits, p.text), limitPerType));
    }

    if (wants(SearchType.note) && p.area == null) {
      final tagMap = tagNames.isEmpty
          ? const <String, Set<String>>{}
          : await tagsOf([
              for (final l in await db.select(db.noteTags).get())
                (owner: l.noteLocalId, tag: l.tagLocalId),
            ]);
      final rows = await (db.select(
        db.notes,
      )..where((t) => t.pendingDelete.equals(false))).get();
      final hits = <SearchResult>[
        for (final r in rows)
          if (matches(r.title ?? '', r.content) &&
              hasAllTags(tagMap, r.localId) &&
              (projectLocalId == null || r.projectLocalId == projectLocalId))
            NoteHit(
              uid: NoteUid(r.uid ?? r.localId),
              name: r.title ?? '',
              description: _preview(r.content),
            ),
      ];
      out.addAll(_top(rankResults(hits, p.text), limitPerType));
    }

    if (wants(SearchType.tag) && !p.hasRelationFilters) {
      final rows = await (db.select(
        db.tags,
      )..where((t) => t.pendingDelete.equals(false))).get();
      final hits = <SearchResult>[
        for (final r in rows)
          if (matches(r.name, null))
            TagHit(uid: TagUid(r.uid ?? r.localId), name: r.name),
      ];
      out.addAll(_top(rankResults(hits, p.text), limitPerType));
    }
    return out;
  }

  static List<SearchResult> _top(List<SearchResult> l, int n) =>
      l.length > n ? l.sublist(0, n) : l;

  static String? _preview(String? s) =>
      s == null || s.length <= 100 ? s : s.substring(0, 100);
}
