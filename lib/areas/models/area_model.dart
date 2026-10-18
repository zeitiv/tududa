import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/ids.dart';
import '../data/area_dto.dart';

part 'area_model.freezed.dart';

/// Domain area, identified by [uid].
@freezed
abstract class Area with _$Area {
  const factory Area({
    required AreaUid uid,
    int? id,
    required String name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? projectCount,
  }) = _Area;

  factory Area.fromDto(AreaDto dto) => Area(
    uid: AreaUid(dto.uid),
    id: dto.id,
    name: dto.name,
    description: dto.description,
    createdAt: dto.createdAtDate,
    updatedAt: dto.updatedAtDate,
    projectCount: dto.projectCount,
  );
}
