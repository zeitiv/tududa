import '../../core/ids.dart';
import '../../core/time/calendar_date.dart';
import 'search_query.dart';

/// One hit of `GET /search`, discriminated by the response's `type`.
sealed class SearchResult {
  const SearchResult();

  SearchType get type;
  String get name;

  /// Parses one result; returns null for an unknown `type` or a row without
  /// a usable uid, so a newer server never breaks the whole search.
  static SearchResult? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    final type = SearchType.fromWire(json['type']);
    final uid = json['uid'];
    if (type == null || uid is! String || uid.isEmpty) return null;
    final name = (json['name'] ?? json['title'] ?? '').toString();
    final description = json['description'] as String?;
    return switch (type) {
      SearchType.task => TaskHit(
        uid: TaskUid(uid),
        name: name,
        status: _taskStatus(json['status']),
        dueDate: CalendarDate.tryParse(json['due_date'] as String?),
        projectName: _projectName(json),
        description: description,
      ),
      SearchType.project => ProjectHit(
        uid: ProjectUid(uid),
        name: name,
        description: description,
      ),
      SearchType.area => AreaHit(
        uid: AreaUid(uid),
        name: name,
        description: description,
      ),
      SearchType.note => NoteHit(
        uid: NoteUid(uid),
        name: name,
        description: description,
      ),
      SearchType.tag => TagHit(uid: TagUid(uid), name: name),
    };
  }

  static const _statusNames = [
    'not_started',
    'in_progress',
    'done',
    'archived',
    'waiting',
    'cancelled',
    'planned',
  ];

  /// Tasks carry the status as a name or as the integer enum.
  static String? _taskStatus(Object? v) {
    if (v is String) {
      final n = int.tryParse(v);
      return n == null ? v : _taskStatus(n);
    }
    if (v is int && v >= 0 && v < _statusNames.length) return _statusNames[v];
    return null;
  }

  static String? _projectName(Map<String, dynamic> json) {
    for (final key in ['Project', 'project']) {
      final p = json[key];
      if (p is Map && p['name'] is String) return p['name'] as String;
    }
    return json['project_name'] as String?;
  }
}

final class TaskHit extends SearchResult {
  const TaskHit({
    required this.uid,
    required this.name,
    this.status,
    this.dueDate,
    this.projectName,
    this.description,
  });
  final TaskUid uid;
  @override
  final String name;

  /// Status name (`not_started`, `done`, ...), null if the server sent none.
  final String? status;
  final CalendarDate? dueDate;
  final String? projectName;
  final String? description;
  @override
  SearchType get type => SearchType.task;
}

final class ProjectHit extends SearchResult {
  const ProjectHit({required this.uid, required this.name, this.description});
  final ProjectUid uid;
  @override
  final String name;
  final String? description;
  @override
  SearchType get type => SearchType.project;
}

final class AreaHit extends SearchResult {
  const AreaHit({required this.uid, required this.name, this.description});
  final AreaUid uid;
  @override
  final String name;
  final String? description;
  @override
  SearchType get type => SearchType.area;
}

final class NoteHit extends SearchResult {
  const NoteHit({required this.uid, required this.name, this.description});
  final NoteUid uid;
  @override
  final String name;

  /// First 100 characters of the note body.
  final String? description;
  @override
  SearchType get type => SearchType.note;
}

final class TagHit extends SearchResult {
  const TagHit({required this.uid, required this.name});
  final TagUid uid;
  @override
  final String name;
  @override
  SearchType get type => SearchType.tag;
}

class SearchPagination {
  const SearchPagination({
    required this.total,
    required this.limit,
    required this.offset,
    required this.hasMore,
  });
  final int total;
  final int limit;
  final int offset;
  final bool hasMore;
}

class SearchResponse {
  const SearchResponse({
    required this.results,
    this.pagination,
    this.skipped = 0,
  });

  /// Known result types only, in server order (tasks, projects, areas,
  /// notes, tags).
  final List<SearchResult> results;

  /// Null when the request had no `limit`/`offset`.
  final SearchPagination? pagination;

  /// Number of rows dropped because their type is unknown.
  final int skipped;

  factory SearchResponse.fromJson(Object? json) {
    if (json is! Map) throw FormatException('Expected an object', json);
    final raw = json['results'];
    final rows = raw is List ? raw : const [];
    final results = <SearchResult>[];
    var skipped = 0;
    for (final r in rows) {
      final hit = SearchResult.tryParse(r);
      hit == null ? skipped++ : results.add(hit);
    }
    SearchPagination? pagination;
    final p = json['pagination'];
    if (p is Map) {
      int i(String k, int d) => p[k] is num ? (p[k] as num).toInt() : d;
      final total = i('total', results.length);
      final offset = i('offset', 0);
      pagination = SearchPagination(
        total: total,
        limit: i('limit', results.length),
        offset: offset,
        hasMore: p['hasMore'] is bool
            ? p['hasMore'] as bool
            : offset + rows.length < total,
      );
    }
    return SearchResponse(
      results: results,
      pagination: pagination,
      skipped: skipped,
    );
  }
}
