import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/ids.dart';
import '../data/offline_inbox_repository.dart';
import '../domain/inbox_item.dart';

/// Loaded inbox pages. The list is newest first, as the server orders it.
class InboxList {
  const InboxList({
    this.items = const [],
    this.total = 0,
    this.hasMore = false,
    this.loadingMore = false,
  });

  final List<InboxItem> items;
  final int total;
  final bool hasMore;
  final bool loadingMore;

  InboxList copyWith({
    List<InboxItem>? items,
    int? total,
    bool? hasMore,
    bool? loadingMore,
  }) => InboxList(
    items: items ?? this.items,
    total: total ?? this.total,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

const inboxPageSize = 20;

final inboxProvider = AsyncNotifierProvider<InboxNotifier, InboxList>(
  InboxNotifier.new,
);

/// The list is reactive over the local database (so captures, ignores and
/// deletes show instantly, offline too). `refresh` / `loadMore` page the
/// SERVER and merge the rows into the database; while offline they fail
/// quietly and the local rows stay.
class InboxNotifier extends AsyncNotifier<InboxList> {
  OfflineInboxRepository get _repo => ref.read(inboxRepositoryProvider);

  List<InboxItem> _items = const [];
  int? _serverTotal;
  bool _hasMore = false;
  bool _loadingMore = false;
  int _nextOffset = 0;
  Future<void> _initial = Future.value();

  /// Completes when the first server page was requested (success or not).
  @visibleForTesting
  Future<void> get initialLoad => _initial;

  @override
  Future<InboxList> build() {
    final repo = ref.watch(inboxRepositoryProvider);
    final first = Completer<InboxList>();
    final sub = repo.watch().listen(
      (items) {
        _items = items;
        final next = _compose();
        if (first.isCompleted) {
          state = AsyncData(next);
        } else {
          first.complete(next);
        }
      },
      onError: (Object e, StackTrace st) {
        if (first.isCompleted) {
          state = AsyncError(e, st);
        } else {
          first.completeError(e, st);
        }
      },
    );
    ref.onDispose(sub.cancel);
    _initial = _loadPage(0).then((_) {
      if (ref.mounted) _publish();
    });
    return first.future.then((_) => _compose());
  }

  InboxList _compose() {
    final local = _items.length;
    return InboxList(
      items: _items,
      total: _hasMore ? (_serverTotal ?? local).clamp(local, 1 << 30) : local,
      hasMore: _hasMore,
      loadingMore: _loadingMore,
    );
  }

  void _publish() {
    if (state.hasValue) state = AsyncData(_compose());
  }

  /// Fetches the server page at [offset]; false when it failed (offline).
  Future<bool> _loadPage(int offset) async {
    try {
      final page = await _repo.loadServerPage(
        limit: inboxPageSize,
        offset: offset,
      );
      if (!ref.mounted) return false;
      _serverTotal = page.total;
      _nextOffset = offset + page.items.length;
      _hasMore = page.hasMore && page.items.isNotEmpty;
      return true;
    } on ApiError catch (e) {
      debugPrint('Inbox page failed: $e');
      return false;
    }
  }

  /// Reloads the first server page. The local list stays visible meanwhile.
  Future<void> refresh() async {
    await _loadPage(0);
    if (ref.mounted) _publish();
  }

  Future<void> loadMore() async {
    final cur = state.value;
    if (cur == null || !_hasMore || _loadingMore) return;
    _loadingMore = true;
    _publish();
    await _loadPage(_nextOffset);
    if (!ref.mounted) return;
    _loadingMore = false;
    _publish();
  }

  Future<bool> capture(String text, {String source = 'mobile'}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    return _run(() => _repo.capture(trimmed, source: source));
  }

  /// Marks the item processed; it leaves the list at once (a swiped-away
  /// `Dismissible` must be gone from the tree) and the server is told on the
  /// next sync. [target] may name a task / project / note by uid or local id.
  Future<bool> process(InboxUid uid, {InboxProcessTarget? target}) => _run(() {
    _remove(uid);
    return _repo.process(uid, target: target);
  });

  Future<bool> ignore(InboxUid uid) => _run(() {
    _items = [
      for (final i in _items)
        i.uid == uid ? i.copyWith(status: InboxStatus.ignored) : i,
    ];
    _publish();
    return _repo.ignore(uid);
  });

  Future<bool> delete(InboxUid uid) => _run(() {
    _remove(uid);
    return _repo.delete(uid);
  });

  void _remove(InboxUid uid) {
    _items = [
      for (final i in _items)
        if (i.uid != uid) i,
    ];
    _publish();
  }

  Future<bool> _run(Future<Object?> Function() action) async {
    try {
      await action();
      return true;
    } catch (e) {
      debugPrint('Inbox action failed: $e');
      return false;
    }
  }
}
