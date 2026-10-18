import '../fake_tududi.dart';

/// State of the project/area routes of one [FakeTududi].
class ProjectStore {
  final Map<String, Map<String, dynamic>> projects = {};
  final Map<String, Map<String, dynamic>> areas = {};
  int _counter = 0;
}

final _stores = Expando<ProjectStore>('projectStore');

ProjectStore projectStoreOf(FakeTududi s) => _stores[s] ??= ProjectStore();

/// Adds a project directly to [s] (bypasses HTTP).
Map<String, dynamic> seedProject(
  FakeTududi s, {
  String? uid,
  String name = 'Project',
  String? description,
  String status = 'not_started',
  int? priority,
  String? areaUid,
  bool pinToSidebar = false,
  String? dueDateAt,
}) {
  final st = projectStoreOf(s);
  final id = ++st._counter;
  final now = DateTime.utc(2025, 1, 1).toIso8601String();
  final p = <String, dynamic>{
    'id': id,
    'uid': uid ?? 'proj$id-${name.toLowerCase().replaceAll(' ', '-')}',
    'name': name,
    'description': description,
    'status': status,
    'priority': priority,
    'due_date_at': dueDateAt,
    'area_uid': areaUid,
    'pin_to_sidebar': pinToSidebar,
    'task_show_completed': false,
    'task_sort_order': 'created_at:desc',
    'image_url': null,
    'created_at': now,
    'updated_at': now,
  };
  st.projects[p['uid'] as String] = p;
  return p;
}

/// Adds an area directly to [s] (bypasses HTTP).
Map<String, dynamic> seedArea(
  FakeTududi s, {
  String? uid,
  String name = 'Area',
  String? description,
}) {
  final st = projectStoreOf(s);
  final id = ++st._counter;
  final now = DateTime.utc(2025, 1, 1).toIso8601String();
  final a = <String, dynamic>{
    'id': id,
    'uid': uid ?? 'area$id',
    'name': name,
    'description': description,
    'created_at': now,
    'updated_at': now,
  };
  st.areas[a['uid'] as String] = a;
  return a;
}

void registerProjectRoutes(FakeTududi s) {
  final st = projectStoreOf(s);

  Map<String, dynamic> render(Map<String, dynamic> p) {
    final uid = p['uid'] as String;
    final tasks = s.tasks.values.where((t) => t['project_uid'] == uid);
    final area = st.areas[p['area_uid']];
    return {
      ...p,
      'Area': area == null ? null : {'name': area['name'], 'uid': area['uid']},
      'task_status': {
        'total': tasks.length,
        'done': tasks.where((t) => t['status'] == 2).length,
      },
    };
  }

  Map<String, dynamic> renderArea(Map<String, dynamic> a) => {
    ...a,
    'project_count': st.projects.values
        .where((p) => p['area_uid'] == a['uid'])
        .length,
  };

  String stamp(Map<String, dynamic> m) {
    final prev = DateTime.parse(m['updated_at'] as String);
    var now = DateTime.now().toUtc();
    if (!now.isAfter(prev)) now = prev.add(const Duration(milliseconds: 1));
    return m['updated_at'] = now.toIso8601String();
  }

  // ---- projects ----
  s.route('GET', '/projects', (ctx) {
    return FakeTududi.json(200, {
      'projects': [for (final p in st.projects.values) render(p)],
    });
  });
  s.route('GET', '/project/:uid', (ctx) {
    final p = st.projects[ctx.params['uid']];
    return p == null
        ? FakeTududi.json(404, {'error': 'Project not found'})
        : FakeTududi.json(200, render(p));
  });
  s.route('POST', '/project', (ctx) {
    final b = ctx.bodyMap;
    final name = (b['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) {
      return FakeTududi.json(400, {'error': 'Project name is required'});
    }
    final p = seedProject(
      s,
      name: name,
      description: b['description'] as String?,
      status: (b['status'] as String?) ?? 'not_started',
      priority: b['priority'] as int?,
      areaUid: b['area_uid'] as String?,
      pinToSidebar: (b['pin_to_sidebar'] as bool?) ?? false,
      dueDateAt: b['due_date_at'] as String?,
    );
    return FakeTududi.json(201, render(p));
  });
  s.route('PATCH', '/project/:uid', (ctx) {
    final p = st.projects[ctx.params['uid']];
    if (p == null) return FakeTududi.json(404, {'error': 'Project not found'});
    final b = ctx.bodyMap;
    if (b.containsKey('name') &&
        ((b['name'] as String?)?.trim() ?? '').isEmpty) {
      return FakeTududi.json(400, {'error': 'Project name is required'});
    }
    for (final e in b.entries) {
      if (e.key == 'uid' || e.key == 'id') continue;
      p[e.key] = e.value;
    }
    stamp(p);
    return FakeTududi.json(200, render(p));
  });
  s.route('DELETE', '/project/:uid', (ctx) {
    final p = st.projects.remove(ctx.params['uid']);
    return p == null
        ? FakeTududi.json(404, {'error': 'Project not found'})
        : FakeTududi.json(200, {'message': 'Project deleted successfully'});
  });

  // ---- areas (plural paths) ----
  s.route('GET', '/areas', (ctx) {
    return FakeTududi.json(200, [
      for (final a in st.areas.values) renderArea(a),
    ]);
  });
  s.route('POST', '/areas', (ctx) {
    final b = ctx.bodyMap;
    final name = (b['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) {
      return FakeTududi.json(400, {'error': 'Area name is required'});
    }
    final a = seedArea(s, name: name, description: b['description'] as String?);
    return FakeTududi.json(201, renderArea(a));
  });
  s.route('PATCH', '/areas/:uid', (ctx) {
    final a = st.areas[ctx.params['uid']];
    if (a == null) return FakeTududi.json(404, {'error': 'Area not found'});
    final b = ctx.bodyMap;
    if (b.containsKey('name') &&
        ((b['name'] as String?)?.trim() ?? '').isEmpty) {
      return FakeTududi.json(400, {'error': 'Area name is required'});
    }
    for (final e in b.entries) {
      if (e.key == 'uid' || e.key == 'id') continue;
      a[e.key] = e.value;
    }
    stamp(a);
    return FakeTududi.json(200, renderArea(a));
  });
  s.route('DELETE', '/areas/:uid', (ctx) {
    final a = st.areas.remove(ctx.params['uid']);
    if (a == null) return FakeTududi.json(404, {'error': 'Area not found'});
    for (final p in st.projects.values) {
      if (p['area_uid'] == a['uid']) p['area_uid'] = null;
    }
    return FakeTududi.json(200, {'message': 'Area deleted successfully'});
  });
}
