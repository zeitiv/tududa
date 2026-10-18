import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_providers.dart';
import '../domain/search_query.dart';
import '../domain/search_result.dart';
import 'search_api.dart';

abstract interface class SearchRepository {
  /// Pass a [CancelToken] and cancel it when a newer query supersedes this
  /// one; the future then fails with `CancelledError`.
  Future<SearchResponse> search(SearchQuery query, {CancelToken? cancelToken});
}

class RemoteSearchRepository implements SearchRepository {
  RemoteSearchRepository(this._api);
  final SearchApi _api;

  @override
  Future<SearchResponse> search(
    SearchQuery query, {
    CancelToken? cancelToken,
  }) => _api.search(query, cancelToken: cancelToken);
}

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => RemoteSearchRepository(SearchApi(ref.watch(dioProvider))),
);
