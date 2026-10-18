/// One page of a paginated Tududi list (`pagination{total,limit,offset,hasMore}`).
///
/// NOTE: clashes with Flutter's navigator `Page`; import with a prefix or
/// `hide Page` in widget files.
class Page<T> {
  const Page({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
    required this.hasMore,
  });

  final List<T> items;
  final int total;
  final int limit;
  final int offset;
  final bool hasMore;

  /// A list that has no pagination info: one complete page.
  factory Page.single(List<T> items) => Page(
    items: items,
    total: items.length,
    limit: items.length,
    offset: 0,
    hasMore: false,
  );

  /// Reads a response that is either a bare list or an object holding the
  /// list under [itemsKey] (e.g. `tasks`; when null or missing, the first
  /// list-valued entry is used) next to a `pagination` object.
  factory Page.fromJson(
    Object? json,
    T Function(Map<String, dynamic> json) itemFromJson, {
    String? itemsKey,
  }) {
    List<dynamic> raw;
    Map<dynamic, dynamic>? pagination;
    if (json is List) {
      raw = json;
    } else if (json is Map) {
      final byKey = itemsKey == null ? null : json[itemsKey];
      if (byKey is List) {
        raw = byKey;
      } else {
        raw = [
          for (final v in json.values)
            if (v is List) ...v,
        ];
      }
      final p = json['pagination'];
      if (p is Map) pagination = p;
    } else {
      throw FormatException('Expected a list or an object', json);
    }
    final items = [
      for (final e in raw) itemFromJson(Map<String, dynamic>.from(e as Map)),
    ];
    if (pagination == null) return Page.single(items);

    int intOf(String k, int fallback) {
      final v = pagination![k];
      return v is num ? v.toInt() : fallback;
    }

    final total = intOf('total', items.length);
    final offset = intOf('offset', 0);
    final hasMore = pagination['hasMore'];
    return Page(
      items: items,
      total: total,
      limit: intOf('limit', items.length),
      offset: offset,
      hasMore: hasMore is bool ? hasMore : offset + items.length < total,
    );
  }
}

/// Fetches pages until `hasMore` is false, emitting each page. [fetch]
/// receives the offset to request. [pageSize] is advisory: pass the same value
/// as `limit` in [fetch]. Stops on an empty page.
Stream<Page<T>> pageThrough<T>(
  Future<Page<T>> Function(int offset) fetch, {
  int pageSize = 50,
}) async* {
  var offset = 0;
  while (true) {
    final page = await fetch(offset);
    yield page;
    if (!page.hasMore || page.items.isEmpty) return;
    offset += page.items.length;
  }
}
