import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/ids.dart';
import '../data/inbox_repository.dart';
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

/// Action methods return whether the server accepted the change; on failure
/// the list is reloaded so the UI never shows a stale optimistic state.
class InboxNotifier extends AsyncNotifier<InboxList> {
  InboxRepository get _repo => ref.read(inboxRepositoryProvider);

  @override
  Future<InboxList> build() => _fetchFirst();

  Future<InboxList> _fetchFirst() async {
    final page = await _repo.list(limit: inboxPageSize, offset: 0);
    return InboxList(
      items: page.items,
      total: page.total,
      hasMore: page.hasMore,
    );
  }

  /// Reloads from the first page. Keeps the old list visible meanwhile.
  Future<void> refresh() async {
    state = await AsyncValue.guard(_fetchFirst);
  }

  Future<void> loadMore() async {
    final cur = state.value;
    if (cur == null || !cur.hasMore || cur.loadingMore) return;
    state = AsyncData(cur.copyWith(loadingMore: true));
    try {
      final page = await _repo.list(
        limit: inboxPageSize,
        offset: cur.items.length,
      );
      final known = {for (final i in cur.items) i.uid};
      state = AsyncData(
        InboxList(
          items: [
            ...cur.items,
            for (final i in page.items)
              if (!known.contains(i.uid)) i,
          ],
          total: page.total,
          hasMore: page.hasMore && page.items.isNotEmpty,
        ),
      );
    } on ApiError catch (e) {
      debugPrint('Inbox loadMore failed: $e');
      state = AsyncData(cur.copyWith(loadingMore: false));
    }
  }

  Future<bool> capture(String text, {String source = 'mobile'}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    return _run(() async {
      final item = await _repo.capture(trimmed, source: source);
      final cur = state.value ?? const InboxList();
      state = AsyncData(
        cur.copyWith(items: [item, ...cur.items], total: cur.total + 1),
      );
    });
  }

  /// Marks the item processed; the server then hides it from the list.
  /// Optimistic: the item leaves the list before the request returns (a
  /// swiped-away `Dismissible` must be gone from the tree at once).
  Future<bool> process(InboxUid uid, {InboxProcessTarget? target}) =>
      _run(() async {
        _remove(uid);
        await _repo.process(uid, target: target);
      });

  Future<bool> ignore(InboxUid uid) => _run(() async {
    _replace(uid, (i) => i.copyWith(status: InboxStatus.ignored));
    final updated = await _repo.setStatus(uid, InboxStatus.ignored);
    _replace(uid, (_) => updated);
  });

  Future<bool> delete(InboxUid uid) => _run(() async {
    _remove(uid);
    await _repo.delete(uid);
  });

  void _replace(InboxUid uid, InboxItem Function(InboxItem) f) {
    final cur = state.value;
    if (cur == null) return;
    state = AsyncData(
      cur.copyWith(items: [for (final i in cur.items) i.uid == uid ? f(i) : i]),
    );
  }

  void _remove(InboxUid uid) {
    final cur = state.value;
    if (cur == null) return;
    state = AsyncData(
      cur.copyWith(
        items: [
          for (final i in cur.items)
            if (i.uid != uid) i,
        ],
        total: cur.total > 0 ? cur.total - 1 : 0,
      ),
    );
  }

  Future<bool> _run(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } on ApiError catch (e) {
      debugPrint('Inbox action failed: $e');
      await refresh();
      return false;
    }
  }
}
