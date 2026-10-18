import '../api/page.dart';

/// Pages through a list sorted by `updated_at` descending and hands every
/// item that may have changed since [cursor] to [onPage].
///
/// Stop rule: the server has no `updated_since`, so the walk continues until a
/// page contains an item older than `cursor - overlap` (default 5 minutes, to
/// absorb clock skew and in-flight writes); that page is still delivered
/// (without its older items) and the walk ends. Without a [cursor] (first
/// pull) everything is fetched.
///
/// [fetch] receives the offset of the page to request (use the same limit,
/// e.g. 100, on every call). [updatedAt] reads an item's server `updated_at`;
/// items without one are always delivered and never stop the walk. Returns
/// how many items were delivered.
Future<int> pullPaged<T>({
  required Future<Page<T>> Function(int offset) fetch,
  required DateTime? Function(T item) updatedAt,
  required Future<void> Function(List<T> items) onPage,
  DateTime? cursor,
  Duration overlap = const Duration(minutes: 5),
}) async {
  final stopAt = cursor?.subtract(overlap);
  var delivered = 0;
  await for (final page in pageThrough(fetch)) {
    var reachedOld = false;
    final fresh = <T>[];
    for (final item in page.items) {
      final at = updatedAt(item);
      if (stopAt != null && at != null && at.isBefore(stopAt)) {
        reachedOld = true;
      } else {
        fresh.add(item);
      }
    }
    if (fresh.isNotEmpty) {
      await onPage(fresh);
      delivered += fresh.length;
    }
    if (reachedOld) break;
  }
  return delivered;
}
