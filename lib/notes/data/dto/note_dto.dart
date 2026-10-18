import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/ids.dart';
import '../../../tags/data/dto/tag_dto.dart';

part 'note_dto.freezed.dart';
part 'note_dto.g.dart';

Object? _readProject(Map<dynamic, dynamic> json, String key) =>
    json['Project'] ?? json['project'];

Object? _readTags(Map<dynamic, dynamic> json, String key) =>
    json['tags'] ?? json['Tags'];

/// The `Project` stub embedded in a note.
@freezed
abstract class NoteProjectDto with _$NoteProjectDto {
  const factory NoteProjectDto({
    int? id,
    @NullableProjectUidConverter() ProjectUid? uid,
    String? name,
  }) = _NoteProjectDto;

  factory NoteProjectDto.fromJson(Map<String, dynamic> json) =>
      _$NoteProjectDtoFromJson(json);
}

@Freezed(makeCollectionsUnmodifiable: false)
abstract class NoteDto with _$NoteDto {
  const factory NoteDto({
    int? id,
    @NoteUidConverter() required NoteUid uid,
    String? title,
    String? content,
    String? color,
    @NullableProjectUidConverter() ProjectUid? projectUid,
    @JsonKey(readValue: _readProject) NoteProjectDto? project,
    @JsonKey(readValue: _readTags) List<TagDto>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _NoteDto;

  factory NoteDto.fromJson(Map<String, dynamic> json) =>
      _$NoteDtoFromJson(json);
}
