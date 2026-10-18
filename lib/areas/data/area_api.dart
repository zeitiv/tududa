import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/api/patch.dart' show Patch, putPatch;
import '../../core/ids.dart';
import 'area_dto.dart';

/// Body for `POST /areas`.
class NewArea {
  const NewArea({required this.name, this.description});
  final String name;
  final String? description;

  Map<String, Object?> toJson() => {
    'name': name,
    if (description != null) 'description': description,
  };
}

/// Body for `PATCH /areas/:uid`; unset fields are left out of the request.
class AreaPatch {
  const AreaPatch({
    this.name = const Patch.unset(),
    this.description = const Patch.unset(),
  });
  final Patch<String> name;
  final Patch<String> description;

  Map<String, Object?> toJson() {
    final json = <String, Object?>{};
    putPatch(json, 'name', name);
    putPatch(json, 'description', description);
    return json;
  }
}

/// Thin HTTP layer over the plural `/areas` endpoints.
class AreaApi {
  AreaApi(this._dio);
  final Dio _dio;

  Future<List<AreaDto>> list() => guard(() async {
    final res = await _dio.get<Object?>('/areas');
    final data = res.data;
    final raw = data is List
        ? data
        : (data is Map ? (data['areas'] as List? ?? const []) : const []);
    return [
      for (final e in raw)
        AreaDto.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
  });

  Future<AreaDto> create(NewArea area) => guard(() async {
    final res = await _dio.post<Object?>('/areas', data: area.toJson());
    return _one(res.data);
  });

  Future<AreaDto> update(AreaUid uid, AreaPatch patch) => guard(() async {
    final res = await _dio.patch<Object?>(
      '/areas/${Uri.encodeComponent(uid.value)}',
      data: patch.toJson(),
    );
    return _one(res.data);
  });

  Future<void> delete(AreaUid uid) => guard(() async {
    await _dio.delete<Object?>('/areas/${Uri.encodeComponent(uid.value)}');
  });

  static AreaDto _one(Object? data) {
    if (data is Map) {
      final inner = data['area'];
      return AreaDto.fromJson(
        Map<String, dynamic>.from(inner is Map ? inner : data),
      );
    }
    throw FormatException('Expected an area object', data);
  }
}
