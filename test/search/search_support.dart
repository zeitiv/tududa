import '../support/api_stack.dart';
import '../support/fake_tududi/fake_tududi.dart';
import '../support/fake_tududi/routes/search_routes.dart';

Future<TestStack> searchStack({void Function(FakeTududi s)? seed}) async {
  final server = FakeTududi()..addUser('a@b.c', 'pw');
  registerSearchRoutes(server);
  final corpus = searchCorpusOf(server);
  server.seedTask(uid: 't1', name: 'Buy Milk', status: 0);
  server.seedTask(
    uid: 't2',
    name: 'Milk the cow',
    status: 2,
    dueDate: '2025-03-14',
  );
  server.seedTask(
    uid: 't3',
    name: 'Other',
    note: 'with milk inside',
    tags: ['home'],
  );
  corpus
    ..add('Project', 'Milk run', uid: 'p1')
    ..add('Area', 'Kitchen', uid: 'a1')
    ..add('Note', 'Groceries', uid: 'n1', description: 'milk, eggs')
    ..add('Tag', 'milky', uid: 'g1');
  seed?.call(server);
  late final TestStack stack;
  stack = TestStack(
    server,
    callbacks: FakeAuthCallbacks(() async {
      await stack.dio.post(
        '/login',
        data: {'email': 'a@b.c', 'password': 'pw'},
      );
      return true;
    }),
  );
  await stack.dio.post('/login', data: {'email': 'a@b.c', 'password': 'pw'});
  return stack;
}
