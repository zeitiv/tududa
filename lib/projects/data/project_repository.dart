import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_providers.dart';
import '../../core/ids.dart';
import '../models/project_model.dart';
import 'project_api.dart';

abstract class ProjectRepository {
  Future<List<Project>> list();
  Future<Project> get(ProjectUid uid);
  Future<Project> create(NewProject project);
  Future<Project> update(ProjectUid uid, ProjectPatch patch);
  Future<void> delete(ProjectUid uid);
}

/// Talks to the Tududi server; every failure leaves as an `ApiError`.
class RemoteProjectRepository implements ProjectRepository {
  RemoteProjectRepository(this._api);
  final ProjectApi _api;

  @override
  Future<List<Project>> list() async => [
    for (final d in await _api.list()) Project.fromDto(d),
  ];

  @override
  Future<Project> get(ProjectUid uid) async =>
      Project.fromDto(await _api.get(uid));

  @override
  Future<Project> create(NewProject project) async =>
      Project.fromDto(await _api.create(project));

  @override
  Future<Project> update(ProjectUid uid, ProjectPatch patch) async =>
      Project.fromDto(await _api.update(uid, patch));

  @override
  Future<void> delete(ProjectUid uid) => _api.delete(uid);
}

final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => RemoteProjectRepository(ProjectApi(ref.watch(dioProvider))),
);
