import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/patch.dart' as pt;
import '../../core/ids.dart';
import '../data/project_api.dart';
import '../data/project_repository.dart';
import '../data/project_tasks_source.dart';
import '../models/project_model.dart';

/// The HTTP stack already retries transient failures; Riverpod must not
/// retry again (and a 404 must surface at once).
Duration? noRetry(int retryCount, Object error) => null;

/// Projects of the signed-in user. Update and delete are optimistic and roll
/// back on failure, rethrowing the `ApiError`.
class ProjectList extends AsyncNotifier<List<Project>> {
  ProjectRepository get _repo => ref.read(projectRepositoryProvider);

  @override
  Future<List<Project>> build() => ref.watch(projectRepositoryProvider).list();

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repo.list);
  }

  Future<Project> create(NewProject project) async {
    final created = await _repo.create(project);
    state = AsyncData([...?state.value, created]);
    return created;
  }

  Future<Project> edit(ProjectUid uid, ProjectPatch patch) async {
    final before = state.value;
    if (before != null) {
      state = AsyncData([
        for (final p in before)
          if (p.uid == uid) applyProjectPatch(p, patch) else p,
      ]);
    }
    try {
      final saved = await _repo.update(uid, patch);
      state = AsyncData([
        for (final p in state.value ?? const <Project>[])
          if (p.uid == uid) saved else p,
      ]);
      ref.invalidate(projectDetailProvider(uid));
      return saved;
    } catch (_) {
      if (before != null) state = AsyncData(before);
      rethrow;
    }
  }

  Future<void> delete(ProjectUid uid) async {
    final before = state.value;
    if (before != null) {
      state = AsyncData([
        for (final p in before)
          if (p.uid != uid) p,
      ]);
    }
    try {
      await _repo.delete(uid);
    } catch (_) {
      if (before != null) state = AsyncData(before);
      rethrow;
    }
  }
}

final projectListProvider = AsyncNotifierProvider<ProjectList, List<Project>>(
  ProjectList.new,
  retry: noRetry,
);

/// One project by uid. A missing project surfaces as `NotFoundError`.
class ProjectDetail extends AsyncNotifier<Project> {
  ProjectDetail(this.uid);
  final ProjectUid uid;

  @override
  Future<Project> build() => ref.watch(projectRepositoryProvider).get(uid);

  Future<Project> edit(ProjectPatch patch) async {
    final before = state.value;
    if (before != null) state = AsyncData(applyProjectPatch(before, patch));
    try {
      final saved = await ref
          .read(projectRepositoryProvider)
          .update(uid, patch);
      state = AsyncData(saved);
      return saved;
    } catch (_) {
      if (before != null) state = AsyncData(before);
      rethrow;
    }
  }
}

final projectDetailProvider =
    AsyncNotifierProvider.family<ProjectDetail, Project, ProjectUid>(
      ProjectDetail.new,
      retry: noRetry,
    );

/// Tasks shown on a project's board, with optimistic status moves.
class ProjectTasks extends AsyncNotifier<List<ProjectTaskRef>> {
  ProjectTasks(this.project);
  final ProjectUid project;

  @override
  Future<List<ProjectTaskRef>> build() =>
      ref.watch(projectTasksSourceProvider).tasksFor(project);

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(projectTasksSourceProvider).tasksFor(project),
    );
  }

  Future<void> setStatus(ProjectTaskRef task, int status) async {
    final before = state.value;
    if (before != null) {
      state = AsyncData([
        for (final t in before)
          if (t.uid == task.uid) t.copyWith(status: status) else t,
      ]);
    }
    try {
      await ref.read(projectTasksSourceProvider).setStatus(task.uid, status);
    } catch (_) {
      if (before != null) state = AsyncData(before);
      rethrow;
    }
  }
}

final projectTasksProvider =
    AsyncNotifierProvider.family<
      ProjectTasks,
      List<ProjectTaskRef>,
      ProjectUid
    >(ProjectTasks.new, retry: noRetry);

/// Applies [patch] to [p] locally (for optimistic updates).
Project applyProjectPatch(Project p, ProjectPatch patch) {
  T? v<T>(pt.Patch<T> x, T? current) => switch (x) {
    pt.Set<T>(:final value) => value,
    _ => current,
  };
  return p.copyWith(
    name: v(patch.name, p.name) ?? p.name,
    description: v(patch.description, p.description),
    status: v(patch.status, p.status) ?? p.status,
    priority: v(patch.priority, p.priority),
    areaUid: v(patch.areaUid, p.areaUid),
    // The area name is refreshed from the server response.
    areaName: patch.areaUid.isSet ? null : p.areaName,
    pinToSidebar: v(patch.pinToSidebar, p.pinToSidebar) ?? p.pinToSidebar,
    taskShowCompleted:
        v(patch.taskShowCompleted, p.taskShowCompleted) ?? p.taskShowCompleted,
    taskSortOrder: v(patch.taskSortOrder, p.taskSortOrder) ?? p.taskSortOrder,
    dueDateAt: v(patch.dueDateAt, p.dueDateAt),
  );
}
