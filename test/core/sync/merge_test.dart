import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/sync/merge.dart';

void main() {
  final serverAt = DateTime.utc(2025, 1, 1, 12);
  int ms(DateTime d) => d.millisecondsSinceEpoch;
  final earlier = ms(serverAt.subtract(const Duration(minutes: 1)));
  final later = ms(serverAt.add(const Duration(minutes: 1)));

  MergeResult<Map<String, dynamic>> merge(
    Map<String, dynamic>? base,
    Map<String, dynamic> local,
    Map<String, dynamic> server,
    Map<String, int> dirty, {
    Duration skew = Duration.zero,
    Set<String> conflictCopyFields = const {},
  }) => mergeFields(
    base,
    local,
    server,
    dirty,
    entity: 'task',
    localId: 'L1',
    serverUpdatedAt: serverAt,
    skew: skew,
    conflictCopyFields: conflictCopyFields,
  );

  test('1 server-only change: not dirty takes the server value', () {
    final r = merge({'name': 'a', 'note': 'n'}, {'name': 'a', 'note': 'n'}, {
      'name': 'b',
      'note': 'n',
    }, {});
    expect(r.value, {'name': 'b', 'note': 'n'});
    expect(r.dirtyFields, isEmpty);
    expect(r.notices, isEmpty);
  });

  test('2 local-only change: kept and still dirty', () {
    final r = merge(
      {'name': 'a'},
      {'name': 'mine'},
      {'name': 'a'},
      {'name': later},
    );
    expect(r.value['name'], 'mine');
    expect(r.dirtyFields, {'name': later});
    expect(r.notices, isEmpty);
  });

  test('3 both changed, server newer: server wins, field cleaned, notice', () {
    final r = merge(
      {'name': 'a'},
      {'name': 'mine'},
      {'name': 'theirs'},
      {'name': earlier},
    );
    expect(r.value['name'], 'theirs');
    expect(r.dirtyFields, isEmpty);
    expect(r.notices, [
      const ConflictNotice(
        entity: 'task',
        localId: 'L1',
        field: 'name',
        localValue: 'mine',
        serverValue: 'theirs',
        winner: ConflictWinner.server,
      ),
    ]);
  });

  test('4 both changed, local newer: local wins and stays dirty', () {
    final r = merge(
      {'name': 'a'},
      {'name': 'mine'},
      {'name': 'theirs'},
      {'name': later},
    );
    expect(r.value['name'], 'mine');
    expect(r.dirtyFields, {'name': later});
    expect(r.notices.single.winner, ConflictWinner.local);
  });

  test('5 tags are merged as a set', () {
    final r = merge(
      {
        'tags': ['a', 'b'],
      },
      {
        'tags': ['a', 'c'],
      }, // removed b, added c
      {
        'tags': ['a', 'b', 'd'],
      }, // server added d
      {'tags': later},
    );
    expect(r.value['tags'], ['a', 'd', 'c']);
    expect(r.dirtyFields, {'tags': later});
    expect(r.notices, isEmpty);
  });

  test('5b tags: local change already on the server is no longer dirty', () {
    final r = merge(
      {
        'tags': ['a'],
      },
      {
        'tags': ['a', 'b'],
      },
      {
        'tags': ['b', 'a'],
      },
      {'tags': later},
    );
    expect(r.dirtyFields, isEmpty);
  });

  test('6 same value on both sides: clean', () {
    final r = merge(
      {'name': 'a'},
      {'name': 'x'},
      {'name': 'x'},
      {'name': later},
    );
    expect(r.value['name'], 'x');
    expect(r.dirtyFields, isEmpty);
    expect(r.notices, isEmpty);
  });

  test('7 null clears: a local null against an unchanged server', () {
    final r = merge(
      {'due_date': '2025-02-01'},
      {'due_date': null},
      {'due_date': '2025-02-01'},
      {'due_date': later},
    );
    expect(r.value['due_date'], isNull);
    expect(r.dirtyFields.keys, ['due_date']);
  });

  test('7b null clears: a server null beats an older local edit', () {
    final r = merge(
      {'due_date': '2025-02-01'},
      {'due_date': '2025-03-01'},
      {'due_date': null},
      {'due_date': earlier},
    );
    expect(r.value['due_date'], isNull);
    expect(r.dirtyFields, isEmpty);
  });

  test('8 local dirty but server deleted: keep for push, 404 rolls back', () {
    expect(
      resolveRow(
        pendingDelete: false,
        serverDeleted: true,
        hasDirtyFields: true,
      ),
      RowResolution.keepForPush,
    );
    expect(
      resolveRow(
        pendingDelete: false,
        serverDeleted: true,
        hasDirtyFields: false,
      ),
      RowResolution.removeLocal,
    );
    const notice = ConflictNotice.rolledBack(entity: 'task', localId: 'L1');
    expect((notice.field, notice.winner), ('*', ConflictWinner.server));
  });

  test('9 local delete vs server edit: delete wins', () {
    expect(
      resolveRow(
        pendingDelete: true,
        serverDeleted: false,
        hasDirtyFields: false,
      ),
      RowResolution.keepPendingDelete,
    );
    expect(
      resolveRow(
        pendingDelete: true,
        serverDeleted: true,
        hasDirtyFields: false,
      ),
      RowResolution.removeLocal,
    );
    expect(
      resolveRow(
        pendingDelete: false,
        serverDeleted: false,
        hasDirtyFields: true,
      ),
      RowResolution.applyServer,
    );
  });

  test(
    '10 note content: both changed -> server wins, local text kept as copy',
    () {
      final r = mergeNoteContent(
        base: 'one',
        local: 'one + mine',
        server: 'one + theirs',
        dirtyFields: {'content': later, 'title': later},
        localId: 'N1',
      );
      expect(r.value, 'one + theirs');
      expect(r.conflictCopy, 'one + mine');
      expect(r.dirtyFields, {'title': later});
      expect(r.notices.single.field, 'content');
    },
  );

  test('10b note content: only local changed keeps local', () {
    final r = mergeNoteContent(
      base: 'one',
      local: 'two',
      server: 'one',
      dirtyFields: {'content': later},
      localId: 'N1',
    );
    expect((r.value, r.conflictCopy), ('two', null));
    expect(r.dirtyFields, {'content': later});
  });

  test('11 skew correction decides close calls', () {
    // Device clock is 10 minutes behind the server (skew = +10 min). The
    // local edit at 11:58 device time is 12:08 server time: after the
    // server's 12:00 update, so local wins even though 11:58 < 12:00.
    final edit = ms(DateTime.utc(2025, 1, 1, 11, 58));
    final withSkew = merge(
      {'name': 'a'},
      {'name': 'mine'},
      {'name': 'theirs'},
      {'name': edit},
      skew: const Duration(minutes: 10),
    );
    expect(withSkew.value['name'], 'mine');
    final without = merge(
      {'name': 'a'},
      {'name': 'mine'},
      {'name': 'theirs'},
      {'name': edit},
    );
    expect(without.value['name'], 'theirs');
  });

  test('12 no base snapshot: differing values go to the newer edit', () {
    final r = merge(null, {'name': 'mine'}, {'name': 'theirs'}, {
      'name': earlier,
    });
    expect(r.value['name'], 'theirs');
    final l = merge(null, {'name': 'mine'}, {'name': 'theirs'}, {
      'name': later,
    });
    expect(l.value['name'], 'mine');
    expect(l.notices, hasLength(1));
  });

  test('13 a reverted local edit is not a conflict', () {
    final r = merge(
      {'name': 'a'},
      {'name': 'a'}, // edited and edited back
      {'name': 'theirs'},
      {'name': later},
    );
    expect(r.value['name'], 'theirs');
    expect(r.dirtyFields, isEmpty);
    expect(r.notices, isEmpty);
  });

  test('14 dirty fields neither side carries are preserved', () {
    final r = merge({}, {'a': 1}, {'a': 1}, {'ghost': 5});
    expect(r.dirtyFields, {'ghost': 5});
  });
}
