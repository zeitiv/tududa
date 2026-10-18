import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_tududi/dio_adapter.dart';
import 'fake_tududi/fake_tududi.dart';

void main() {
  late FakeTududi server;
  late Dio dio;

  setUp(() {
    server = FakeTududi()..addUser('a@b.c', 'pw');
    dio = makeDio(server);
  });

  Future<Response<dynamic>> login() =>
      dio.post('/login', data: {'email': 'a@b.c', 'password': 'pw'});

  Future<Options> csrfOptions() async {
    final r = await dio.get('/csrf-token');
    return Options(headers: {'x-csrf-token': r.data['csrfToken']});
  }

  Future<DioException> expectDioError(Future<Object?> f) async {
    try {
      await f;
    } on DioException catch (e) {
      return e;
    }
    fail('expected DioException');
  }

  test('login ok sets connect.sid and returns user', () async {
    final r = await login();
    expect(r.statusCode, 200);
    expect(r.data['user']['email'], 'a@b.c');
    expect(r.headers['set-cookie']!.single, startsWith('connect.sid='));
    expect((await dio.get('/current_user')).data['user']['email'], 'a@b.c');
  });

  test('bad login -> 401 with errors list', () async {
    final e = await expectDioError(
      dio.post('/login', data: {'email': 'a@b.c', 'password': 'x'}),
    );
    expect(e.response!.statusCode, 401);
    expect(e.response!.data['errors'], ['Invalid credentials']);
  });

  test('5th bad attempt -> 429', () async {
    final codes = <int?>[];
    for (var i = 0; i < 5; i++) {
      final e = await expectDioError(
        dio.post('/login', data: {'email': 'a@b.c', 'password': 'x'}),
      );
      codes.add(e.response!.statusCode);
    }
    expect(codes, [401, 401, 401, 401, 429]);
  });

  test('mutation without CSRF -> 403, with token -> 200', () async {
    await login();
    server.seedTask(uid: 't1', name: 'x');
    final e = await expectDioError(dio.patch('/task/t1', data: {'name': 'y'}));
    expect(e.response!.statusCode, 403);
    expect(e.response!.data['error'], 'Invalid CSRF token');

    final r = await dio.patch(
      '/task/t1',
      data: {'name': 'y'},
      options: await csrfOptions(),
    );
    expect(r.statusCode, 200);
    expect(r.data['name'], 'y');
  });

  test('csrf-token without session -> 401', () async {
    final e = await expectDioError(dio.get('/csrf-token'));
    expect(e.response!.statusCode, 401);
    expect(e.response!.data['error'], 'Authentication required');
  });

  test('expireAllSessions -> 401 on protected route', () async {
    await login();
    expect((await dio.get('/tasks')).statusCode, 200);
    server.expireAllSessions();
    final e = await expectDioError(dio.get('/tasks'));
    expect(e.response!.statusCode, 401);
  });

  test('current_user without session -> {user:null}', () async {
    final r = await dio.get('/current_user');
    expect(r.statusCode, 200);
    expect(r.data, {'user': null});
  });

  test('logout clears session', () async {
    await login();
    await dio.get('/logout');
    final e = await expectDioError(dio.get('/tasks'));
    expect(e.response!.statusCode, 401);
    expect((await dio.get('/current_user')).data['user'], isNull);
  });

  test('offline -> DioException', () async {
    server.offline = true;
    final e = await expectDioError(dio.get('/health'));
    expect(e.type, DioExceptionType.connectionError);
    server.offline = false;
    expect((await dio.get('/health')).data, {'status': 'ok'});
  });

  test('failNext injects one failure', () async {
    await login();
    server.failNext('/tasks', 500);
    final e = await expectDioError(dio.get('/tasks'));
    expect(e.response!.statusCode, 500);
    expect((await dio.get('/tasks')).statusCode, 200);
    expect(server.requests.last.path, '/tasks');
  });

  test('task list pagination', () async {
    await login();
    for (var i = 0; i < 5; i++) {
      server.seedTask(name: 'T$i');
    }
    final r = await dio.get(
      '/tasks',
      queryParameters: {'limit': 2, 'offset': 4},
    );
    expect(r.data['tasks'], hasLength(1));
    expect(r.data['pagination'], {
      'total': 5,
      'limit': 2,
      'offset': 4,
      'hasMore': false,
    });
    final r2 = await dio.get('/tasks', queryParameters: {'limit': 2});
    expect(r2.data['pagination']['hasMore'], isTrue);
  });

  test('PATCH null clears due_date, omitted key keeps it', () async {
    await login();
    server.seedTask(uid: 't1', dueDate: '2025-01-02', note: 'n');
    final opts = await csrfOptions();
    var r = await dio.patch('/task/t1', data: {'note': 'm'}, options: opts);
    expect(r.data['due_date'], '2025-01-02');
    expect(r.data['note'], 'm');
    r = await dio.patch('/task/t1', data: {'due_date': null}, options: opts);
    expect(r.data['due_date'], isNull);
    expect(r.data['note'], 'm');
  });
}
