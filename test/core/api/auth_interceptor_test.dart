import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/api_stack.dart';
import '../../support/fake_tududi/fake_tududi.dart';

void main() {
  late FakeTududi server;
  late FakeAuthCallbacks callbacks;
  late TestStack stack;

  Future<Response<dynamic>> login() =>
      stack.dio.post('/login', data: {'email': 'a@b.c', 'password': 'pw'});

  setUp(() {
    server = FakeTududi()..addUser('a@b.c', 'pw');
    callbacks = FakeAuthCallbacks();
    stack = TestStack(server, callbacks: callbacks);
    callbacks.onReauth = () async {
      await login();
      return true;
    };
  });

  test(
    'three parallel 401s trigger exactly one re-login and all succeed',
    () async {
      await login();
      server.seedTask(name: 'x');
      server.latency = const Duration(milliseconds: 5);
      server.expireAllSessions();

      final results = await Future.wait([
        stack.dio.get('/tasks'),
        stack.dio.get('/tasks'),
        stack.dio.get('/tasks'),
      ]);
      expect(results.map((r) => r.statusCode), [200, 200, 200]);
      expect(callbacks.calls, 1);
      expect(stack.count('POST', '/login'), 2);
    },
  );

  test('request is retried exactly once', () async {
    await login();
    server.expireAllSessions();
    callbacks.onReauth = () async => true; // claims success, but no session
    await expectLater(stack.dio.get('/tasks'), throwsA(isA<DioException>()));
    expect(callbacks.calls, 1);
    expect(stack.count('GET', '/tasks'), 2); // original + one retry, no loop
  });

  test('failed reauth passes the 401 through', () async {
    await login();
    server.expireAllSessions();
    callbacks.onReauth = () async => false;
    await expectLater(
      stack.dio.get('/tasks'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          401,
        ),
      ),
    );
    expect(stack.count('GET', '/tasks'), 1);
  });

  test('throwing reauth passes the 401 through', () async {
    await login();
    server.expireAllSessions();
    callbacks.onReauth = () async => throw StateError('boom');
    await expectLater(stack.dio.get('/tasks'), throwsA(isA<DioException>()));
    expect(callbacks.calls, 1);
  });

  test(
    '401 on /login, /current_user, /logout does not reauthenticate',
    () async {
      await expectLater(
        stack.dio.post('/login', data: {'email': 'a@b.c', 'password': 'bad'}),
        throwsA(isA<DioException>()),
      );
      server.failNext('/current_user', 401);
      await expectLater(
        stack.dio.get('/current_user'),
        throwsA(isA<DioException>()),
      );
      server.failNext('/logout', 401);
      await expectLater(stack.dio.get('/logout'), throwsA(isA<DioException>()));
      expect(callbacks.calls, 0);
    },
  );

  test(
    'a late 401 from before the re-login is replayed without a second one',
    () async {
      await login();
      server.expireAllSessions();
      // Fire a request, let reauth complete, then fail a request that was sent earlier.
      final first = stack.dio.get('/tasks');
      final second = stack.dio.get('/tasks');
      await Future.wait([first, second]);
      expect(callbacks.calls, 1);
    },
  );

  test('a new expiry later triggers a new re-login', () async {
    await login();
    server.expireAllSessions();
    await stack.dio.get('/tasks');
    server.expireAllSessions();
    await stack.dio.get('/tasks');
    expect(callbacks.calls, 2);
  });
}
