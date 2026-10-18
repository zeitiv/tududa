import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../domain/search_query.dart';
import '../domain/search_result.dart';

/// `GET /api/search`. See [SearchQuery] for the backend notes.
class SearchApi {
  SearchApi(this._dio);
  final Dio _dio;

  Future<SearchResponse> search(
    SearchQuery query, {
    CancelToken? cancelToken,
  }) => guard(() async {
    final res = await _dio.get<Object?>(
      '/search',
      queryParameters: query.toQueryParameters(),
      cancelToken: cancelToken,
    );
    return SearchResponse.fromJson(res.data);
  });
}
