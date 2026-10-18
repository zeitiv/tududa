import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/ids.dart';

part 'tag_dto.freezed.dart';
part 'tag_dto.g.dart';

/// A tag as the server sends it. Tags embedded in tasks or notes may carry
/// only `name` (and `color`), so everything but the name is optional.
@freezed
abstract class TagDto with _$TagDto {
  const factory TagDto({
    int? id,
    @NullableTagUidConverter() TagUid? uid,
    @Default('') String name,
    String? color,
    bool? pinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _TagDto;

  factory TagDto.fromJson(Map<String, dynamic> json) => _$TagDtoFromJson(json);
}
