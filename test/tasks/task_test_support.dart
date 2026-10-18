import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' show addTearDown;
import 'package:tududa/core/api/api_providers.dart';

import '../support/api_stack.dart';
import '../support/fake_tududi/fake_tududi.dart';

/// A fake Tududi with one user, the production Dio stack against it, and
/// silent re-login wired like the session layer will do it.
class TaskTestRig {
  TaskTestRig() {
    server = FakeTududi()..addUser('a@b.c', 'pw');
    stack = TestStack(server);
    stack.callbacks.onReauth = () async {
      await stack.dio.post('/login', data: _creds);
      return true;
    };
  }

  static const _creds = {'email': 'a@b.c', 'password': 'pw'};

  late final FakeTududi server;
  late final TestStack stack;

  Future<void> login() async {
    await stack.dio.post('/login', data: _creds);
  }

  ProviderContainer container() {
    final c = ProviderContainer(
      // Failed providers must not retry on their own in tests.
      retry: (_, _) => null,
      overrides: [dioProvider.overrideWithValue(stack.dio)],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Requests of [method] to [path] seen by the server.
  Iterable<RecordedRequest> sent(String method, String path) =>
      server.requests.where((r) => r.method == method && r.path == path);
}
