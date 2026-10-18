import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/api_stack.dart';
import '../../support/fake_tududi/fake_tududi.dart';

void main() {
  late FakeTududi server;
  late TestStack stack;

  setUp(() async {
    server = FakeTududi()..addUser('a@b.c', 'pw');
    stack = TestStack(server);
    await stack.dio.post('/login', data: {'email': 'a@b.c', 'password': 'pw'});
  });

  test(
    'GET is retried on connection errors with exponential backoff',
    () async {
      server.failNextConnection('/tasks', times: 2);
      final res = await stack.dio.get('/tasks');
      expect(res.statusCode, 200);
      expect(stack.count('GET', '/tasks'), 3);
      expect(stack.delays, const [
        Duration(milliseconds: 400),
        Duration(milliseconds: 800),
      ]);
    },
  );

  test('GET is retried 3 times then fails', () async {
    server.failNextConnection('/tasks', times: 10);
    await expectLater(stack.dio.get('/tasks'), throwsA(isA<DioException>()));
    expect(stack.count('GET', '/tasks'), 4);
    expect(stack.delays, const [
      Duration(milliseconds: 400),
      Duration(milliseconds: 800),
      Duration(milliseconds: 1600),
    ]);
  });

  test('retries 502/503/504 but not 500 or 400', () async {
    for (final s in [502, 503, 504]) {
      server.failNext('/tasks', s);
    }
    expect((await stack.dio.get('/tasks')).statusCode, 200);
    expect(stack.count('GET', '/tasks'), 4);

    server.failNext('/tasks', 500);
    await expectLater(stack.dio.get('/tasks'), throwsA(isA<DioException>()));
    server.failNext('/tasks', 400);
    await expectLater(stack.dio.get('/tasks'), throwsA(isA<DioException>()));
    expect(stack.count('GET', '/tasks'), 6);
  });

  test('POST and PATCH are never retried', () async {
    server.seedTask(uid: 't1');
    server.failNextConnection('/task', times: 1);
    await expectLater(
      stack.dio.post('/task', data: {'name': 'x'}),
      throwsA(isA<DioException>()),
    );
    server.failNext('/task/t1', 503);
    await expectLater(
      stack.dio.patch('/task/t1', data: {'name': 'y'}),
      throwsA(isA<DioException>()),
    );
    expect(stack.delays, isEmpty);
    expect(stack.count('PATCH', '/task/t1'), 1);
  });

  test('DELETE is retried', () async {
    server.seedTask(uid: 't1');
    server.failNext('/task/t1', 503);
    final res = await stack.dio.delete('/task/t1');
    expect(res.statusCode, 200);
    expect(stack.delays, hasLength(1));
  });

  test('429 honours Retry-After', () async {
    server.failNext('/tasks', 429, headers: {'retry-after': '2'});
    final res = await stack.dio.get('/tasks');
    expect(res.statusCode, 200);
    expect(stack.delays, const [Duration(seconds: 2)]);
  });

  test('429 with a huge Retry-After is not retried', () async {
    server.failNext('/tasks', 429, headers: {'retry-after': '900'});
    await expectLater(stack.dio.get('/tasks'), throwsA(isA<DioException>()));
    expect(stack.delays, isEmpty);
    expect(stack.count('GET', '/tasks'), 1);
  });

  test('cancelled requests are not retried', () async {
    final token = CancelToken();
    server.latency = const Duration(milliseconds: 20);
    final f = stack.dio.get('/tasks', cancelToken: token);
    final expectation = expectLater(
      f,
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );
    token.cancel('stop');
    await expectation;
    expect(stack.delays, isEmpty);
  });

  test('cancel during backoff stops the retry', () async {
    final token = CancelToken();
    final stack2 = TestStack(server);
    await stack2.dio.post('/login', data: {'email': 'a@b.c', 'password': 'pw'});
    server.failNextConnection('/tasks', times: 5);
    // The recording delay cancels, as a user navigating away would.
    final dio = stack2.dio;
    final f = dio.get('/tasks', cancelToken: token);
    Future<void>.delayed(Duration.zero, () => token.cancel());
    await expectLater(f, throwsA(isA<DioException>()));
    expect(stack2.count('GET', '/tasks'), lessThan(5));
  });
}
