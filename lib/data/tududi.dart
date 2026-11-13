import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../areas/models/area_model.dart';
import '../auth/providers/auth_provider.dart';
import '../core/services/api_service.dart';
import '../inbox/models/inbox_item_model.dart';
import '../notes/models/note_model.dart';
import '../projects/models/project_model.dart';
import '../tasks/models/task_model.dart';
import 'demo.dart';

/// Tududi's data, held on the device and changed there first: a tap shows
/// its result at once, the server hears about it right after, and if the
/// server says no the list is fetched again.

ApiService get _api => ApiService.instance;

bool _ok(Response r) => (r.statusCode ?? 500) < 400;

List<Map<String, dynamic>> _rows(dynamic data, List<String> keys) {
  dynamic list = data;
  if (data is Map) {
    for (final k in keys) {
      if (data[k] is List) {
        list = data[k];
        break;
      }
    }
  }
  if (list is! List) return const [];
  return [for (final e in list) if (e is Map) Map<String, dynamic>.from(e)];
}

Map<String, dynamic>? _row(dynamic data, String key) {
  if (data is! Map) return null;
  final inner = data[key];
  return Map<String, dynamic>.from(inner is Map ? inner : data);
}

var _tmp = 0;
String _tmpKey() => 'tmp-${_tmp++}';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

// ---------------------------------------------------------------- tasks

class TasksState {
  final List<Task> open;
  final List<Task> done;
  final Set<String> today;
  final bool loading;
  final bool loaded;
  final bool doneLoaded;
  final String? error;

  const TasksState({
    this.open = const [],
    this.done = const [],
    this.today = const {},
    this.loading = false,
    this.loaded = false,
    this.doneLoaded = false,
    this.error,
  });

  TasksState copyWith({
    List<Task>? open,
    List<Task>? done,
    Set<String>? today,
    bool? loading,
    bool? loaded,
    bool? doneLoaded,
    String? error,
  }) =>
      TasksState(
        open: open ?? this.open,
        done: done ?? this.done,
        today: today ?? this.today,
        loading: loading ?? this.loading,
        loaded: loaded ?? this.loaded,
        doneLoaded: doneLoaded ?? this.doneLoaded,
        error: error,
      );

  /// Today: what the server put there, what is due or overdue, what is in
  /// progress.
  bool isToday(Task t) {
    if (today.contains(t.key) || t.status == 1) return true;
    final due = t.dueDate;
    return due != null && !_day(due.toLocal()).isAfter(_day(DateTime.now()));
  }

  List<Task> get todayTasks => [for (final t in open) if (isToday(t)) t];

  List<Task> get upcoming {
    final list = [for (final t in open) if (t.dueDate != null && !isToday(t)) t];
    list.sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    return list;
  }

  int get doneToday {
    final now = _day(DateTime.now());
    return done.where((t) => t.completedAt != null && _day(t.completedAt!.toLocal()) == now).length;
  }
}

class TasksNotifier extends StateNotifier<TasksState> {
  final Ref ref;
  TasksNotifier(this.ref) : super(const TasksState());

  bool get _demo => ref.read(authProvider).demo;

  Future<void> load() async {
    if (_demo) {
      if (!state.loaded) {
        state = TasksState(open: demoTasks(), done: demoDone(), loaded: true, doneLoaded: true);
      }
      return;
    }
    state = state.copyWith(loading: true);
    try {
      final res = await Future.wait([
        _api.getTasks(queryParams: {'type': 'all'}),
        _api.getTasks(queryParams: {'type': 'today'}),
      ]);
      if (!_ok(res[0])) {
        state = state.copyWith(loading: false, error: 'Tududi ${res[0].statusCode}');
        return;
      }
      final all = _rows(res[0].data, ['tasks']).map(Task.fromJson).toList();
      final today = _ok(res[1])
          ? _rows(res[1].data, ['tasks']).map((e) => Task.fromJson(e).key).toSet()
          : <String>{};
      state = state.copyWith(
        open: [for (final t in all) if (!t.isCompleted && t.status != 5) t],
        today: today,
        loading: false,
        loaded: true,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: 'offline');
    }
  }

  Future<void> loadDone() async {
    if (_demo) return;
    try {
      for (final status in ['completed', 'done']) {
        final r = await _api.getTasks(queryParams: {'type': 'all', 'status': status});
        if (!_ok(r)) continue;
        final done = [
          for (final t in _rows(r.data, ['tasks']).map(Task.fromJson)) if (t.isCompleted) t,
        ];
        if (done.isEmpty && status == 'completed') continue;
        done.sort((a, b) => (b.completedAt ?? b.updatedAt ?? DateTime(2000))
            .compareTo(a.completedAt ?? a.updatedAt ?? DateTime(2000)));
        state = state.copyWith(done: done, doneLoaded: true);
        return;
      }
      state = state.copyWith(doneLoaded: true);
    } catch (_) {
      state = state.copyWith(doneLoaded: true);
    }
  }

  Map<String, dynamic> _patch(Task t) => t.toJson()
    ..['note'] = t.note ?? ''
    ..['due_date'] = t.dueDate?.toIso8601String()
    ..['project_id'] = t.projectId;

  Future<bool> add(Task draft) async {
    final temp = draft.copyWith(uid: _tmpKey());
    state = state.copyWith(open: [temp, ...state.open]);
    if (_demo) return true;
    try {
      final r = await _api.createTask(draft.toJson());
      final row = _ok(r) ? _row(r.data, 'task') : null;
      if (row == null) throw StateError('create');
      final saved = Task.fromJson(row);
      state = state.copyWith(open: [for (final t in state.open) t.key == temp.key ? saved : t]);
      return true;
    } catch (_) {
      state = state.copyWith(open: [for (final t in state.open) if (t.key != temp.key) t]);
      return false;
    }
  }

  Future<bool> save(Task t) async {
    state = state.copyWith(open: [for (final o in state.open) o.key == t.key ? t : o]);
    if (_demo) return true;
    try {
      final r = await _api.updateTask(t.key, _patch(t));
      if (_ok(r)) return true;
    } catch (_) {}
    await load();
    return false;
  }

  Future<bool> setStatus(Task t, int status) async {
    final next = t.copyWith(status: status);
    final wasDone = t.isCompleted;
    final isDone = next.isCompleted;
    state = state.copyWith(
      open: isDone
          ? [for (final o in state.open) if (o.key != t.key) o]
          : wasDone
              ? [next, ...state.open]
              : [for (final o in state.open) o.key == t.key ? next : o],
      done: isDone
          ? [next, for (final o in state.done) if (o.key != t.key) o]
          : [for (final o in state.done) if (o.key != t.key) o],
    );
    if (_demo) return true;
    try {
      final r = await _api.updateTask(t.key, {'status': status});
      if (_ok(r)) return true;
    } catch (_) {}
    await load();
    return false;
  }

  Future<bool> setDone(Task t, bool done) => setStatus(t, done ? 2 : 0);

  Future<bool> remove(Task t) async {
    state = state.copyWith(
      open: [for (final o in state.open) if (o.key != t.key) o],
      done: [for (final o in state.done) if (o.key != t.key) o],
    );
    if (_demo) return true;
    try {
      final r = await _api.deleteTask(t.key);
      if (_ok(r)) return true;
    } catch (_) {}
    await load();
    return false;
  }

  /// A task's steps. Tududi keeps them as tasks with a parent.
  Future<List<Task>> subtasks(Task parent) async {
    if (_demo) return parent.subtasks ?? const [];
    if (parent.id == null) return const [];
    try {
      final r = await _api.getSubtasks(parent.id);
      if (_ok(r)) return _rows(r.data, ['subtasks', 'tasks']).map(Task.fromJson).toList();
    } catch (_) {}
    return parent.subtasks ?? const [];
  }

  Future<Task?> addSubtask(Task parent, String name) async {
    final draft = Task(name: name, parentTaskId: parent.id, projectId: parent.projectId);
    if (_demo) return draft.copyWith(uid: _tmpKey());
    try {
      final r = await _api.createTask(draft.toJson());
      final row = _ok(r) ? _row(r.data, 'task') : null;
      return row == null ? null : Task.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  Future<bool> setSubtaskDone(Task sub, bool done) async {
    if (_demo) return true;
    try {
      return _ok(await _api.updateTask(sub.key, {'status': done ? 2 : 0}));
    } catch (_) {
      return false;
    }
  }
}

final tasksProvider =
    StateNotifierProvider<TasksNotifier, TasksState>((ref) => TasksNotifier(ref));

// ------------------------------------------------- lists of everything else

class Listed<T> {
  final List<T> items;
  final bool loading;
  final bool loaded;
  final String? error;
  const Listed({this.items = const [], this.loading = false, this.loaded = false, this.error});

  Listed<T> copyWith({List<T>? items, bool? loading, bool? loaded, String? error}) => Listed(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        loaded: loaded ?? this.loaded,
        error: error,
      );
}

abstract class ListNotifier<T> extends StateNotifier<Listed<T>> {
  final Ref ref;
  ListNotifier(this.ref) : super(Listed<T>());

  bool get demo => ref.read(authProvider).demo;
  List<T> seed();
  Future<List<T>?> fetch();

  Future<void> load() async {
    if (demo) {
      if (!state.loaded) state = Listed(items: seed(), loaded: true);
      return;
    }
    state = state.copyWith(loading: true);
    try {
      final items = await fetch();
      state = items == null
          ? state.copyWith(loading: false, error: 'error')
          : Listed(items: items, loaded: true);
    } catch (_) {
      state = state.copyWith(loading: false, error: 'offline');
    }
  }

  /// Shows [next] now, then runs [call]; if the server refuses, reloads.
  Future<bool> apply(List<T> next, Future<Response> Function() call, {bool reload = false}) async {
    state = state.copyWith(items: next);
    if (demo) return true;
    try {
      if (_ok(await call())) {
        if (reload) await load();
        return true;
      }
    } catch (_) {}
    await load();
    return false;
  }
}

class ProjectsNotifier extends ListNotifier<Project> {
  ProjectsNotifier(super.ref);
  @override
  List<Project> seed() => demoProjects();
  @override
  Future<List<Project>?> fetch() async {
    final r = await _api.getProjects();
    return _ok(r) ? _rows(r.data, ['projects']).map(Project.fromJson).toList() : null;
  }

  Future<bool> add(Project p) =>
      apply([...state.items, p], () => _api.createProject(p.toJson()), reload: true);
  Future<bool> save(Project p) => apply(
        [for (final o in state.items) o.id == p.id ? p : o],
        () => _api.updateProject(p.uid ?? p.id, p.toJson()),
      );
  Future<bool> remove(Project p) => apply(
        [for (final o in state.items) if (o.id != p.id) o],
        () => _api.deleteProject(p.uid ?? p.id),
      );
}

class AreasNotifier extends ListNotifier<Area> {
  AreasNotifier(super.ref);
  @override
  List<Area> seed() => demoAreas();
  @override
  Future<List<Area>?> fetch() async {
    final r = await _api.getAreas();
    return _ok(r) ? _rows(r.data, ['areas']).map(Area.fromJson).toList() : null;
  }

  Future<bool> add(String name) {
    final a = Area(id: demo ? -state.items.length - 1 : null, name: name);
    return apply([...state.items, a], () => _api.createArea(a.toJson()), reload: true);
  }

  Future<bool> save(Area a) => apply(
        [for (final o in state.items) o.id == a.id ? a : o],
        () => _api.updateArea(a.uid ?? a.id, a.toJson()),
      );
  Future<bool> remove(Area a) => apply(
        [for (final o in state.items) if (o.id != a.id) o],
        () => _api.deleteArea(a.uid ?? a.id),
      );
}

class NotesNotifier extends ListNotifier<Note> {
  NotesNotifier(super.ref);
  @override
  List<Note> seed() => demoNotes();
  @override
  Future<List<Note>?> fetch() async {
    final r = await _api.getNotes();
    return _ok(r) ? _rows(r.data, ['notes']).map(Note.fromJson).toList() : null;
  }

  Future<bool> add(Note n) {
    final local = demo ? Note(id: -state.items.length - 1, title: n.title, content: n.content) : n;
    return apply([local, ...state.items], () => _api.createNote(n.toJson()), reload: true);
  }

  Future<bool> save(Note n) => apply(
        [for (final o in state.items) o.id == n.id ? n : o],
        () => _api.updateNote(n.uid ?? n.id, n.toJson()),
      );
  Future<bool> remove(Note n) => apply(
        [for (final o in state.items) if (o.id != n.id) o],
        () => _api.deleteNote(n.uid ?? n.id),
      );
}

class InboxNotifier extends ListNotifier<InboxItem> {
  InboxNotifier(super.ref);
  @override
  List<InboxItem> seed() => demoInbox();
  @override
  Future<List<InboxItem>?> fetch() async {
    final r = await _api.getInboxItems();
    if (!_ok(r)) return null;
    return [
      for (final i in _rows(r.data, ['items', 'inboxItems', 'inbox_items']).map(InboxItem.fromJson))
        if (!i.isProcessed && !i.isIgnored) i,
    ];
  }

  Future<bool> add(String content) {
    final item = InboxItem(uid: _tmpKey(), content: content, createdAt: DateTime.now());
    return apply([item, ...state.items], () => _api.createInboxItem(content), reload: true);
  }

  List<InboxItem> _without(InboxItem i) =>
      [for (final o in state.items) if (!identical(o, i) && (o.uid ?? o.id) != (i.uid ?? i.id)) o];

  Future<bool> process(InboxItem i) =>
      apply(_without(i), () => _api.updateInboxItem(i.uid ?? i.id, {'status': 'processed'}));
  Future<bool> remove(InboxItem i) =>
      apply(_without(i), () => _api.deleteInboxItem(i.uid ?? i.id));
}

final projectsProvider =
    StateNotifierProvider<ProjectsNotifier, Listed<Project>>((ref) => ProjectsNotifier(ref));
final areasProvider =
    StateNotifierProvider<AreasNotifier, Listed<Area>>((ref) => AreasNotifier(ref));
final notesProvider =
    StateNotifierProvider<NotesNotifier, Listed<Note>>((ref) => NotesNotifier(ref));
final inboxProvider =
    StateNotifierProvider<InboxNotifier, Listed<InboxItem>>((ref) => InboxNotifier(ref));
