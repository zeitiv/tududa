import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/api/patch.dart' as p;
import 'package:tududa/core/api/patch.dart' show Patch, putPatch;

void main() {
  test('unset is omitted', () {
    final json = <String, Object?>{};
    putPatch(json, 'due_date', const Patch<String>.unset());
    expect(json, isEmpty);
    expect(const Patch<String>.unset().isSet, isFalse);
  });

  test('clear writes null', () {
    final json = <String, Object?>{};
    putPatch(json, 'due_date', const Patch<String>.clear());
    expect(json.containsKey('due_date'), isTrue);
    expect(json['due_date'], isNull);
    expect(const Patch<String>.clear().isSet, isTrue);
    expect(const Patch<String>.clear().isClear, isTrue);
  });

  test('set writes the value, through encode when given', () {
    final json = <String, Object?>{};
    putPatch(json, 'name', const Patch.set('x'));
    putPatch<int>(json, 'n', const Patch.set(3), (v) => v * 2);
    expect(json, {'name': 'x', 'n': 6});
    expect(const Patch.set('x').isClear, isFalse);
  });

  test('encode is not applied to clears', () {
    final json = <String, Object?>{};
    putPatch<int>(json, 'n', const Patch.clear(), (v) => fail('no'));
    expect(json, {'n': null});
  });

  test('equality and pattern matching', () {
    expect(const Patch.set(1), const Patch.set(1));
    expect(const Patch<int>.unset(), const Patch<int>.unset());
    final Patch<int> v = const Patch.set(2);
    final out = switch (v) {
      p.Unset<int>() => 'unset',
      p.Set<int>(:final value) => 'set $value',
    };
    expect(out, 'set 2');
  });
}
