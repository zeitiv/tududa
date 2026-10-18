import '../../core/api/patch.dart';

/// Partial update for `PATCH /tag/:identifier`.
class TagPatch {
  const TagPatch({
    this.name = const Patch.unset(),
    this.pinned = const Patch.unset(),
    this.color = const Patch.unset(),
  });

  final Patch<String> name;
  final Patch<bool> pinned;
  final Patch<String> color;

  Map<String, Object?> toJson() {
    final json = <String, Object?>{};
    putPatch(json, 'name', name);
    putPatch(json, 'pinned', pinned);
    putPatch(json, 'color', color);
    return json;
  }
}
