import 'package:tududa/core/api/api_error.dart';

import '../support/api_stack.dart';
import '../support/fake_tududi/fake_tududi.dart';
import '../support/fake_tududi/routes/notes_routes.dart';

/// A signed-in stack against a fake server that serves notes and tags.
Future<TestStack> signedInStack() async {
  final server = FakeTududi()..addUser('a@b.c', 'pw');
  registerNoteRoutes(server);
  final stack = TestStack(server);
  Future<bool> login() async {
    await stack.dio.post('/login', data: {'email': 'a@b.c', 'password': 'pw'});
    return true;
  }

  stack.callbacks.onReauth = login;
  await login();
  return stack;
}

Future<ApiError> errorOf(Future<Object?> f) async {
  try {
    await f;
  } on ApiError catch (e) {
    return e;
  }
  throw StateError('expected ApiError');
}
