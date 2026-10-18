import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/ids.dart';

void main() {
  test('uid extension types wrap strings', () {
    const t = TaskUid('abc');
    expect(t.value, 'abc');
    expect('$t', 'abc');
    expect(t, const TaskUid('abc'));
    expect(ProjectUid('p').value, 'p');
    expect(AreaUid('a').value, 'a');
    expect(NoteUid('n').value, 'n');
    expect(TagUid('t').value, 't');
    expect(InboxUid('i').value, 'i');
  });

  test('converters round trip', () {
    expect(const TaskUidConverter().fromJson('x'), const TaskUid('x'));
    expect(const TaskUidConverter().toJson(const TaskUid('x')), 'x');
    expect(const ProjectUidConverter().toJson(const ProjectUid('p')), 'p');
    expect(const AreaUidConverter().fromJson('a').value, 'a');
    expect(const NoteUidConverter().fromJson('n').value, 'n');
    expect(const TagUidConverter().fromJson('t').value, 't');
    expect(const InboxUidConverter().fromJson('i').value, 'i');
  });

  test('nullable converters', () {
    expect(const NullableProjectUidConverter().fromJson(null), isNull);
    expect(const NullableProjectUidConverter().toJson(null), isNull);
    expect(
      const NullableProjectUidConverter().fromJson('p'),
      const ProjectUid('p'),
    );
    expect(
      const NullableProjectUidConverter().toJson(const ProjectUid('p')),
      'p',
    );
  });

  test('LocalId.generate yields distinct uuid v4 values', () {
    final a = LocalId.generate(), b = LocalId.generate();
    expect(a, isNot(b));
    expect(
      a.value,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(const LocalIdConverter().fromJson(a.value), a);
    expect(const LocalIdConverter().toJson(a), a.value);
  });

  test('ServerId', () {
    const id = ServerId(42);
    expect(id.value, 42);
    expect('$id', '42');
    expect(const ServerIdConverter().fromJson(42), id);
    expect(const ServerIdConverter().toJson(id), 42);
    expect(const NullableServerIdConverter().fromJson(null), isNull);
    expect(const NullableServerIdConverter().toJson(id), 42);
  });
}
