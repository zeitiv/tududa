import 'package:freezed_annotation/freezed_annotation.dart';

part 'area_dto.freezed.dart';
part 'area_dto.g.dart';

int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');

DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse('$v');

/// Wire shape of a Tududi area (`GET /areas`).
@freezed
abstract class AreaDto with _$AreaDto {
  const factory AreaDto({
    int? id,
    required String uid,
    @Default('') String name,
    String? description,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'updated_at') String? updatedAt,
    @JsonKey(name: 'project_count') int? projectCount,
  }) = _AreaDto;

  factory AreaDto.fromJson(Map<String, dynamic> json) =>
      _$AreaDtoFromJson(_normalize(json));

  static Map<String, dynamic> _normalize(Map<String, dynamic> json) => {
    ...json,
    'created_at': json['created_at'] ?? json['createdAt'],
    'updated_at': json['updated_at'] ?? json['updatedAt'],
    'project_count': _int(json['project_count'] ?? json['projectCount']),
    'uid': json['uid'] ?? '${json['id']}',
  };
}

extension AreaDtoDates on AreaDto {
  DateTime? get createdAtDate => _date(createdAt);
  DateTime? get updatedAtDate => _date(updatedAt);
}
