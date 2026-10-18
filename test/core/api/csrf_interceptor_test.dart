import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/api/api_error.dart';

import '../../support/api_stack.dart';
import '../../support/fake_tududi/fake_tududi.dart';

void main() {
  late FakeTududi server;
  late TestStack stack;

  Future<void> login() =>
      stack.dio.post('/login', data: {'email': 'a@b.c', 'password': 'pw'});

  Future<Response<dynamic>> createTask([String name = 'T']) =>
      stack.dio.post('/task', data: {'name': name});

  setUp(() {
    server = FakeTududi()..addUser('a@b.c', 'pw');
    stack = TestStack(server);
  });

  test('token is fetched lazily and only for mutations', () async {
    await login();
    await stack.dio.get('/tasks');
    expect(stack.count('GET', '/csrf-token'), 0);

    await createTask();
    expect(stack.count('GET', '/csrf-token'), 1);
    final post = server.requests.lastWhere((r) => r.path == '/task');
    expect(post.headers['x-csrf-token'], isNotNull);
    expect(post.status, 201);

    final get = server.requests.lastWhere((r) => r.path == '/tasks');
    expect(get.headers.containsKey('x-csrf-token'), isFalse);
  });

  test('token is cached across mutations', () async {
    await login();
    await createTask('a');
    await createTask('b');
    expect(stack.count('GET', '/csrf-token'), 1);
  });

  test('no token on login', () async {
    await login();
    final req = server.requests.firstWhere((r) => r.path == '/login');
    expect(req.headers.containsKey('x-csrf-token'), isFalse);
    expect(stack.count('GET', '/csrf-token'), 0);
  });

  test('concurrent mutations share one in-flight fetch', () async {
    await login();
    server.latency = const Duration(milliseconds: 5);
    await Future.wait([createTask('a'), createTask('b'), createTask('c')]);
    expect(stack.count('GET', '/csrf-token'), 1);
    expect(server.tasks, hasLength(3));
  });

  test('403 csrf: refetch and retry once', () async {
    await login();
    await createTask('a');
    expect(stack.count('GET', '/csrf-token'), 1);

    server.failNext('/task', 403, body: {'error': 'Invalid CSRF token'});
    final res = await createTask('b');
    expect(res.statusCode, 201);
    expect(stack.count('GET', '/csrf-token'), 2);
    expect(stack.count('POST', '/task'), 3); // ok, 403, retry ok
  });

  test('403 csrf twice: surfaces the error, no loop', () async {
    await login();
    server.failNext('/task', 403, body: {'error': 'Invalid CSRF token'});
    server.failNext('/task', 403, body: {'error': 'Invalid CSRF token'});
    await expectLater(
      createTask().catchError(
        (Object e) => throw ApiError.fromDio(e as DioException),
      ),
      throwsA(isA<CsrfError>()),
    );
    expect(stack.count('POST', '/task'), 2);
  });

  test('403 without csrf is not retried', () async {
    await login();
    server.failNext('/task', 403, body: {'error': 'Forbidden'});
    await expectLater(createTask(), throwsA(isA<DioException>()));
    expect(stack.count('POST', '/task'), 1);
  });

  test('token cleared on login and logout', () async {
    await login();
    await createTask();
    await stack.dio.get('/logout');
    await login();
    await createTask();
    expect(stack.count('GET', '/csrf-token'), 2);
  });

  test('token cleared on any 401', () async {
    await login();
    await createTask();
    server.failNext('/tasks', 401);
    await expectLater(stack.dio.get('/tasks'), throwsA(isA<DioException>()));
    await createTask();
    expect(stack.count('GET', '/csrf-token'), 2);
  });

  test('failed token fetch rejects the mutation', () async {
    await login();
    server.failNext('/csrf-token', 500);
    server.failNext('/csrf-token', 500);
    server.failNext('/csrf-token', 500);
    server.failNext('/csrf-token', 500);
    await expectLater(createTask(), throwsA(isA<DioException>()));
    expect(stack.count('POST', '/task'), 0);
  });
}
