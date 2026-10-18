import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpDate;

import 'package:shelf/shelf.dart';

import 'routes/routes.dart';
import 'routes/tasks_routes.dart';

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

class _Failure {
  _Failure(this.status, this.body, this.headers, {this.connection = false});
  final int status;
  final Object? body;
  final Map<String, Object> headers;
  final bool connection;
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
    registerTaskRoutes(this);
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
  final Map<String, List<_Failure>> _failures = {};
  final List<_Route> _routes = [];
  int _idCounter = 0;
  int failedLogins = 0;

  // ---- knobs ----
  bool offline = false;
  Duration latency = Duration.zero;
  int loginFailureLimit = 5;

  /// `GET /tasks` answers with a bare list instead of `{tasks, pagination}`.
  bool tasksListBare = false;

  /// A fresh numeric id (shared by users, sessions and tasks).
  int nextId() => ++_idCounter;

  /// The server's idea of "now", used for the `Date` response header.
  DateTime Function() clock = DateTime.now;

  /// Added to [clock] for the `Date` header, to simulate a skewed device clock.
  Duration serverSkew = Duration.zero;

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
      'completed_at': null,
      'recurrence_type': 'none',
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
  /// [body] defaults to `{error: 'Injected failure'}`; [headers] are added to
  /// the response (e.g. `{'retry-after': '2'}` for a 429).
  void failNext(
    String path,
    int status, {
    Object? body,
    Map<String, Object> headers = const {},
  }) => _failures
      .putIfAbsent(path, () => [])
      .add(_Failure(status, body ?? {'error': 'Injected failure'}, headers));

  /// The next [times] requests to [path] fail like a dropped connection.
  void failNextConnection(String path, {int times = 1}) {
    for (var i = 0; i < times; i++) {
      _failures
          .putIfAbsent(path, () => [])
          .add(_Failure(0, null, const {}, connection: true));
    }
  }

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
    return res.change(
      headers: {'date': HttpDate.format(clock().add(serverSkew).toUtc())},
    );
  }

  Future<Response> _dispatch(Request req, String path, Object? body) async {
    final queue = _failures[path];
    if (queue != null && queue.isNotEmpty) {
      final f = queue.removeAt(0);
      if (f.connection) throw const FakeConnectionError();
      return json(f.status, f.body, headers: f.headers);
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
          return json(
            429,
            {'error': 'Too many login attempts, please try again later.'},
            headers: {'retry-after': '900'},
          );
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
  }

  /// Status as a number, from a number or a name like `done`.
  static int? statusOf(Object? v) {
    if (v is int) return v;
    if (v is String) return taskStatusNames[v] ?? int.tryParse(v);
    return null;
  }
}

/// Thrown by the handler when [FakeTududi.offline] is set.
class FakeConnectionError implements Exception {
  const FakeConnectionError();
  @override
  String toString() => 'FakeConnectionError: server offline';
}
