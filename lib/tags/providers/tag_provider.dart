import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/patch.dart' show Patch;
import '../../core/db/app_database.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/sync/sync_handler.dart';
import '../data/offline_tag_repository.dart';
import '../data/tag_patch.dart';
import '../domain/tag.dart';

/// Reads and writes go to the local database; `TagSyncHandler` moves them to
/// the server.
final tagRepositoryProvider = Provider<OfflineTagRepository>(
  (ref) => OfflineTagRepository(ref.watch(appDatabaseProvider)),
);

/// All tags, live from the local database. Mutations return as soon as they
/// are stored locally and throw an `ApiError` (validation, not found) for
/// input the server would refuse.
class TagListNotifier extends StreamNotifier<List<Tag>> {
  OfflineTagRepository get _repo => ref.read(tagRepositoryProvider);

  @override
  Stream<List<Tag>> build() => ref.watch(tagRepositoryProvider).watchList();

  /// Pull-to-refresh: runs a sync cycle now.
  Future<void> refresh() =>
      ref.read(syncEngineProvider).requestSync(SyncReason.manual);

  Future<Tag> create(String name) => _repo.create(name);

  Future<Tag> rename(Tag tag, String name) =>
      _update(tag, TagPatch(name: Patch.set(name)));

  /// A null [color] clears the colour.
  Future<Tag> recolor(Tag tag, String? color) => _update(
    tag,
    TagPatch(color: color == null ? const Patch.clear() : Patch.set(color)),
  );

  Future<Tag> setPinned(Tag tag, bool pinned) =>
      _update(tag, TagPatch(pinned: Patch.set(pinned)));

  Future<Tag> _update(Tag tag, TagPatch patch) =>
      _repo.update(_key(tag), patch);

  Future<void> delete(Tag tag) => _repo.delete(_key(tag));

  /// The local id when known: it stays valid across renames and before the
  /// tag has a uid.
  String _key(Tag tag) => tag.localId?.value ?? tag.identifier;
}

final tagListProvider = StreamNotifierProvider<TagListNotifier, List<Tag>>(
  TagListNotifier.new,
);
