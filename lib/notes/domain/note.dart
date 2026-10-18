import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/ids.dart';
import '../../tags/domain/tag.dart';

part 'note.freezed.dart';

@Freezed(makeCollectionsUnmodifiable: false)
abstract class Note with _$Note {
  const factory Note({
    int? id,
    required NoteUid uid,
    String? title,
    String? content,

    /// Hex string such as `#FFD6D6`.
    String? color,
    ProjectUid? projectUid,
    String? projectName,
    @Default(<Tag>[]) List<Tag> tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _Note;
}

/// What is needed to create a note; the server assigns the uid.
@Freezed(makeCollectionsUnmodifiable: false)
abstract class NoteDraft with _$NoteDraft {
  const factory NoteDraft({
    String? title,
    String? content,
    String? color,
    ProjectUid? projectUid,
    @Default(<String>[]) List<String> tagNames,
  }) = _NoteDraft;
}
