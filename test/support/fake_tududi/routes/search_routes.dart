import '../fake_tududi.dart';

/// A small in-memory corpus for `GET /search`, next to the tasks seeded in
/// [FakeTududi.tasks] (which are searched too, as `Task` rows).
class FakeSearchCorpus {
  final List<Map<String, dynamic>> rows = [];

  /// [type] is `Project|Area|Note|Tag` (or `Task`); [extra] is merged into the
  /// row, e.g. `{'status': 1, 'due_date': '2025-03-01'}`.
  Map<String, dynamic> add(
    String type,
    String name, {
    String? uid,
    String? description,
    Map<String, dynamic> extra = const {},
  }) {
    final row = <String, dynamic>{
      'type': type,
      'id': rows.length + 1,
      'uid': uid ?? '${type.toLowerCase()}-${rows.length + 1}',
      'name': name,
      if (type == 'Note') 'title': name,
      'description': ?description,
      ...extra,
    };
    rows.add(row);
    return row;
  }
}

final _corpora = Expando<FakeSearchCorpus>('FakeSearchCorpus');

/// The extra search corpus of [s]; `searchCorpusOf(s).add('Project', 'Home')`.
FakeSearchCorpus searchCorpusOf(FakeTududi s) =>
    _corpora[s] ??= FakeSearchCorpus();

const _typeOrder = ['Task', 'Project', 'Area', 'Note', 'Tag'];
const _completed = {2, 3, 5};

/// Fake of Tududi v1.9.4 `GET /search`: case-insensitive substring over name
/// and description/note, `filters`, `status`, `tags` (tasks), `project_uid`,
/// and per-type `limit`/`offset` with a summed `pagination.total`, as the real
/// backend does.
void registerSearchRoutes(FakeTududi s) {
  final corpus = searchCorpusOf(s);

  s.route('GET', '/search', (ctx) {
    final q = ctx.query;
    final needle = (q['q'] ?? '').trim().toLowerCase();
    final types = q['filters'] == null
        ? _typeOrder
        : q['filters']!.split(',').map((e) => e.trim()).toList();
    final hasPagination = q.containsKey('limit') || q.containsKey('offset');
    final limit = hasPagination ? (int.tryParse(q['limit'] ?? '') ?? 20) : 20;
    final offset = hasPagination ? (int.tryParse(q['offset'] ?? '') ?? 0) : 0;
    final status = q['status'];
    final tags = (q['tags'] ?? '')
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
    final projectUid = q['project_uid'];

    bool matches(Map<String, dynamic> r) {
      if (needle.isEmpty) return true;
      for (final k in ['name', 'title', 'description', 'note']) {
        final v = r[k];
        if (v is String && v.toLowerCase().contains(needle)) return true;
      }
      return false;
    }

    bool taskOk(Map<String, dynamic> t) {
      final st = t['status'];
      if (status == 'active' && _completed.contains(st)) return false;
      if (status == 'completed' && !_completed.contains(st)) return false;
      final taskStatus = q['task_status'];
      if (taskStatus != null && taskStatusNames[taskStatus] != st) return false;
      if (projectUid != null && t['project_uid'] != projectUid) return false;
      if (tags.isNotEmpty) {
        final have = [
          for (final x in (t['tags'] as List? ?? const []))
            (x is Map ? x['name'] : x).toString().toLowerCase(),
        ];
        if (!tags.every(have.contains)) return false;
      }
      return true;
    }

    final results = <Map<String, dynamic>>[];
    var total = 0;
    for (final type in _typeOrder) {
      if (!types.contains(type)) continue;
      final rows = <Map<String, dynamic>>[
        if (type == 'Task')
          for (final t in s.tasks.values)
            if (taskOk(t)) {...t, 'type': 'Task', 'description': t['note']},
        for (final r in corpus.rows)
          if (r['type'] == type && (type != 'Task' || taskOk(r))) r,
      ].where(matches).toList();
      total += rows.length;
      results.addAll(rows.skip(offset).take(limit));
    }
    return FakeTududi.json(200, {
      'results': results,
      if (hasPagination)
        'pagination': {
          'total': total,
          'limit': limit,
          'offset': offset,
          'hasMore': offset + results.length < total,
        },
    });
  });
}
