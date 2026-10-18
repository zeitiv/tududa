import '../../core/ids.dart';
import '../domain/tag.dart';
import 'tag_mapper.dart';
import 'tag_patch.dart';
import 'tag_repository.dart';
import 'tags_api.dart';

class RemoteTagRepository implements TagRepository {
  RemoteTagRepository(this._api);
  final TagsApi _api;

  @override
  Future<List<Tag>> list() async => [
    for (final d in await _api.list()) d.toDomain(),
  ];

  @override
  Future<Tag> get({TagUid? uid, String? name}) async =>
      (await _api.get(uid: uid, name: name)).toDomain();

  @override
  Future<Tag> create(String name) async => (await _api.create(name)).toDomain();

  @override
  Future<Tag> update(String identifier, TagPatch patch) async =>
      (await _api.update(identifier, patch)).toDomain();

  @override
  Future<void> delete(String identifier) => _api.delete(identifier);
}
