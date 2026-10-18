import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/ids.dart';
import '../models/area_model.dart';
import 'area_api.dart';
import 'offline_area_repository.dart';

abstract class AreaRepository {
  Future<List<Area>> list();
  Future<Area> create(NewArea area);
  Future<Area> update(AreaUid uid, AreaPatch patch);
  Future<void> delete(AreaUid uid);
}

/// Talks to the Tududi server; every failure leaves as an `ApiError`.
class RemoteAreaRepository implements AreaRepository {
  RemoteAreaRepository(this._api);
  final AreaApi _api;

  @override
  Future<List<Area>> list() async => [
    for (final d in await _api.list()) Area.fromDto(d),
  ];

  @override
  Future<Area> create(NewArea area) async =>
      Area.fromDto(await _api.create(area));

  @override
  Future<Area> update(AreaUid uid, AreaPatch patch) async =>
      Area.fromDto(await _api.update(uid, patch));

  @override
  Future<void> delete(AreaUid uid) => _api.delete(uid);
}

/// The offline repository: reads the local table, writes table + outbox. The
/// sync handler talks to the server (see [RemoteAreaRepository] / `AreaApi`).
final areaRepositoryProvider = Provider<OfflineAreaRepository>(
  (ref) => OfflineAreaRepository(ref.watch(appDatabaseProvider)),
);
