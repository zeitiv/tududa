import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/ids.dart';
import '../../tags/domain/tag.dart';

part 'note.freezed.dart';

@Freezed(makeCollectionsUnmodifiable: false)
abstract class Note with _$Note {
  const factory Note({
    int? id,

    /// Null until the create reached the server.
    NoteUid? uid,

    /// Local primary key; set for notes read from the offline store.
    LocalId? localId,
    String? title,
    String? content,

    /// Hex string such as `#FFD6D6`.
    String? color,
    ProjectUid? projectUid,
    LocalId? projectLocalId,
    String? projectName,
    @Default(<Tag>[]) List<Tag> tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _Note;

  const Note._();

  /// What routes use to open the note: the uid, else the local id.
  String? get routeId => uid?.value ?? localId?.value;
}

/// What is needed to create a note; the server assigns the uid.
@Freezed(makeCollectionsUnmodifiable: false)
abstract class NoteDraft with _$NoteDraft {
  const factory NoteDraft({
    String? title,
    String? content,
    String? color,
    ProjectUid? projectUid,

    /// Offline alternative to [projectUid] (a project not synced yet).
    LocalId? projectLocalId,
    @Default(<String>[]) List<String> tagNames,
  }) = _NoteDraft;
}
