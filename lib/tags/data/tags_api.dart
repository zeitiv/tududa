import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/api/page.dart';
import '../../core/ids.dart';
import 'dto/tag_dto.dart';
import 'tag_patch.dart';

/// Thin typed wrapper over the tag endpoints (paths relative to `/api`).
class TagsApi {
  TagsApi(this._dio);
  final Dio _dio;

  Future<List<TagDto>> list() => guard(() async {
    final res = await _dio.get<Object?>('/tags');
    return Page.fromJson(res.data, TagDto.fromJson, itemsKey: 'tags').items;
  });

  /// Looks a tag up by [uid] or [name] (exactly one is expected).
  Future<TagDto> get({TagUid? uid, String? name}) => guard(() async {
    final res = await _dio.get<Object?>(
      '/tag',
      queryParameters: {'uid': ?uid?.value, 'name': ?name},
    );
    return TagDto.fromJson(_unwrap(res.data));
  });

  Future<TagDto> create(String name) => guard(() async {
    final res = await _dio.post<Object?>('/tag', data: {'name': name});
    return TagDto.fromJson(_unwrap(res.data));
  });

  Future<TagDto> update(String identifier, TagPatch patch) => guard(() async {
    final res = await _dio.patch<Object?>(
      '/tag/${Uri.encodeComponent(identifier)}',
      data: patch.toJson(),
    );
    return TagDto.fromJson(_unwrap(res.data));
  });

  Future<void> delete(String identifier) => guard(() async {
    await _dio.delete<Object?>('/tag/${Uri.encodeComponent(identifier)}');
  });

  static Map<String, dynamic> _unwrap(Object? data) {
    if (data is! Map) throw FormatException('Expected an object', data);
    final inner = data['tag'];
    return Map<String, dynamic>.from(inner is Map ? inner : data);
  }
}
