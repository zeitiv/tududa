import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/api/page.dart';
import '../../core/ids.dart';
import '../domain/inbox_item.dart';
import 'inbox_dto.dart';

/// Raw Tududi v1.9.4 inbox endpoints (paths relative to `/api`).
///
/// Backend facts (modules/inbox, v1.9.4):
/// - `GET /inbox` lists everything except processed/deleted items; with
///   `limit`/`offset` it returns `{items, pagination}`, otherwise a bare list.
/// - `POST /inbox {content, source}` -> 201 item (source defaults to manual).
/// - `PATCH /inbox/:uid {content?, status?}`; `DELETE` is a soft delete.
/// - `PATCH /inbox/:uid/process` takes an optional `{task_uid|project_uid|
///   note_uid}` (NOT a `target` object) and marks the item processed.
/// - `POST /inbox/analyze-text {content}` (NOT `text`).
class InboxApi {
  InboxApi(this._dio);
  final Dio _dio;

  Future<Page<InboxItemDto>> list({
    int limit = 20,
    int offset = 0,
    CancelToken? cancelToken,
  }) => guard(() async {
    final res = await _dio.get<Object?>(
      '/inbox',
      queryParameters: {'limit': limit, 'offset': offset},
      cancelToken: cancelToken,
    );
    return Page.fromJson(res.data, InboxItemDto.fromJson, itemsKey: 'items');
  });

  Future<InboxItemDto> get(InboxUid uid) => guard(() async {
    final res = await _dio.get<Object?>('/inbox/${uid.value}');
    return InboxItemDto.fromJson(_map(res.data));
  });

  Future<InboxItemDto> create(String content, {String source = 'manual'}) =>
      guard(() async {
        final res = await _dio.post<Object?>(
          '/inbox',
          data: {'content': content, 'source': source},
        );
        return InboxItemDto.fromJson(_map(res.data));
      });

  Future<InboxItemDto> update(
    InboxUid uid, {
    String? content,
    InboxStatus? status,
  }) => guard(() async {
    final res = await _dio.patch<Object?>(
      '/inbox/${uid.value}',
      data: {'content': ?content, if (status != null) 'status': status.wire},
    );
    return InboxItemDto.fromJson(_map(res.data));
  });

  Future<void> delete(InboxUid uid) =>
      guard(() async => _dio.delete<Object?>('/inbox/${uid.value}'));

  Future<InboxItemDto> process(InboxUid uid, {InboxProcessTarget? target}) =>
      guard(() async {
        final res = await _dio.patch<Object?>(
          '/inbox/${uid.value}/process',
          data: {if (target != null) target.key: target.uid},
        );
        return InboxItemDto.fromJson(_map(res.data));
      });

  Future<InboxAnalysis> analyzeText(String text, {CancelToken? cancelToken}) =>
      guard(() async {
        final res = await _dio.post<Object?>(
          '/inbox/analyze-text',
          data: {'content': text},
          cancelToken: cancelToken,
        );
        return InboxAnalysis.fromJson(_map(res.data));
      });

  static Map<String, dynamic> _map(Object? data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    throw FormatException('Expected an object', data);
  }
}
