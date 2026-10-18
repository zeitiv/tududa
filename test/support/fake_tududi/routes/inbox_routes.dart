import '../fake_tududi.dart';

/// In-memory inbox of one [FakeTududi] (rows as the server serialises them).
class FakeInboxStore {
  final List<Map<String, dynamic>> items = [];
  int _n = 0;

  /// Adds a row; [createdAt] defaults to a strictly increasing time so list
  /// order (newest first) is deterministic.
  Map<String, dynamic> add(
    String content, {
    String? uid,
    String status = 'added',
    String source = 'manual',
    DateTime? createdAt,
  }) {
    final n = ++_n;
    final at = (createdAt ?? DateTime.utc(2025, 1, 1).add(Duration(minutes: n)))
        .toIso8601String();
    final row = <String, dynamic>{
      'uid': uid ?? 'inbox-$n',
      'title': content,
      'content': content,
      'status': status,
      'source': source,
      'created_at': at,
      'updated_at': at,
      'attachments': <Object?>[],
    };
    items.add(row);
    return row;
  }
}

final _stores = Expando<FakeInboxStore>('FakeInboxStore');

/// The inbox rows of [s]; seed with `inboxStoreOf(s).add('Buy milk')`.
FakeInboxStore inboxStoreOf(FakeTududi s) => _stores[s] ??= FakeInboxStore();

/// Fake of Tududi v1.9.4 `modules/inbox/routes.js`.
void registerInboxRoutes(FakeTududi s) {
  final store = inboxStoreOf(s);

  Map<String, dynamic>? find(String? uid) {
    for (final r in store.items) {
      if (r['uid'] == uid && r['status'] != 'deleted') return r;
    }
    return null;
  }

  Map<String, dynamic> public(Map<String, dynamic> r) => {
    for (final k in const [
      'uid',
      'title',
      'content',
      'status',
      'source',
      'created_at',
      'updated_at',
    ])
      k: r[k],
  };

  final notFound = FakeTududi.json(404, {'error': 'Inbox item not found.'});

  s.route('GET', '/inbox', (ctx) {
    final active =
        store.items
            .where(
              (r) => r['status'] != 'deleted' && r['status'] != 'processed',
            )
            .toList()
          ..sort(
            (a, b) => (b['created_at'] as String).compareTo(
              a['created_at'] as String,
            ),
          );
    final q = ctx.query;
    if (!q.containsKey('limit') && !q.containsKey('offset')) {
      return FakeTududi.json(200, active);
    }
    final limit = int.tryParse(q['limit'] ?? '') ?? 20;
    final offset = int.tryParse(q['offset'] ?? '') ?? 0;
    final page = active.skip(offset).take(limit).toList();
    return FakeTududi.json(200, {
      'items': page,
      'pagination': {
        'total': active.length,
        'limit': limit,
        'offset': offset,
        'hasMore': offset + page.length < active.length,
      },
    });
  });

  s.route('POST', '/inbox', (ctx) {
    final content = ctx.bodyMap['content'];
    if (content is! String || content.trim().isEmpty) {
      return FakeTududi.json(400, {'error': 'Content is required'});
    }
    final source = (ctx.bodyMap['source'] as String?)?.trim();
    final row = store.add(
      content.trim(),
      source: source == null || source.isEmpty ? 'manual' : source,
      createdAt: DateTime.now().toUtc(),
    );
    return FakeTududi.json(201, {...public(row), 'attachments': <Object?>[]});
  });

  // Registered before `/inbox/:uid` is irrelevant: segment counts differ for
  // process; analyze-text is POST while `:uid` routes are GET/PATCH/DELETE.
  s.route('POST', '/inbox/analyze-text', (ctx) {
    final content = ctx.bodyMap['content'];
    if (content is! String || content.trim().isEmpty) {
      return FakeTududi.json(400, {'error': 'Content is required'});
    }
    final tags = [for (final m in RegExp(r'#(\w+)').allMatches(content)) m[1]!];
    final projects = [
      for (final m in RegExp(r'\+(\w+)').allMatches(content)) m[1]!,
    ];
    final cleaned = content
        .replaceAll(RegExp(r'[#+]\w+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return FakeTududi.json(200, {
      'parsed_tags': tags,
      'parsed_projects': projects,
      'cleaned_content': cleaned,
      'parsed_due_date': null,
      'parsed_due_time': null,
      'parsed_reminder_at': null,
      'parsed_date_text': null,
      'parsed_recurrence': null,
      'parsed_person': null,
      'suggested_type': null,
      'suggested_reason': null,
      'parsed_assignee': null,
      'parsed_area': null,
    });
  });

  s.route('GET', '/inbox/:uid', (ctx) {
    final r = find(ctx.params['uid']);
    return r == null
        ? notFound
        : FakeTududi.json(200, {...public(r), 'attachments': <Object?>[]});
  });

  s.route('PATCH', '/inbox/:uid', (ctx) {
    final r = find(ctx.params['uid']);
    if (r == null) return notFound;
    final b = ctx.bodyMap;
    final content = b['content'];
    if (content != null) {
      if (content is! String || content.trim().isEmpty) {
        return FakeTududi.json(400, {'error': 'Content cannot be empty'});
      }
      r['content'] = content.trim();
      r['title'] = content.trim();
    }
    if (b['status'] != null) r['status'] = b['status'];
    r['updated_at'] = DateTime.now().toUtc().toIso8601String();
    return FakeTududi.json(200, {...public(r), 'attachments': <Object?>[]});
  });

  s.route('DELETE', '/inbox/:uid', (ctx) {
    final r = find(ctx.params['uid']);
    if (r == null) return notFound;
    r['status'] = 'deleted';
    return FakeTududi.json(200, {'message': 'Inbox item successfully deleted'});
  });

  s.route('PATCH', '/inbox/:uid/process', (ctx) {
    final r = find(ctx.params['uid']);
    if (r == null) return notFound;
    r['status'] = 'processed';
    r['updated_at'] = DateTime.now().toUtc().toIso8601String();
    return FakeTududi.json(200, public(r));
  });
}
