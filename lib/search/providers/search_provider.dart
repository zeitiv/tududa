import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../settings/providers/settings_provider.dart';
import '../data/recent_searches.dart';
import '../data/search_repository.dart';
import '../domain/search_query.dart';
import '../domain/search_result.dart';

export '../data/search_repository.dart'
    show SearchOutcome, SearchRepositoryFacade, searchFacadeProvider;

/// Delay between the last keystroke and the request.
final searchDebounceProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 250),
);

enum SearchPhase { idle, loading, data, error }

class SearchState {
  const SearchState({
    this.text = '',
    this.types = const {},
    this.phase = SearchPhase.idle,
    this.results = const [],
    this.offline = false,
    this.error,
  });

  final String text;

  /// Empty means every type.
  final Set<SearchType> types;
  final SearchPhase phase;

  /// While [phase] is loading these are the previous query's results.
  final List<SearchResult> results;

  /// The results come from the local database.
  final bool offline;
  final Object? error;

  SearchState copyWith({
    String? text,
    Set<SearchType>? types,
    SearchPhase? phase,
    List<SearchResult>? results,
    bool? offline,
    Object? error,
  }) => SearchState(
    text: text ?? this.text,
    types: types ?? this.types,
    phase: phase ?? this.phase,
    results: results ?? this.results,
    offline: offline ?? this.offline,
    error: phase == SearchPhase.error ? error : null,
  );
}

/// Debounced search. Only the newest query's outcome is ever applied: older
/// requests are cancelled and, should they still complete, ignored.
class SearchNotifier extends Notifier<SearchState> {
  Timer? _timer;
  CancelToken? _cancel;
  int _seq = 0;

  @override
  SearchState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _cancel?.cancel();
      _seq++;
    });
    return const SearchState();
  }

  /// Sets the raw query. Runs after the debounce, or at once when
  /// [immediate] (submit, chips, deep links).
  void setText(String text, {bool immediate = false}) {
    state = state.copyWith(text: text);
    _schedule(immediate: immediate);
  }

  void setTypes(Set<SearchType> types) {
    state = state.copyWith(types: types);
    _schedule(immediate: true);
  }

  void retry() => _schedule(immediate: true);

  void _schedule({required bool immediate}) {
    _timer?.cancel();
    if (ParsedSearch.parse(state.text).isEmpty) {
      _cancelInFlight();
      state = state.copyWith(
        phase: SearchPhase.idle,
        results: const [],
        offline: false,
      );
      return;
    }
    state = state.copyWith(phase: SearchPhase.loading);
    final delay = immediate ? Duration.zero : ref.read(searchDebounceProvider);
    _timer = Timer(delay, _run);
  }

  void _cancelInFlight() {
    _seq++;
    _cancel?.cancel();
    _cancel = null;
  }

  Future<void> _run() async {
    _cancelInFlight();
    final seq = _seq;
    final token = _cancel = CancelToken();
    final text = state.text;
    try {
      final outcome = await ref
          .read(searchFacadeProvider)
          .search(text, types: state.types, cancelToken: token);
      if (seq != _seq) return;
      state = state.copyWith(
        phase: SearchPhase.data,
        results: outcome.results,
        offline: outcome.offline,
      );
    } on CancelledError {
      // superseded
    } catch (e) {
      if (seq != _seq) return;
      state = state.copyWith(phase: SearchPhase.error, error: e);
    }
  }
}

final searchControllerProvider =
    NotifierProvider.autoDispose<SearchNotifier, SearchState>(
      SearchNotifier.new,
    );

class RecentSearchesNotifier extends Notifier<List<String>> {
  RecentSearches get _store =>
      RecentSearches(ref.read(sharedPreferencesProvider));

  @override
  List<String> build() => _store.load();

  Future<void> add(String query) async => state = await _store.add(query);
  Future<void> remove(String query) async => state = await _store.remove(query);
  Future<void> clear() async {
    await _store.clear();
    state = const [];
  }
}

final recentSearchesProvider =
    NotifierProvider<RecentSearchesNotifier, List<String>>(
      RecentSearchesNotifier.new,
    );
