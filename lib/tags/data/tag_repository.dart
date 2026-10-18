import '../../core/ids.dart';
import '../domain/tag.dart';
import 'tag_patch.dart';

/// Tag access for the rest of the app. All failures are [ApiError]s.
abstract interface class TagRepository {
  Future<List<Tag>> list();
  Future<Tag> get({TagUid? uid, String? name});
  Future<Tag> create(String name);

  /// [identifier] is the tag's uid or, failing that, its name.
  Future<Tag> update(String identifier, TagPatch patch);
  Future<void> delete(String identifier);
}
