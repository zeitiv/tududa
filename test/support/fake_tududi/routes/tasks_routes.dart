import 'package:shelf/shelf.dart';

import '../fake_tududi.dart';

/// Task endpoints of a Tududi v1.9.x server, as far as the app uses them:
///
/// * `GET /tasks` with `type`, `status`, `priority`, `tag`, `project_uid`,
///   `area_uid`, `search`, `order_by`, `limit`/`offset` (always answers
///   `{tasks, pagination}` unless [FakeTududi.tasksListBare]) and
///   `include_lists` for `type=today`. Subtasks never appear at top level.
/// * `GET/PATCH/DELETE /task/:uid`, `POST /task`, `GET /task/:uid/subtasks`,
///   `POST /task/:uid/skip-occurrence`, `GET /tasks/metrics`.
///
/// PATCH semantics: omitted keys are kept, `null` clears, `tags` replaces the
/// whole set by name, and sending `due_date` without `due_time` drops the
/// time. Unknown uid is 404, an empty name is 400.
void registerTaskRoutes(FakeTududi s) {
  Response notFound() => FakeTududi.json(404, {'error': 'Task not found'});
  Response badRequest(String m) => FakeTududi.json(400, {'error': m});

  s.route('GET', '/tasks', (ctx) => _list(s, ctx));

  s.route('GET', '/tasks/metrics', (ctx) {
    final all = s.tasks.values.toList();
    bool done(Map<String, dynamic> t) => t['status'] == 2 || t['status'] == 3;
    return FakeTududi.json(200, {
      'total_open_tasks': all.where((t) => !done(t)).length,
      'tasks_completed': all.where(done).length,
    });
  });

  s.route('GET', '/task/:uid', (ctx) {
    final t = s.tasks[ctx.params['uid']];
    return t == null ? notFound() : FakeTududi.json(200, _render(s, t));
  });

  s.route('GET', '/task/:uid/subtasks', (ctx) {
    final t = s.tasks[ctx.params['uid']];
    if (t == null) return notFound();
    return FakeTududi.json(200, [
      for (final c in _children(s, t)) _render(s, c),
    ]);
  });

  s.route('POST', '/task', (ctx) {
    final b = ctx.bodyMap;
    final name = (b['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) return badRequest('Task name is required');

    int? parentId;
    if (b['parent_task_id'] != null) {
      parentId = b['parent_task_id'] as int;
      final parentExists = s.tasks.values.any((t) => t['id'] == parentId);
      if (!parentExists) {
        return FakeTududi.json(404, {'error': 'Parent task not found'});
      }
    }
    final minutesError = _validateMinutes(b);
    if (minutesError != null) return badRequest(minutesError);

    final task = s.seedTask(
      name: name,
      createdAt: DateTime.now().toUtc(),
      extra: {'parent_task_id': ?parentId},
    );
    _apply(task, b, isCreate: true);
    return FakeTududi.json(201, _render(s, task));
  });

  s.route('PATCH', '/task/:uid', (ctx) {
    final t = s.tasks[ctx.params['uid']];
    if (t == null) return notFound();
    final b = ctx.bodyMap;
    if (b.containsKey('name') &&
        ((b['name'] as String?)?.trim() ?? '').isEmpty) {
      return badRequest('Task name is required');
    }
    final minutesError = _validateMinutes(b);
    if (minutesError != null) return badRequest(minutesError);
    _apply(t, b, isCreate: false);
    return FakeTududi.json(200, _render(s, t));
  });

  s.route('DELETE', '/task/:uid', (ctx) {
    final t = s.tasks.remove(ctx.params['uid']);
    if (t == null) return notFound();
    for (final c in _children(s, t).toList()) {
      s.tasks.remove(c['uid']);
    }
    return FakeTududi.json(200, {'message': 'Task successfully deleted'});
  });

  s.route('POST', '/task/:uid/skip-occurrence', (ctx) {
    final t = s.tasks[ctx.params['uid']];
    if (t == null) return notFound();
    final type = t['recurrence_type'] as String? ?? 'none';
    if (type == 'none') return badRequest('Task is not recurring');
    final due = t['due_date'] as String?;
    if (due != null) {
      final n = (t['recurrence_interval'] as int?) ?? 1;
      final d = DateTime.parse(due.substring(0, 10));
      final next = switch (type) {
        'daily' => DateTime.utc(d.year, d.month, d.day + n),
        'weekly' => DateTime.utc(d.year, d.month, d.day + 7 * n),
        _ => _addMonths(d, n),
      };
      t['due_date'] = _ymd(next);
    }
    _touch(t);
    return FakeTududi.json(200, _render(s, t));
  });
}

// ---- helpers ----

const _mutableKeys = <String>{
  'name',
  'note',
  'status',
  'priority',
  'due_date',
  'due_time',
  'defer_until',
  'reminder_at',
  'estimated_minutes',
  'project_uid',
  'area_uid',
  'recurrence_type',
  'recurrence_interval',
  'recurrence_end_date',
  'recurrence_weekday',
  'recurrence_weekdays',
  'recurrence_month_day',
  'recurrence_week_of_month',
  'completion_based',
  'tags',
  'order',
};

const _priorityNames = {'low': 0, 'medium': 1, 'high': 2};

int? _priorityOf(Object? v) {
  if (v is int) return v;
  if (v is String) return _priorityNames[v] ?? int.tryParse(v);
  return null;
}

String? _validateMinutes(Map<String, dynamic> b) {
  final m = b['estimated_minutes'];
  if (m == null) return null;
  if (m is! int || m < 5 || m > 720) {
    return 'estimated_minutes must be between 5 and 720';
  }
  return null;
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime _addMonths(DateTime d, int n) {
  final total = d.month - 1 + n;
  final year = d.year + total ~/ 12;
  final month = total % 12 + 1;
  final last = DateTime.utc(year, month + 1, 0).day;
  return DateTime.utc(year, month, d.day > last ? last : d.day);
}

void _touch(Map<String, dynamic> t) {
  final prev = DateTime.parse(t['updated_at'] as String);
  var now = DateTime.now().toUtc();
  if (!now.isAfter(prev)) now = prev.add(const Duration(milliseconds: 1));
  t['updated_at'] = now.toIso8601String();
}

List<Map<String, dynamic>> _tagsOf(Object? raw) => [
  if (raw is List)
    for (final tag in raw)
      if (tag is Map)
        {'name': tag['name'], 'uid': 'tag-${tag['name']}'}
      else
        {'name': tag, 'uid': 'tag-$tag'},
];

/// Applies a create/patch body to [t] the way Tududi does.
void _apply(
  Map<String, dynamic> t,
  Map<String, dynamic> b, {
  required bool isCreate,
}) {
  final wasDone = t['status'] == 2;
  for (final e in b.entries) {
    if (!_mutableKeys.contains(e.key)) continue;
    switch (e.key) {
      case 'name':
        final name = (e.value as String).trim();
        t['name'] = name;
        t['original_name'] = name;
      case 'status':
        t['status'] = e.value == null
            ? 0
            : (FakeTududi.statusOf(e.value) ?? t['status']);
      case 'priority':
        t['priority'] = e.value == null
            ? 0
            : (_priorityOf(e.value) ?? t['priority']);
      case 'tags':
        t['tags'] = _tagsOf(e.value);
      case 'recurrence_type':
        t['recurrence_type'] = e.value ?? 'none';
      default:
        t[e.key] = e.value;
    }
  }
  // Tududi: a new due date without a due time resets the time.
  if (!isCreate && b.containsKey('due_date') && !b.containsKey('due_time')) {
    t['due_time'] = null;
  }
  final isDone = t['status'] == 2;
  if (isDone && !wasDone) {
    t['completed_at'] = DateTime.now().toUtc().toIso8601String();
  } else if (!isDone) {
    t['completed_at'] = null;
  }
  _touch(t);
}

Iterable<Map<String, dynamic>> _children(
  FakeTududi s,
  Map<String, dynamic> t,
) => s.tasks.values.where((c) => c['parent_task_id'] == t['id']);

/// The task as the API returns it: children folded into `subtasks`.
Map<String, dynamic> _render(FakeTududi s, Map<String, dynamic> t) {
  final kids = _children(s, t).toList();
  return {
    ...t,
    if (kids.isNotEmpty) 'subtasks': [for (final c in kids) _render(s, c)],
  };
}

bool _finished(Map<String, dynamic> t) => t['status'] == 2 || t['status'] == 3;

Response _list(FakeTududi s, RouteContext ctx) {
  final q = ctx.query;
  final today = s.clock().toIso8601String().substring(0, 10);
  String? due(Map<String, dynamic> t) {
    final d = t['due_date'] as String?;
    return d?.substring(0, 10);
  }

  var list = s.tasks.values.where((t) => t['parent_task_id'] == null).toList();

  final type = q['type'];
  list = list.where((t) {
    final d = due(t);
    return switch (type) {
      'today' => d != null && d.compareTo(today) <= 0 && !_finished(t),
      'upcoming' => d != null && d.compareTo(today) > 0 && !_finished(t),
      'someday' => d == null && !_finished(t),
      'inbox' => d == null && t['project_uid'] == null && !_finished(t),
      'waiting' => t['status'] == 4,
      'all' => true,
      _ => !_finished(t),
    };
  }).toList();

  final status = q['status'];
  if (status != null) {
    list = list.where((t) {
      return switch (status) {
        'completed' => _finished(t),
        'active' => !_finished(t),
        'all' => true,
        _ => t['status'] == FakeTududi.statusOf(status),
      };
    }).toList();
  }
  final priority = _priorityOf(q['priority']);
  if (priority != null) {
    list = list.where((t) => t['priority'] == priority).toList();
  }
  final tag = q['tag'];
  if (tag != null) {
    list = list
        .where((t) => (t['tags'] as List).any((g) => (g as Map)['name'] == tag))
        .toList();
  }
  final project = q['project_uid'];
  if (project != null) {
    list = list.where((t) => t['project_uid'] == project).toList();
  }
  final area = q['area_uid'];
  if (area != null) list = list.where((t) => t['area_uid'] == area).toList();
  final search = q['search']?.toLowerCase();
  if (search != null && search.isNotEmpty) {
    list = list.where((t) {
      return (t['name'] as String).toLowerCase().contains(search) ||
          ((t['note'] as String?) ?? '').toLowerCase().contains(search);
    }).toList();
  }

  final order = q['order_by'];
  if (order != null) {
    final bits = order.split(':');
    final field = bits.first;
    final desc = bits.length > 1 && bits[1] == 'desc';
    int cmp(Map<String, dynamic> a, Map<String, dynamic> b) {
      final x = a[field], y = b[field];
      if (x == null && y == null) return 0;
      if (x == null) return 1;
      if (y == null) return -1;
      return (x as Comparable).compareTo(y);
    }

    list.sort((a, b) => desc ? cmp(b, a) : cmp(a, b));
  }

  final total = list.length;
  final hasWindow = q.containsKey('limit') || q.containsKey('offset');
  final limit = int.tryParse(q['limit'] ?? '') ?? (hasWindow ? 50 : total);
  final offset = int.tryParse(q['offset'] ?? '') ?? 0;
  final page = [for (final t in list.skip(offset).take(limit)) _render(s, t)];

  if (s.tasksListBare) return FakeTududi.json(200, page);

  final body = <String, Object?>{
    'tasks': page,
    'pagination': {
      'total': total,
      'limit': limit,
      'offset': offset,
      'hasMore': offset + page.length < total,
    },
  };
  if (type == 'today' && q['include_lists'] == 'true') {
    final all = s.tasks.values.where((t) => t['parent_task_id'] == null);
    List<Map<String, dynamic>> pick(bool Function(Map<String, dynamic>) f) => [
      for (final t in all)
        if (f(t)) _render(s, t),
    ];
    body['tasks_overdue'] = pick((t) {
      final d = due(t);
      return d != null && d.compareTo(today) < 0 && !_finished(t);
    });
    body['tasks_due_today'] = pick((t) => due(t) == today && !_finished(t));
    body['tasks_today_plan'] = pick((t) => t['status'] == 6);
    body['tasks_in_progress'] = pick((t) => t['status'] == 1);
    body['tasks_completed_today'] = pick((t) {
      final c = t['completed_at'] as String?;
      return t['status'] == 2 && c != null && c.substring(0, 10) == today;
    });
  }
  return FakeTududi.json(200, body);
}
