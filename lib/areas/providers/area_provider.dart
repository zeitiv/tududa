import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/patch.dart' as pt;
import '../../core/ids.dart';
import '../data/area_api.dart';
import '../data/area_repository.dart';
import '../models/area_model.dart';

/// Areas of the signed-in user. Mutations are optimistic where the result is
/// predictable (update, delete) and roll back, rethrowing the `ApiError`.
class AreaList extends AsyncNotifier<List<Area>> {
  AreaRepository get _repo => ref.read(areaRepositoryProvider);

  @override
  Future<List<Area>> build() => ref.watch(areaRepositoryProvider).list();

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repo.list);
  }

  Future<Area> create(NewArea area) async {
    final created = await _repo.create(area);
    state = AsyncData([...?state.value, created]);
    return created;
  }

  Future<Area> edit(AreaUid uid, AreaPatch patch) async {
    final before = state.value;
    if (before != null) {
      state = AsyncData([
        for (final a in before)
          if (a.uid == uid) _apply(a, patch) else a,
      ]);
    }
    try {
      final saved = await _repo.update(uid, patch);
      state = AsyncData([
        for (final a in state.value ?? const <Area>[])
          if (a.uid == uid) saved else a,
      ]);
      return saved;
    } catch (_) {
      if (before != null) state = AsyncData(before);
      rethrow;
    }
  }

  Future<void> delete(AreaUid uid) async {
    final before = state.value;
    if (before != null) {
      state = AsyncData([
        for (final a in before)
          if (a.uid != uid) a,
      ]);
    }
    try {
      await _repo.delete(uid);
    } catch (_) {
      if (before != null) state = AsyncData(before);
      rethrow;
    }
  }

  static Area _apply(Area a, AreaPatch p) => a.copyWith(
    name: _valueOf(p.name) ?? a.name,
    description: p.description.isSet ? _valueOf(p.description) : a.description,
  );

  static String? _valueOf(pt.Patch<String> p) => switch (p) {
    pt.Set<String>(:final value) => value,
    _ => null,
  };
}

final areaListProvider = AsyncNotifierProvider<AreaList, List<Area>>(
  AreaList.new,
  retry: (_, _) => null,
);
