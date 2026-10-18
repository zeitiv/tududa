import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_providers.dart';
import '../../core/api/patch.dart' show Patch;
import '../data/remote_tag_repository.dart';
import '../data/tag_patch.dart';
import '../data/tag_repository.dart';
import '../data/tags_api.dart';
import '../domain/tag.dart';

final tagRepositoryProvider = Provider<TagRepository>(
  (ref) => RemoteTagRepository(TagsApi(ref.watch(dioProvider))),
);

/// All tags. Mutations rethrow the repository's `ApiError` after leaving the
/// current list untouched.
class TagListNotifier extends AsyncNotifier<List<Tag>> {
  TagRepository get _repo => ref.read(tagRepositoryProvider);

  @override
  Future<List<Tag>> build() => ref.watch(tagRepositoryProvider).list();

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repo.list);
  }

  List<Tag> get _current => state.value ?? const [];

  Future<Tag> create(String name) async {
    final tag = await _repo.create(name);
    state = AsyncData([..._current.where((t) => t.name != tag.name), tag]);
    return tag;
  }

  Future<Tag> rename(Tag tag, String name) =>
      _update(tag, TagPatch(name: Patch.set(name)));

  /// A null [color] clears the colour.
  Future<Tag> recolor(Tag tag, String? color) => _update(
    tag,
    TagPatch(color: color == null ? const Patch.clear() : Patch.set(color)),
  );

  Future<Tag> setPinned(Tag tag, bool pinned) =>
      _update(tag, TagPatch(pinned: Patch.set(pinned)));

  Future<Tag> _update(Tag tag, TagPatch patch) async {
    final updated = await _repo.update(tag.identifier, patch);
    state = AsyncData([
      for (final t in _current)
        if (t.identifier == tag.identifier) updated else t,
    ]);
    return updated;
  }

  Future<void> delete(Tag tag) async {
    await _repo.delete(tag.identifier);
    state = AsyncData([
      for (final t in _current)
        if (t.identifier != tag.identifier) t,
    ]);
  }
}

final tagListProvider = AsyncNotifierProvider<TagListNotifier, List<Tag>>(
  TagListNotifier.new,
);
