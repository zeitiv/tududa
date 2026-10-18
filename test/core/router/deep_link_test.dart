import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/router/deep_link.dart';

void main() {
  String? map(String u) => deepLinkLocation(Uri.parse(u));

  test('ignores non tududa links', () {
    expect(map('https://example.com/today'), isNull);
    expect(map('/today'), isNull);
  });

  test('widget open-app link', () {
    expect(map('tududa://today'), '/today');
  });

  test('entities', () {
    expect(map('tududa://task/abc'), '/tasks/abc');
    expect(map('tududa://project/p1'), '/projects/p1');
    expect(map('tududa://note/n1'), '/notes/n1');
    expect(map('tududa://inbox'), '/inbox');
  });

  test('quick add carries text', () {
    expect(
      map('tududa://quick-add?text=buy%20milk'),
      '/today?quickAdd=buy+milk',
    );
  });

  test('unknown host falls back to today', () {
    expect(map('tududa://nope'), '/today');
  });
}
