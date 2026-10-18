import '../support/api_stack.dart';
import '../support/fake_tududi/fake_tududi.dart';
import '../support/fake_tududi/routes/inbox_routes.dart';

/// A signed-in stack against a fake server with the inbox routes.
Future<TestStack> inboxStack({int seed = 0}) async {
  final server = FakeTududi()..addUser('a@b.c', 'pw');
  registerInboxRoutes(server);
  for (var i = 1; i <= seed; i++) {
    inboxStoreOf(server).add('Item $i');
  }
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
