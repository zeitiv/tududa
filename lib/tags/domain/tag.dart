import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/ids.dart';

part 'tag.freezed.dart';

/// The single canonical tag type. [uid] is null only for tags embedded in
/// other payloads that carry just a name; [identifier] is what the tag
/// endpoints accept.
@freezed
abstract class Tag with _$Tag {
  const Tag._();

  const factory Tag({
    int? id,
    TagUid? uid,
    required String name,
    String? color,
    bool? pinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _Tag;

  String get identifier => uid?.value ?? name;
}
