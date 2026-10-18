import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/api/api_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/ids.dart';
import '../../core/sync/sync_triggers.dart';
import '../../core/connectivity/connectivity_service.dart';
import '../../auth/session/session_providers.dart';
import '../../core/time/calendar_date.dart';
import '../domain/search_filter.dart';
import '../domain/search_query.dart';
import '../domain/search_result.dart';
import 'local_search.dart';
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

/// What the search screen shows: the hits and where they came from.
class SearchOutcome {
  const SearchOutcome(this.results, {this.offline = false});
  final List<SearchResult> results;

  /// True when the results come from the local database (device offline or
  /// the server unreachable).
  final bool offline;
}

/// Parses the raw query, asks the server when online and falls back to
/// [LocalSearch] when offline or the request fails transiently.
class SearchRepositoryFacade {
  SearchRepositoryFacade({
    required this.remote,
    required this.local,
    required this.isOnline,
    required this.today,
  });

  final SearchRepository remote;
  final LocalSearch local;
  final bool Function() isOnline;
  final CalendarDate Function() today;

  /// An empty [types] set means every type. Throws [CancelledError] when
  /// [cancelToken] is cancelled and any non-transient [ApiError].
  Future<SearchOutcome> search(
    String raw, {
    Set<SearchType> types = const {},
    CancelToken? cancelToken,
  }) async {
    final parsed = ParsedSearch.parse(raw);
    if (parsed.isEmpty) return const SearchOutcome([]);
    final day = today();
    if (parsed.hasTaskFilters &&
        types.isNotEmpty &&
        !types.contains(SearchType.task)) {
      return const SearchOutcome([]);
    }
    if (!isOnline()) return _local(parsed, types, day);
    try {
      return await _remote(parsed, types, day, cancelToken);
    } on CancelledError {
      rethrow;
    } on ApiError catch (e) {
      if (e.isTransient) return _local(parsed, types, day);
      rethrow;
    }
  }

  Future<SearchOutcome> _local(
    ParsedSearch p,
    Set<SearchType> types,
    CalendarDate day,
  ) async => SearchOutcome(
    await local.search(p, types: types, today: day),
    offline: true,
  );

  Future<SearchOutcome> _remote(
    ParsedSearch p,
    Set<SearchType> types,
    CalendarDate day,
    CancelToken? cancelToken,
  ) async {
    // Names are resolved through the local copy; a name we do not know
    // cannot match anything.
    AreaUid? areaUid;
    if (p.area != null) {
      areaUid = await local.areaUidByName(p.area!);
      if (areaUid == null) return const SearchOutcome([]);
    }
    final query = SearchQuery(
      text: p.text,
      filters: p.hasTaskFilters || p.project != null
          ? {SearchType.task}
          : types,
      tags: p.tags,
      status: p.flags.contains(SearchIs.done) ? SearchStatus.completed : null,
      priority: p.priority,
      due: switch (p.due) {
        SearchDue.today => 'today',
        SearchDue.tomorrow => 'tomorrow',
        _ => null,
      },
      areaUid: areaUid,
    );
    final res = await remote.search(query, cancelToken: cancelToken);
    var hits = applyTaskFilters(res.results, p, day);
    if (p.project != null) {
      final n = p.project!.toLowerCase();
      hits = [
        for (final h in hits)
          if (h is TaskHit && (h.projectName ?? '').toLowerCase() == n) h,
      ];
    }
    if (types.isNotEmpty) {
      hits = [
        for (final h in hits)
          if (types.contains(h.type)) h,
      ];
    }
    return SearchOutcome(rankResults(hits, p.text));
  }
}

final localSearchProvider = Provider<LocalSearch>(
  (ref) => LocalSearch(ref.watch(appDatabaseProvider)),
);

final searchFacadeProvider = Provider<SearchRepositoryFacade>((ref) {
  return SearchRepositoryFacade(
    remote: ref.watch(searchRepositoryProvider),
    local: ref.watch(localSearchProvider),
    isOnline: () =>
        ref.read(connectivityServiceProvider).current != NetworkStatus.offline,
    today: () => ref.read(userClockProvider).today(),
  );
});
