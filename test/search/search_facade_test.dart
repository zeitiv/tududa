import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/api/api_error.dart';
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/ids.dart';
import 'package:tududa/core/time/calendar_date.dart';
import 'package:tududa/search/data/local_search.dart';
import 'package:tududa/search/data/search_repository.dart';
import 'package:tududa/search/domain/search_query.dart';
import 'package:tududa/search/domain/search_result.dart';
import 'package:tududa/search/providers/search_provider.dart';

const today = CalendarDate(2026, 10, 18);

class FakeRemote implements SearchRepository {
  final calls =
      <
        ({
          SearchQuery query,
          Completer<SearchResponse> done,
          CancelToken? token,
        })
      >[];
  Object? failWith;

  @override
  Future<SearchResponse> search(SearchQuery query, {CancelToken? cancelToken}) {
    if (failWith != null) return Future.error(failWith!);
    final c = Completer<SearchResponse>();
    calls.add((query: query, done: c, token: cancelToken));
    return c.future;
  }
}

SearchResponse resp(List<String> names) => SearchResponse(
  results: [for (final n in names) TaskHit(uid: TaskUid(n), name: n)],
);

Future<AppDatabase> seededDb() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  Future<void> task(
    String id,
    String name, {
    String? note,
    int status = 0,
    int priority = 0,
    String? due,
    String? project,
    String? area,
  }) => db
      .into(db.tasks)
      .insert(
        TasksCompanion.insert(
          localId: id,
          name: Value(name),
          note: Value(note),
          status: Value(status),
          priority: Value(priority),
          dueDate: Value(due),
          projectLocalId: Value(project),
          areaLocalId: Value(area),
        ),
      );
  await db
      .into(db.areas)
      .insert(
        AreasCompanion.insert(localId: 'a1', name: const Value('Kitchen')),
      );
  await db
      .into(db.projects)
      .insert(
        ProjectsCompanion.insert(
          localId: 'p1',
          uid: const Value('pu1'),
          name: const Value('Milk run'),
          areaLocalId: const Value('a1'),
        ),
      );
  await task('t1', 'Buy Milk', priority: 2, due: '2026-10-10', project: 'p1');
  await task('t2', 'Fresh MILK', status: 2, due: '2026-10-18');
  await task('t3', 'Other', note: 'with milk inside', due: '2026-10-19');
  await task('t4', 'Bread');
  await db
      .into(db.notes)
      .insert(
        NotesCompanion.insert(
          localId: 'n1',
          title: const Value('Groceries'),
          content: const Value('milk, eggs'),
        ),
      );
  await db
      .into(db.tags)
      .insert(TagsCompanion.insert(localId: 'g1', name: const Value('milky')));
  await db
      .into(db.tags)
      .insert(TagsCompanion.insert(localId: 'g2', name: const Value('home')));
  await db
      .into(db.taskTags)
      .insert(TaskTagsCompanion.insert(taskLocalId: 't3', tagLocalId: 'g2'));
  return db;
}

void main() {
  group('local fallback (in-memory Drift)', () {
    late AppDatabase db;
    late LocalSearch local;
    setUp(() async {
      db = await seededDb();
      local = LocalSearch(db);
    });

    Future<List<String>> run(
      String q, {
      Set<SearchType> types = const {},
    }) async => [
      for (final h in await local.search(
        ParsedSearch.parse(q),
        types: types,
        today: today,
      ))
        '${h.type.name}:${h.name}',
    ];

    test('groups by type, ranks prefix > contains > description', () async {
      expect(await run('milk'), [
        'task:Buy Milk', // contains
        'task:Fresh MILK',
        'task:Other', // description only
        'project:Milk run',
        'note:Groceries',
        'tag:milky',
      ]);
      expect(await run('mil'), contains('project:Milk run'));
      final ranked = await run('milk');
      // 'Buy Milk' and 'Fresh MILK' both only contain; prefix wins in:
      expect(await run('buy'), ['task:Buy Milk']);
      expect(ranked.first.startsWith('task:'), isTrue);
    });

    test('type filter', () async {
      expect(await run('milk', types: {SearchType.tag}), ['tag:milky']);
    });

    test('syntax filters', () async {
      expect(await run('is:overdue'), ['task:Buy Milk']);
      expect(await run('is:today'), ['task:Fresh MILK']);
      expect(await run('is:done'), ['task:Fresh MILK']);
      expect(await run('priority:high'), ['task:Buy Milk']);
      expect(await run('due:tomorrow'), ['task:Other']);
      expect(await run('due:2026-10-18 milk'), ['task:Fresh MILK']);
      expect(await run('#home'), ['task:Other']);
      expect(await run('+"milk run"'), ['task:Buy Milk']);
      expect(await run('~kitchen'), ['task:Buy Milk', 'project:Milk run']);
      expect(await run('+unknown'), isEmpty);
      expect(await run('is:overdue priority:low'), isEmpty);
    });

    test('pending-delete rows are hidden', () async {
      await (db.update(db.tasks)..where((t) => t.localId.equals('t4'))).write(
        const TasksCompanion(pendingDelete: Value(true)),
      );
      expect(await run('bread'), isEmpty);
    });

    test('facade falls back offline and on transient errors', () async {
      final remote = FakeRemote();
      var online = false;
      final facade = SearchRepositoryFacade(
        remote: remote,
        local: local,
        isOnline: () => online,
        today: () => today,
      );
      var out = await facade.search('bread');
      expect(out.offline, isTrue);
      expect(out.results.single.name, 'Bread');
      expect(remote.calls, isEmpty);

      online = true;
      remote.failWith = const NetworkError('down');
      out = await facade.search('bread');
      expect(out.offline, isTrue);

      remote.failWith = const ForbiddenError('no');
      await expectLater(facade.search('bread'), throwsA(isA<ForbiddenError>()));
    });
  });

  group('online path', () {
    test('maps syntax to the request and post-filters', () async {
      final db = await seededDb();
      final remote = FakeRemote();
      final facade = SearchRepositoryFacade(
        remote: remote,
        local: LocalSearch(db),
        isOnline: () => true,
        today: () => today,
      );
      final f = facade.search('milk #home priority:high is:overdue');
      await Future<void>.delayed(Duration.zero);
      final q = remote.calls.single.query;
      expect(q.toQueryParameters(), {
        'q': 'milk',
        'filters': 'Task',
        'priority': 'high',
        'tags': 'home',
      });
      remote.calls.single.done.complete(
        SearchResponse(
          results: [
            TaskHit(
              uid: const TaskUid('x'),
              name: 'late',
              dueDate: today.addDays(-1),
              priority: 'high',
            ),
            const TaskHit(uid: TaskUid('y'), name: 'nodue'),
          ],
        ),
      );
      final out = await f;
      expect(out.offline, isFalse);
      expect(out.results.map((r) => r.name), ['late']);
    });
  });

  group('SearchController debounce and cancel', () {
    late FakeRemote remote;
    late ProviderContainer c;

    setUp(() async {
      final db = await seededDb();
      remote = FakeRemote();
      c = ProviderContainer(
        overrides: [
          searchDebounceProvider.overrideWithValue(
            const Duration(milliseconds: 20),
          ),
          searchFacadeProvider.overrideWithValue(
            SearchRepositoryFacade(
              remote: remote,
              local: LocalSearch(db),
              isOnline: () => true,
              today: () => today,
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      c.listen(searchControllerProvider, (_, _) {});
    });

    Future<void> wait([int ms = 60]) =>
        Future<void>.delayed(Duration(milliseconds: ms));

    test('default debounce is 250 ms', () {
      expect(
        ProviderContainer().read(searchDebounceProvider),
        const Duration(milliseconds: 250),
      );
    });

    test('rapid typing sends only the last query', () async {
      final ctl = c.read(searchControllerProvider.notifier);
      ctl.setText('m');
      ctl.setText('mi');
      ctl.setText('milk');
      expect(c.read(searchControllerProvider).phase, SearchPhase.loading);
      await wait();
      expect(remote.calls.length, 1);
      expect(remote.calls.single.query.text, 'milk');
      remote.calls.single.done.complete(resp(['Milk']));
      await wait(5);
      final s = c.read(searchControllerProvider);
      expect(s.phase, SearchPhase.data);
      expect(s.results.single.name, 'Milk');
    });

    test('older response never overwrites the newest query', () async {
      final ctl = c.read(searchControllerProvider.notifier);
      ctl.setText('one');
      await wait();
      ctl.setText('two');
      await wait();
      expect(remote.calls.length, 2);
      expect(remote.calls[0].token!.isCancelled, isTrue);
      expect(remote.calls[1].token!.isCancelled, isFalse);
      remote.calls[1].done.complete(resp(['two-hit']));
      await wait(5);
      remote.calls[0].done.complete(resp(['one-hit']));
      await wait(5);
      expect(c.read(searchControllerProvider).results.map((r) => r.name), [
        'two-hit',
      ]);
    });

    test('clearing the query cancels and resets', () async {
      final ctl = c.read(searchControllerProvider.notifier);
      ctl.setText('one');
      await wait();
      ctl.setText('');
      expect(remote.calls.single.token!.isCancelled, isTrue);
      remote.calls.single.done.complete(resp(['late']));
      await wait(5);
      final s = c.read(searchControllerProvider);
      expect(s.phase, SearchPhase.idle);
      expect(s.results, isEmpty);
    });

    test('offline outcome is flagged; permanent errors surface', () async {
      final ctl = c.read(searchControllerProvider.notifier);
      remote.failWith = const NetworkError('down');
      ctl.setText('bread', immediate: true);
      await wait(30);
      var s = c.read(searchControllerProvider);
      expect(s.offline, isTrue);
      expect(s.results.single.name, 'Bread');

      remote.failWith = const ForbiddenError('no');
      ctl.setText('bread2', immediate: true);
      await wait(30);
      s = c.read(searchControllerProvider);
      expect(s.phase, SearchPhase.error);
    });
  });
}
