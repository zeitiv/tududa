import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ids.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/sync/sync_handler.dart';
import '../data/area_api.dart';
import '../data/area_repository.dart';
import '../models/area_model.dart';

/// Areas of the signed-in user, live from the local table. Edits are written
/// locally (so they show at once) and synced in the background; a failed sync
/// rolls the row back and reports a notice on the sync screen.
class AreaList extends StreamNotifier<List<Area>> {
  @override
  Stream<List<Area>> build() => ref.watch(areaRepositoryProvider).watchAll();

  /// Pull-to-refresh: runs a sync cycle.
  Future<void> refresh() =>
      ref.read(syncEngineProvider).requestSync(SyncReason.manual);

  Future<Area> create(NewArea area) =>
      ref.read(areaRepositoryProvider).create(area);

  Future<Area> edit(AreaUid uid, AreaPatch patch) =>
      ref.read(areaRepositoryProvider).update(uid, patch);

  Future<void> delete(AreaUid uid) =>
      ref.read(areaRepositoryProvider).delete(uid);
}

final areaListProvider = StreamNotifierProvider<AreaList, List<Area>>(
  AreaList.new,
  retry: (_, _) => null,
);
