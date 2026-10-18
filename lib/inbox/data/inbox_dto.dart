import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/ids.dart';
import '../domain/inbox_item.dart';

part 'inbox_dto.freezed.dart';
part 'inbox_dto.g.dart';

/// Wire shape of an inbox item (backend `PUBLIC_ATTRIBUTES` + attachments).
@freezed
abstract class InboxItemDto with _$InboxItemDto {
  const InboxItemDto._();

  const factory InboxItemDto({
    @InboxUidConverter() required InboxUid uid,
    @Default('') String content,
    String? title,
    String? status,
    String? source,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _InboxItemDto;

  factory InboxItemDto.fromJson(Map<String, dynamic> json) =>
      _$InboxItemDtoFromJson(json);

  InboxItem toDomain() => InboxItem(
    uid: uid,
    content: content.isNotEmpty ? content : (title ?? ''),
    status: InboxStatus.parse(status),
    source: source ?? 'manual',
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
