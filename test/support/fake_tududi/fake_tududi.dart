import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';

import 'routes/routes.dart';

/// A request as seen by the fake server (paths exclude the `/api` prefix).
class RecordedRequest {
  RecordedRequest({
    required this.method,
    required this.path,
    required this.query,
    required this.headers,
    required this.body,
  });

  final String method;
  final String path;
  final Map<String, String> query;
  final Map<String, String> headers;
  final Object? body;

  /// Filled in once the response is produced.
  int? status;

  @override
  String toString() => '$method $path -> $status';
}

class FakeUser {
  FakeUser({
    required this.uid,
    required this.email,
    required this.password,
    this.name = 'Test',
    this.surname = 'User',
    this.language = 'en',
    this.appearance = 'light',
    this.timezone = 'UTC',
  });

  final String uid;
  final String email;
  final String password;
  String name;
  String surname;
  String language;
  String appearance;
  String timezone;

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'email': email,
    'name': name,
    'surname': surname,
    'language': language,
    'appearance': appearance,
    'timezone': timezone,
  };
}

class FakeSession {
  FakeSession(this.id, this.user, this.csrfToken);
  final String id;
  final FakeUser user;
  final String csrfToken;
}

/// What a route handler receives.
class RouteContext {
  RouteContext(this.request, this.params, this.body, this.session);
  final Request request;
  final Map<String, String> params;
  final Object? body;
  final FakeSession? session;

  Map<String, String> get query => request.url.queryParameters;
  Map<String, dynamic> get bodyMap =>
      body is Map ? Map<String, dynamic>.from(body as Map) : {};
}

typedef RouteHandler = FutureOr<Response> Function(RouteContext ctx);

class _Route {
  _Route(this.method, this.pattern, this.handler, this.auth, this.csrf)
    : segments = pattern.split('/').where((s) => s.isNotEmpty).toList();
  final String method;
  final String pattern;
  final RouteHandler handler;
  final bool auth;
  final bool csrf;
  final List<String> segments;

  Map<String, String>? match(String m, List<String> parts) {
    if (m != method || parts.length != segments.length) return null;
    final params = <String, String>{};
    for (var i = 0; i < parts.length; i++) {
      if (segments[i].startsWith(':')) {
        params[segments[i].substring(1)] = Uri.decodeComponent(parts[i]);
      } else if (segments[i] != parts[i]) {
        return null;
      }
    }
    return params;
  }
}

const taskStatusNames = <String, int>{
  'not_started': 0,
  'in_progress': 1,
  'done': 2,
  'archived': 3,
  'waiting': 4,
  'cancelled': 5,
  'planned': 6,
};

/// In-memory stand-in for a Tududi v1.9.4 server, exposed as a shelf [Handler].
class FakeTududi {
  FakeTududi() {
    _registerBuiltIns();
    for (final r in registrars) {
      r(this);
    }
  }

  static const sessionCookie = 'connect.sid';

  // ---- state ----
  final Map<String, FakeUser> users = {};
  final Map<String, FakeSession> sessions = {};
  final Map<String, Map<String, dynamic>> tasks = {};
  final List<RecordedRequest> requests = [];
  final Map<String, List<int>> _failures = {};
  final List<_Route> _routes = [];
  int _idCounter = 0;
  int failedLogins = 0;

  // ---- knobs ----
  bool offline = false;
  Duration latency = Duration.zero;
  int loginFailureLimit = 5;

  // ---- public API ----
  FakeUser addUser(
    String email,
    String password, {
    String name = 'Test',
    String surname = 'User',
  }) {
    final u = FakeUser(
      uid: 'user-${++_idCounter}',
      email: email,
      password: password,
      name: name,
      surname: surname,
    );
    users[email] = u;
    return u;
  }

  Map<String, dynamic> seedTask({
    String? uid,
    String name = 'Task',
    String? note,
    int status = 0,
    int priority = 0,
    String? dueDate,
    String? dueTime,
    String? projectUid,
    List<String> tags = const [],
    List<Map<String, dynamic>> subtasks = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic> extra = const {},
  }) {
    final id = ++_idCounter;
    final created = (createdAt ?? DateTime.utc(2025, 1, 1)).toIso8601String();
    final task = <String, dynamic>{
      'id': id,
      'uid': uid ?? 'task-$id',
      'name': name,
      'original_name': name,
      'note': note,
      'status': status,
      'priority': priority,
      'due_date': dueDate,
      'due_time': dueTime,
      'project_uid': projectUid,
      'tags': [
        for (final t in tags) {'name': t},
      ],
      'subtasks': subtasks,
      'created_at': created,
      'updated_at': (updatedAt ?? createdAt ?? DateTime.utc(2025, 1, 1))
          .toIso8601String(),
      ...extra,
    };
    tasks[task['uid'] as String] = task;
    return task;
  }

  /// Invalidates every session (client keeps its cookie, server forgets it).
  void expireAllSessions() => sessions.clear();

  /// The next request to [path] (without `/api`, e.g. `/tasks`) fails with
  /// [status]. Calls stack: each call queues one failure.
  void failNext(String path, int status) =>
      _failures.putIfAbsent(path, () => []).add(status);

  /// Registers a route. [pattern] excludes `/api`, supports `:param`.
  void route(
    String method,
    String pattern,
    RouteHandler handler, {
    bool auth = true,
    bool csrf = true,
  }) {
    _routes.removeWhere((r) => r.method == method && r.pattern == pattern);
    _routes.add(_Route(method, pattern, handler, auth, csrf));
  }

  static Response json(
    int status,
    Object? body, {
    Map<String, Object> headers = const {},
  }) => Response(
    status,
    body: jsonEncode(body),
    headers: {'content-type': 'application/json; charset=utf-8', ...headers},
  );

  /// Throws if [offline]; the Dio adapter turns this into a connection error.
  Handler get handler => _handle;

  // ---- dispatch ----
  Future<Response> _handle(Request req) async {
    if (offline) throw const FakeConnectionError();
    if (latency > Duration.zero) await Future<void>.delayed(latency);

    var path = req.url.path;
    path = '/${path.startsWith('/') ? path.substring(1) : path}';
    if (path == '/api' || path.startsWith('/api/')) path = path.substring(4);
    if (path.isEmpty) path = '/';

    final raw = await req.readAsString();
    Object? body;
    if (raw.isNotEmpty) {
      try {
        body = jsonDecode(raw);
      } catch (_) {
        body = raw;
      }
    }
    final rec = RecordedRequest(
      method: req.method,
      path: path,
      query: req.url.queryParameters,
      headers: req.headers,
      body: body,
    );
    requests.add(rec);
    final res = await _dispatch(req, path, body);
    rec.status = res.statusCode;
    return res;
  }

  Future<Response> _dispatch(Request req, String path, Object? body) async {
    final queue = _failures[path];
    if (queue != null && queue.isNotEmpty) {
      return json(queue.removeAt(0), {'error': 'Injected failure'});
    }

    final parts = path.split('/').where((s) => s.isNotEmpty).toList();
    _Route? route;
    Map<String, String> params = {};
    for (final r in _routes.reversed) {
      final m = r.match(req.method, parts);
      if (m != null) {
        route = r;
        params = m;
        break;
      }
    }
    if (route == null) return json(404, {'error': 'Not found'});

    final session = _sessionFor(req);
    if (route.auth && session == null) {
      return json(401, {'error': 'Authentication required'});
    }
    const mutating = {'POST', 'PUT', 'PATCH', 'DELETE'};
    if (route.csrf &&
        session != null &&
        mutating.contains(req.method) &&
        req.headers['x-csrf-token'] != session.csrfToken) {
      return json(403, {'error': 'Invalid CSRF token'});
    }
    return route.handler(RouteContext(req, params, body, session));
  }

  FakeSession? _sessionFor(Request req) {
    final header = req.headers['cookie'];
    if (header == null) return null;
    for (final part in header.split(';')) {
      final kv = part.trim().split('=');
      if (kv.length >= 2 && kv.first == sessionCookie) {
        return sessions[kv.sublist(1).join('=')];
      }
    }
    return null;
  }

  // ---- built-in routes ----
  void _registerBuiltIns() {
    route('GET', '/health', (_) => json(200, {'status': 'ok'}), auth: false);
    route(
      'GET',
      '/version',
      (_) => json(200, {'version': '1.9.4'}),
      auth: false,
    );

    route('POST', '/login', (ctx) {
      final email = ctx.bodyMap['email'];
      final password = ctx.bodyMap['password'];
      final user = users[email];
      if (user == null || user.password != password) {
        failedLogins++;
        if (failedLogins >= loginFailureLimit) {
          return json(429, {
            'error': 'Too many login attempts, please try again later.',
          });
        }
        return json(401, {
          'errors': ['Invalid credentials'],
        });
      }
      failedLogins = 0;
      final id = 'sess-${++_idCounter}';
      sessions[id] = FakeSession(id, user, 'csrf-${++_idCounter}');
      return json(
        200,
        {'user': user.toJson()},
        headers: {'set-cookie': '$sessionCookie=$id; Path=/; HttpOnly'},
      );
    }, auth: false);

    route('GET', '/csrf-token', (ctx) {
      return json(200, {'csrfToken': ctx.session!.csrfToken});
    });

    route('GET', '/current_user', (ctx) {
      return json(200, {'user': ctx.session?.user.toJson()});
    }, auth: false);

    route('GET', '/logout', (ctx) {
      final s = ctx.session;
      if (s != null) sessions.remove(s.id);
      return json(
        200,
        {'message': 'Logged out successfully'},
        headers: {'set-cookie': '$sessionCookie=; Path=/; Max-Age=0; HttpOnly'},
      );
    }, auth: false);

    route('GET', '/tasks', _listTasks);
    route('GET', '/task/:uid', (ctx) {
      final t = tasks[ctx.params['uid']];
      return t == null ? json(404, {'error': 'Task not found'}) : json(200, t);
    });
    route('POST', '/task', (ctx) {
      final b = ctx.bodyMap;
      final name = (b['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) return json(400, {'error': 'Task name is required'});
      final now = DateTime.now().toUtc();
      final t = seedTask(
        name: name,
        note: b['note'] as String?,
        status: _statusOf(b['status']) ?? 0,
        priority: (b['priority'] as int?) ?? 0,
        dueDate: b['due_date'] as String?,
        dueTime: b['due_time'] as String?,
        projectUid: b['project_uid'] as String?,
        tags: [
          for (final tag in (b['tags'] as List? ?? const []))
            tag is Map ? tag['name'] as String : tag as String,
        ],
        createdAt: now,
      );
      return json(201, t);
    });
    route('PATCH', '/task/:uid', (ctx) {
      final t = tasks[ctx.params['uid']];
      if (t == null) return json(404, {'error': 'Task not found'});
      final b = ctx.bodyMap;
      for (final e in b.entries) {
        if (e.key == 'uid' || e.key == 'id') continue;
        if (e.key == 'status') {
          t['status'] = _statusOf(e.value) ?? t['status'];
        } else if (e.key == 'tags' && e.value is List) {
          t['tags'] = [
            for (final tag in e.value as List)
              tag is Map ? {'name': tag['name']} : {'name': tag},
          ];
        } else {
          t[e.key] = e.value;
        }
      }
      final prev = DateTime.parse(t['updated_at'] as String);
      var now = DateTime.now().toUtc();
      if (!now.isAfter(prev)) now = prev.add(const Duration(milliseconds: 1));
      t['updated_at'] = now.toIso8601String();
      return json(200, t);
    });
    route('DELETE', '/task/:uid', (ctx) {
      final t = tasks.remove(ctx.params['uid']);
      return t == null
          ? json(404, {'error': 'Task not found'})
          : json(200, {'message': 'Task successfully deleted'});
    });
  }

  static int? _statusOf(Object? v) {
    if (v is int) return v;
    if (v is String) return taskStatusNames[v] ?? int.tryParse(v);
    return null;
  }

  Response _listTasks(RouteContext ctx) {
    final q = ctx.query;
    var list = tasks.values.toList();

    final status = _statusOf(q['status']);
    if (status != null) {
      list = list.where((t) => t['status'] == status).toList();
    }
    final project = q['project_uid'];
    if (project != null) {
      list = list.where((t) => t['project_uid'] == project).toList();
    }
    if (q['type'] == 'today') {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      list = list.where((t) {
        final d = t['due_date'] as String?;
        return d != null && d.compareTo(today) <= 0 && t['status'] != 2;
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
    final limit = int.tryParse(q['limit'] ?? '') ?? 50;
    final offset = int.tryParse(q['offset'] ?? '') ?? 0;
    final page = list.skip(offset).take(limit).toList();
    return json(200, {
      'tasks': page,
      'pagination': {
        'total': total,
        'limit': limit,
        'offset': offset,
        'hasMore': offset + page.length < total,
      },
    });
  }
}

/// Thrown by the handler when [FakeTududi.offline] is set.
class FakeConnectionError implements Exception {
  const FakeConnectionError();
  @override
  String toString() => 'FakeConnectionError: server offline';
}
