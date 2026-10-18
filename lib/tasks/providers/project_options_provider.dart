import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/ids.dart';

/// A project a task can be filed under (just what the picker needs).
class ProjectOption {
  const ProjectOption({required this.uid, required this.name});
  final ProjectUid uid;
  final String name;
}

/// Projects for the task form's picker, from the offline store (so it works
/// without a connection). A project created offline has no server uid yet;
/// its local id stands in until it syncs.
final projectOptionsProvider = StreamProvider<List<ProjectOption>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final query = db.select(db.projects)
    ..where((p) => p.pendingDelete.equals(false) & p.name.equals('').not())
    ..orderBy([(p) => OrderingTerm.asc(p.name)]);
  return query.watch().map(
    (rows) => [
      for (final p in rows)
        ProjectOption(uid: ProjectUid(p.uid ?? p.localId), name: p.name),
    ],
  );
});
