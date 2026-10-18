import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_providers.dart';
import '../../core/ids.dart';

/// A project a task can be filed under (just what the picker needs).
class ProjectOption {
  const ProjectOption({required this.uid, required this.name});
  final ProjectUid uid;
  final String name;
}

/// Projects for the task form's picker. Kept separate from the projects
/// feature so the task form only depends on `uid` and `name`.
final projectOptionsProvider = FutureProvider<List<ProjectOption>>((ref) {
  final dio = ref.watch(dioProvider);
  return guard(() async {
    final res = await dio.get<Object?>('/projects');
    final data = res.data;
    final raw = data is List
        ? data
        : (data is Map && data['projects'] is List
              ? data['projects'] as List
              : const []);
    return [
      for (final p in raw)
        if (p is Map && p['uid'] is String)
          ProjectOption(
            uid: ProjectUid(p['uid'] as String),
            name: (p['name'] as String?) ?? '',
          ),
    ];
  });
});
