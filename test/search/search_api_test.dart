import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/api/api_error.dart';
import 'package:tududa/core/api/api_providers.dart';
import 'package:tududa/core/ids.dart';
import 'package:tududa/core/time/calendar_date.dart';
import 'package:tududa/search/data/search_api.dart';
import 'package:tududa/search/data/search_repository.dart';
import 'package:tududa/search/domain/search_query.dart';
import 'package:tududa/search/domain/search_result.dart';

import 'search_support.dart';

void main() {
  group('SearchResponse.fromJson', () {
    test('parses each type with the type discriminator', () {
      final r = SearchResponse.fromJson({
        'results': [
          {
            'type': 'Task',
            'uid': 't',
            'name': 'N',
            'status': 'in_progress',
            'due_date': '2025-03-14',
            'Project': {'name': 'Home'},
          },
          {'type': 'Task', 'uid': 't2', 'name': 'Int status', 'status': 2},
          {'type': 'Project', 'uid': 'p', 'name': 'P'},
          {'type': 'Area', 'uid': 'a', 'name': 'A'},
          {'type': 'Note', 'uid': 'n', 'name': 'Nt', 'title': 'Nt'},
          {'type': 'Tag', 'uid': 'g', 'name': 'G'},
        ],
      });
      expect(r.pagination, isNull);
      final task = r.results[0] as TaskHit;
      expect(task.uid, const TaskUid('t'));
      expect(task.status, 'in_progress');
      expect(task.dueDate, const CalendarDate(2025, 3, 14));
      expect(task.projectName, 'Home');
      expect((r.results[1] as TaskHit).status, 'done');
      expect(r.results[2], isA<ProjectHit>());
      expect(r.results[3], isA<AreaHit>());
      expect(r.results[4], isA<NoteHit>());
      expect(r.results[5], isA<TagHit>());
    });

    test('unknown types and malformed rows are skipped, not fatal', () {
      final r = SearchResponse.fromJson({
        'results': [
          {'type': 'Spaceship', 'uid': 'x', 'name': 'X'},
          {'type': 'Tag', 'name': 'no uid'},
          'junk',
          {'type': 'Tag', 'uid': 'ok', 'name': 'ok'},
        ],
        'pagination': {'total': 4, 'limit': 20, 'offset': 0, 'hasMore': false},
      });
      expect(r.results, hasLength(1));
      expect(r.skipped, 3);
      expect(r.pagination!.total, 4);
    });
  });

  group('SearchApi against the fake', () {
    test('substring match is case-insensitive across all types', () async {
      final stack = await searchStack();
      final r = await SearchApi(stack.dio)
          .search(const SearchQuery(text: 'MILK'));
      expect(r.results.map((e) => '${e.type.wire}:${e.name}'), [
        'Task:Buy Milk',
        'Task:Milk the cow',
        'Task:Other',
        'Project:Milk run',
        'Note:Groceries',
        'Tag:milky',
      ]);
      expect(stack.server.requests.last.query, {'q': 'MILK'});
    });

    test('filters, status, tags and pagination are honoured', () async {
      final stack = await searchStack();
      final api = SearchApi(stack.dio);
      var r = await api.search(
        const SearchQuery(text: 'milk', filters: {SearchType.task}),
      );
      expect(r.results, hasLength(3));

      r = await api.search(
        const SearchQuery(
          text: 'milk',
          filters: {SearchType.task},
          status: SearchStatus.completed,
        ),
      );
      expect(r.results.map((e) => e.name), ['Milk the cow']);

      r = await api.search(
        const SearchQuery(filters: {SearchType.task}, tags: ['home']),
      );
      expect(r.results.map((e) => e.name), ['Other']);

      final p1 = await api.search(
        const SearchQuery(text: 'milk', filters: {SearchType.task}, limit: 2),
      );
      expect(p1.results, hasLength(2));
      expect(p1.pagination!.total, 3);
      expect(p1.pagination!.hasMore, isTrue);
      final p2 = await api.search(
        const SearchQuery(
          text: 'milk',
          filters: {SearchType.task},
          limit: 2,
          offset: 2,
        ),
      );
      expect(p2.results.map((e) => e.name), ['Other']);
      expect(p2.pagination!.hasMore, isFalse);
    });

    test('reauthenticates after session expiry', () async {
      final stack = await searchStack();
      stack.server.expireAllSessions();
      final r = await SearchApi(stack.dio)
          .search(const SearchQuery(text: 'cow'));
      expect(r.results, hasLength(1));
      expect(stack.callbacks.calls, 1);
    });

    test(
      'a cancelled search throws CancelledError; the next call works',
      () async {
        final stack = await searchStack();
        stack.server.latency = const Duration(milliseconds: 30);
        final repo = RemoteSearchRepository(SearchApi(stack.dio));
        final token = CancelToken();
        final first = repo.search(
          const SearchQuery(text: 'milk'),
          cancelToken: token,
        );
        final expectation = expectLater(first, throwsA(isA<CancelledError>()));
        await Future<void>.delayed(const Duration(milliseconds: 5));
        token.cancel('superseded');
        await expectation;

        final second = await repo.search(
          const SearchQuery(text: 'cow'),
          cancelToken: CancelToken(),
        );
        expect(second.results.single.name, 'Milk the cow');
      },
    );
  });

  test('searchRepositoryProvider uses dioProvider', () async {
    final stack = await searchStack();
    final c = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(stack.dio)],
    );
    addTearDown(c.dispose);
    final r = await c
        .read(searchRepositoryProvider)
        .search(const SearchQuery(text: 'kitchen'));
    expect(r.results.single, isA<AreaHit>());
  });
}
