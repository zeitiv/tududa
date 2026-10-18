import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/ids.dart';
import 'package:tududa/search/domain/search_query.dart';

void main() {
  test('empty query encodes to nothing and isEmpty', () {
    const q = SearchQuery();
    expect(q.toQueryParameters(), isEmpty);
    expect(q.isEmpty, isTrue);
  });

  test('every field is encoded, filters in canonical order', () {
    final q = SearchQuery(
      text: '  milk ',
      filters: {SearchType.tag, SearchType.task},
      tags: ['a', ' b ', ''],
      status: SearchStatus.active,
      taskStatus: 'in_progress',
      priority: 'high',
      due: 'today',
      defer: 'next_week',
      projectUid: const ProjectUid('p1'),
      areaUid: const AreaUid('a1'),
      limit: 20,
      offset: 40,
    );
    expect(q.toQueryParameters(), {
      'q': 'milk',
      'filters': 'Task,Tag',
      'priority': 'high',
      'due': 'today',
      'defer': 'next_week',
      'tags': 'a,b',
      'status': 'active',
      'task_status': 'in_progress',
      'project_uid': 'p1',
      'area_uid': 'a1',
      'limit': '20',
      'offset': '40',
    });
    expect(q.isEmpty, isFalse);
  });

  test('equality ignores filter insertion order', () {
    expect(
      SearchQuery(text: 'x', filters: {SearchType.note, SearchType.task}),
      SearchQuery(text: 'x', filters: {SearchType.task, SearchType.note}),
    );
    expect(
      const SearchQuery(text: 'x').copyWith(offset: 5).toQueryParameters(),
      {'q': 'x', 'offset': '5'},
    );
  });
}
