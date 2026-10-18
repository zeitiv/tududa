import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/api/page.dart';
import '../../core/ids.dart';
import 'dto/note_dto.dart';
import 'note_patch.dart';

/// Thin typed wrapper over the note endpoints (paths relative to `/api`).
class NotesApi {
  NotesApi(this._dio);
  final Dio _dio;

  /// `GET /notes`; the response is a bare list or `{notes: [...]}`.
  Future<List<NoteDto>> list({ProjectUid? projectUid}) => guard(() async {
    final res = await _dio.get<Object?>(
      '/notes',
      queryParameters: {
        if (projectUid != null) 'project_uid': projectUid.value,
      },
    );
    return Page.fromJson(res.data, NoteDto.fromJson, itemsKey: 'notes').items;
  });

  Future<NoteDto> get(NoteUid uid) => guard(() async {
    final res = await _dio.get<Object?>(
      '/note/${Uri.encodeComponent(uid.value)}',
    );
    return _one(res.data);
  });

  Future<NoteDto> create(Map<String, Object?> body) => guard(() async {
    final res = await _dio.post<Object?>('/note', data: body);
    return _one(res.data);
  });

  Future<NoteDto> update(NoteUid uid, NotePatch patch) => guard(() async {
    final res = await _dio.patch<Object?>(
      '/note/${Uri.encodeComponent(uid.value)}',
      data: patch.toJson(),
    );
    return _one(res.data);
  });

  Future<void> delete(NoteUid uid) => guard(() async {
    await _dio.delete<Object?>('/note/${Uri.encodeComponent(uid.value)}');
  });

  static NoteDto _one(Object? data) {
    if (data is! Map) throw FormatException('Expected an object', data);
    final inner = data['note'];
    return NoteDto.fromJson(
      Map<String, dynamic>.from(inner is Map ? inner : data),
    );
  }
}
