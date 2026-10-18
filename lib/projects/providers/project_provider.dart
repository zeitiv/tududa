import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/patch.dart' as pt;
import '../../core/api/api_error.dart';
import '../../core/ids.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/sync/sync_handler.dart';
import '../data/project_api.dart';
import '../data/offline_project_repository.dart';
import '../data/project_repository.dart';
import '../data/project_tasks_source.dart';
import '../models/project_model.dart';

/// The HTTP stack already retries transient failures; Riverpod must not
/// retry again (and a 404 must surface at once).
Duration? noRetry(int retryCount, Object error) => null;

/// Projects of the signed-in user, live from the local table. Edits are
/// written locally (so they show at once) and synced in the background; a
/// failed sync rolls the row back and reports a notice on the sync screen.
class ProjectList extends StreamNotifier<List<Project>> {
  OfflineProjectRepository get _repo => ref.read(projectRepositoryProvider);

  @override
  Stream<List<Project>> build() =>
      ref.watch(projectRepositoryProvider).watchAll();

  /// Pull-to-refresh: runs a sync cycle.
  Future<void> refresh() =>
      ref.read(syncEngineProvider).requestSync(SyncReason.manual);

  Future<Project> create(NewProject project) => _repo.create(project);

  Future<Project> edit(ProjectUid uid, ProjectPatch patch) =>
      _repo.update(uid, patch);

  Future<void> delete(ProjectUid uid) => _repo.delete(uid);
}

final projectListProvider = StreamNotifierProvider<ProjectList, List<Project>>(
  ProjectList.new,
  retry: noRetry,
);

/// One project by uid (or local id). A missing project surfaces as
/// `NotFoundError`.
class ProjectDetail extends StreamNotifier<Project> {
  ProjectDetail(this.uid);
  final ProjectUid uid;

  @override
  Stream<Project> build() => ref
      .watch(projectRepositoryProvider)
      .watchByKey(uid.value)
      .map((p) => p ?? (throw const NotFoundError('Project not found')));

  Future<Project> edit(ProjectPatch patch) =>
      ref.read(projectRepositoryProvider).update(uid, patch);
}

final projectDetailProvider =
    StreamNotifierProvider.family<ProjectDetail, Project, ProjectUid>(
      ProjectDetail.new,
      retry: noRetry,
    );

/// Tasks shown on a project's board, live from the tasks table; status moves
/// are written locally and show at once.
class ProjectTasks extends StreamNotifier<List<ProjectTaskRef>> {
  ProjectTasks(this.project);
  final ProjectUid project;

  @override
  Stream<List<ProjectTaskRef>> build() =>
      ref.watch(projectTasksSourceProvider).watchTasksFor(project);

  Future<void> refresh() =>
      ref.read(syncEngineProvider).requestSync(SyncReason.manual);

  Future<void> setStatus(ProjectTaskRef task, int status) =>
      ref.read(projectTasksSourceProvider).setStatus(task.uid, status);
}

final projectTasksProvider =
    StreamNotifierProvider.family<
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
