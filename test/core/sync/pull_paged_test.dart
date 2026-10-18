import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/api/page.dart';
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/sync/id_resolver.dart';
import 'package:tududa/core/sync/pull_paged.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';

void main() {
  final cursor = DateTime.utc(2025, 1, 1, 12);
  // Newest first, one item per minute going back from 12:10.
  final items = [
    for (var i = 0; i < 30; i++)
      (
        id: i,
        at: DateTime.utc(2025, 1, 1, 12, 10).subtract(Duration(minutes: i)),
      ),
  ];

  Future<Page<({int id, DateTime at})>> fetch(
    int offset, {
    int limit = 10,
  }) async {
    final slice = items.skip(offset).take(limit).toList();
    return Page(
      items: slice,
      total: items.length,
      limit: limit,
      offset: offset,
      hasMore: offset + slice.length < items.length,
    );
  }

  test('without a cursor everything is fetched', () async {
    final got = <int>[];
    final n = await pullPaged(
      fetch: fetch,
      updatedAt: (i) => i.at,
      onPage: (p) async => got.addAll(p.map((i) => i.id)),
    );
    expect((n, got.length), (30, 30));
  });

  test(
    'stops once a page reaches items older than cursor - 5 minutes',
    () async {
      final pages = <int>[];
      final got = <int>[];
      final fetched = <int>[];
      await pullPaged(
        fetch: (o) {
          fetched.add(o);
          return fetch(o);
        },
        updatedAt: (i) => i.at,
        cursor: cursor,
        onPage: (p) async {
          pages.add(p.length);
          got.addAll(p.map((i) => i.id));
        },
      );
      // Items are >= 11:55 up to index 15; the page at offset 10 holds 10..19.
      expect(got, [for (var i = 0; i <= 15; i++) i]);
      expect(pages, [10, 6]);
      expect(fetched, [0, 10]);
    },
  );

  test(
    'items without updated_at are delivered and do not stop the walk',
    () async {
      final got = <int>[];
      await pullPaged<int?>(
        fetch: (o) async => Page(
          items: o == 0 ? [null, null] : [null],
          total: 3,
          limit: 2,
          offset: o,
          hasMore: o == 0,
        ),
        updatedAt: (_) => null,
        cursor: cursor,
        onPage: (p) async => got.addAll(p.map((e) => 0)),
      );
      expect(got, hasLength(3));
    },
  );

  test('IdResolver maps local ids and waits for missing uids', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.projects)
        .insert(
          ProjectsCompanion.insert(
            localId: 'p1',
            uid: const Value('uid-1'),
            serverId: const Value(7),
          ),
        );
    await db.into(db.projects).insert(ProjectsCompanion.insert(localId: 'p2'));
    final ids = IdResolver(db);
    expect(await ids.uidOf(SyncEntity.project, 'p1'), 'uid-1');
    expect(await ids.serverIdOf(SyncEntity.project, 'p1'), 7);
    expect(await ids.localIdOfUid(SyncEntity.project, 'uid-1'), 'p1');
    expect(await ids.localIdOfServerId(SyncEntity.project, 7), 'p1');
    expect(await ids.uidOf(SyncEntity.project, 'p2'), isNull);
    expect(
      () => ids.requireUid(SyncEntity.project, 'p2'),
      throwsA(isA<DependencyPendingException>()),
    );
    expect(
      () => ids.requireServerId(SyncEntity.project, 'nope'),
      throwsA(isA<DependencyPendingException>()),
    );
    expect(await ids.localIdsByUid(SyncEntity.project), {'uid-1': 'p1'});
  });
}
