import '../domain/tag.dart';
import 'dto/tag_dto.dart';

extension TagDtoMapper on TagDto {
  Tag toDomain() => Tag(
    id: id,
    uid: uid,
    name: name,
    color: color,
    pinned: pinned,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
