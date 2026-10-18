import '../fake_tududi.dart';

/// In-memory notes and tags for one [FakeTududi].
class NotesStore {
  final Map<String, Map<String, dynamic>> notes = {};
  final Map<String, Map<String, dynamic>> tags = {};
  int _counter = 0;

  /// When true, `GET /notes` answers `{notes: [...]}` instead of a bare list.
  bool wrapNotesList = false;
}

final Expando<NotesStore> _stores = Expando<NotesStore>('NotesStore');

/// The notes/tags state behind [s]; created on first use.
NotesStore notesStoreOf(FakeTududi s) => _stores[s] ??= NotesStore();

Map<String, dynamic> seedNote(
  FakeTududi s, {
  String? uid,
  String? title = 'Note',
  String? content,
  String? color,
  String? projectUid,
  String? projectName,
  List<String> tags = const [],
}) {
  final st = notesStoreOf(s);
  final n = ++st._counter;
  final note = <String, dynamic>{
    'id': n,
    'uid': uid ?? 'note$n',
    'title': title,
    'content': content,
    'color': color,
    'project_uid': projectUid,
    'Project': projectUid == null
        ? null
        : {'id': 1, 'uid': projectUid, 'name': projectName ?? 'Project'},
    'tags': [for (final t in tags) _tagByName(st, t, create: true)],
    'created_at': '2025-01-01T00:00:00.000Z',
    'updated_at': '2025-01-01T00:00:00.000Z',
  };
  st.notes[note['uid'] as String] = note;
  return note;
}

Map<String, dynamic> seedTag(
  FakeTududi s,
  String name, {
  String? color,
  bool pinned = false,
}) {
  final st = notesStoreOf(s);
  final n = ++st._counter;
  final tag = <String, dynamic>{
    'id': n,
    'uid': 'tag$n',
    'name': name,
    'color': color,
    'pinned': pinned,
    'created_at': '2025-01-01T00:00:00.000Z',
    'updated_at': '2025-01-01T00:00:00.000Z',
  };
  st.tags[tag['uid'] as String] = tag;
  return tag;
}

Map<String, dynamic>? _tagByName(
  NotesStore st,
  String name, {
  bool create = false,
}) {
  for (final t in st.tags.values) {
    if (t['name'] == name) return t;
  }
  if (!create) return null;
  final n = ++st._counter;
  final tag = <String, dynamic>{
    'id': n,
    'uid': 'tag$n',
    'name': name,
    'color': null,
    'pinned': false,
    'created_at': '2025-01-01T00:00:00.000Z',
    'updated_at': '2025-01-01T00:00:00.000Z',
  };
  st.tags[tag['uid'] as String] = tag;
  return tag;
}

/// Exact uid first, else the segment after the last '-' (slug-suffixed ids).
Map<String, dynamic>? _findNote(NotesStore st, String id) {
  final exact = st.notes[id];
  if (exact != null) return exact;
  final dash = id.lastIndexOf('-');
  return dash < 0 ? null : st.notes[id.substring(dash + 1)];
}

Map<String, dynamic>? _findTag(NotesStore st, String identifier) {
  return st.tags[identifier] ?? _tagByName(st, identifier);
}

String _now(FakeTududi s) => s.clock().toUtc().toIso8601String();

List<Map<String, dynamic>> _tagsFromBody(NotesStore st, Object? raw) => [
  for (final t in (raw as List))
    ?_tagByName(
      st,
      t is Map ? (t['name'] ?? '').toString() : t.toString(),
      create: true,
    ),
];

void _applyNoteFields(
  FakeTududi s,
  NotesStore st,
  Map<String, dynamic> note,
  Map<String, dynamic> body,
) {
  for (final k in ['title', 'content', 'color']) {
    if (body.containsKey(k)) note[k] = body[k];
  }
  if (body.containsKey('project_uid')) {
    final p = body['project_uid'];
    note['project_uid'] = p;
    note['Project'] = p == null ? null : {'id': 1, 'uid': p, 'name': 'Project'};
  }
  if (body.containsKey('tags')) {
    note['tags'] = _tagsFromBody(st, body['tags'] ?? const []);
  }
  note['updated_at'] = _now(s);
}

void registerNoteRoutes(FakeTududi s) {
  final st = notesStoreOf(s);
  const json = FakeTududi.json;
  Map<String, dynamic> notFound(String what) => {'error': '$what not found'};

  s.route('GET', '/notes', (ctx) {
    final project = ctx.query['project_uid'];
    final list = [
      for (final n in st.notes.values)
        if (project == null || n['project_uid'] == project) n,
    ];
    return json(200, st.wrapNotesList ? {'notes': list} : list);
  });

  s.route('GET', '/note/:uid', (ctx) {
    final n = _findNote(st, ctx.params['uid']!);
    return n == null ? json(404, notFound('Note')) : json(200, n);
  });

  s.route('POST', '/note', (ctx) {
    final body = ctx.bodyMap;
    final title = (body['title'] ?? '').toString().trim();
    final content = (body['content'] ?? '').toString().trim();
    if (title.isEmpty && content.isEmpty) {
      return json(400, {'error': 'Title is required'});
    }
    final note = seedNote(s, title: null);
    st.notes[note['uid'] as String] = note;
    _applyNoteFields(s, st, note, body);
    return json(201, note);
  });

  s.route('PATCH', '/note/:uid', (ctx) {
    final n = _findNote(st, ctx.params['uid']!);
    if (n == null) return json(404, notFound('Note'));
    final body = ctx.bodyMap;
    if (body.containsKey('title') &&
        (body['title'] ?? '').toString().trim().isEmpty &&
        (body.containsKey('content')
            ? (body['content'] ?? '').toString().trim().isEmpty
            : (n['content'] ?? '').toString().trim().isEmpty)) {
      return json(400, {'error': 'Title is required'});
    }
    _applyNoteFields(s, st, n, body);
    return json(200, n);
  });

  s.route('DELETE', '/note/:uid', (ctx) {
    final n = _findNote(st, ctx.params['uid']!);
    if (n == null) return json(404, notFound('Note'));
    st.notes.remove(n['uid']);
    return json(200, {'message': 'Note deleted successfully'});
  });

  // ---- tags ----
  s.route('GET', '/tags', (_) => json(200, st.tags.values.toList()));

  s.route('GET', '/tag', (ctx) {
    final uid = ctx.query['uid'];
    final name = ctx.query['name'];
    final t = uid != null
        ? st.tags[uid]
        : (name != null ? _tagByName(st, name) : null);
    return t == null ? json(404, notFound('Tag')) : json(200, t);
  });

  s.route('POST', '/tag', (ctx) {
    final name = (ctx.bodyMap['name'] ?? '').toString().trim();
    if (name.isEmpty) return json(400, {'error': 'Tag name is required'});
    if (_tagByName(st, name) != null) {
      return json(409, {'error': 'Tag already exists'});
    }
    return json(201, _tagByName(st, name, create: true));
  });

  s.route('PATCH', '/tag/:identifier', (ctx) {
    final t = _findTag(st, ctx.params['identifier']!);
    if (t == null) return json(404, notFound('Tag'));
    final body = ctx.bodyMap;
    if (body.containsKey('name')) {
      final name = (body['name'] ?? '').toString().trim();
      if (name.isEmpty) return json(400, {'error': 'Tag name is required'});
      t['name'] = name;
    }
    for (final k in ['pinned', 'color']) {
      if (body.containsKey(k)) t[k] = body[k];
    }
    t['updated_at'] = _now(s);
    return json(200, t);
  });

  s.route('DELETE', '/tag/:identifier', (ctx) {
    final t = _findTag(st, ctx.params['identifier']!);
    if (t == null) return json(404, notFound('Tag'));
    st.tags.remove(t['uid']);
    return json(200, {'message': 'Tag deleted successfully'});
  });
}
