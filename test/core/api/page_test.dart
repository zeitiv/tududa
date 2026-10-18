import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/api/page.dart';

int _id(Map<String, dynamic> j) => j['id'] as int;

void main() {
  test('wrapped response with pagination', () {
    final page = Page.fromJson(
      {
        'tasks': [
          {'id': 1},
          {'id': 2},
        ],
        'pagination': {'total': 5, 'limit': 2, 'offset': 0, 'hasMore': true},
      },
      _id,
      itemsKey: 'tasks',
    );
    expect(page.items, [1, 2]);
    expect(page.total, 5);
    expect(page.limit, 2);
    expect(page.offset, 0);
    expect(page.hasMore, isTrue);
  });

  test('items key is auto-detected', () {
    final page = Page.fromJson({
      'projects': [
        {'id': 9},
      ],
    }, _id);
    expect(page.items, [9]);
    expect(page.hasMore, isFalse);
  });

  test('bare list becomes a single page', () {
    final page = Page.fromJson([
      {'id': 1},
      {'id': 2},
    ], _id);
    expect(page.items, [1, 2]);
    expect(page.total, 2);
    expect(page.hasMore, isFalse);
  });

  test('hasMore derived when missing', () {
    final page = Page.fromJson({
      'tasks': [
        {'id': 1},
      ],
      'pagination': {'total': 3, 'limit': 1, 'offset': 0},
    }, _id);
    expect(page.hasMore, isTrue);
  });

  test('bad shape throws FormatException', () {
    expect(() => Page.fromJson('nope', _id), throwsFormatException);
  });

  test('pageThrough walks all pages', () async {
    final all = List.generate(5, (i) => i);
    final offsets = <int>[];
    final pages = await pageThrough<int>((offset) async {
      offsets.add(offset);
      final items = all.skip(offset).take(2).toList();
      return Page(
        items: items,
        total: all.length,
        limit: 2,
        offset: offset,
        hasMore: offset + items.length < all.length,
      );
    }, pageSize: 2).toList();
    expect(offsets, [0, 2, 4]);
    expect([for (final p in pages) ...p.items], all);
  });

  test('pageThrough stops on an empty page even if hasMore lies', () async {
    final pages = await pageThrough<int>(
      (o) async =>
          const Page(items: [], total: 9, limit: 2, offset: 0, hasMore: true),
    ).toList();
    expect(pages, hasLength(1));
  });
}
