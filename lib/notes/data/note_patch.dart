import '../../core/api/patch.dart';
import '../../core/ids.dart';

/// Partial update for `PATCH /note/:uid`: unset fields are left out of the
/// request, cleared fields are sent as `null`, [tags] replaces the whole set.
class NotePatch {
  const NotePatch({
    this.title = const Patch.unset(),
    this.content = const Patch.unset(),
    this.color = const Patch.unset(),
    this.projectUid = const Patch.unset(),
    this.tags = const Patch.unset(),
  });

  final Patch<String> title;
  final Patch<String> content;
  final Patch<String> color;
  final Patch<ProjectUid> projectUid;

  /// Tag names.
  final Patch<List<String>> tags;

  Map<String, Object?> toJson() {
    final json = <String, Object?>{};
    putPatch(json, 'title', title);
    putPatch(json, 'content', content);
    putPatch(json, 'color', color);
    putPatch(json, 'project_uid', projectUid, (u) => u.value);
    putPatch(
      json,
      'tags',
      tags,
      (names) => [
        for (final n in names) {'name': n},
      ],
    );
    return json;
  }
}
