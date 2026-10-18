import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/api/interceptors/redacting_log_interceptor.dart';

class _StubAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"token":"resp-secret-token","ok":true}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        'set-cookie': ['session=cookie-secret-value'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late List<String> logs;
  late Dio dio;

  setUp(() {
    logs = [];
    dio = Dio(BaseOptions(baseUrl: 'http://example.test/api'))
      ..httpClientAdapter = _StubAdapter()
      ..interceptors.add(RedactingLogInterceptor(sink: logs.add));
  });

  test('login request redacts password, cookies and tokens', () async {
    final body = {'email': 'a@b.c', 'password': 'hunter2'};
    final res = await dio.post(
      '/login',
      data: body,
      options: Options(
        headers: {
          'Cookie': 'sid=cookie-secret-value',
          'X-CSRF-Token': 'csrf-xyz',
        },
      ),
    );

    final out = logs.join('\n');
    expect(out, isNot(contains('hunter2')));
    expect(out, isNot(contains('cookie-secret-value')));
    expect(out, isNot(contains('csrf-xyz')));
    expect(out, isNot(contains('resp-secret-token')));
    expect(out, contains('POST'));
    expect(out, contains('/api/login'));
    expect(out, contains('200'));
    expect(out, contains('a@b.c'));
    // Real data is not mutated.
    expect(body['password'], 'hunter2');
    expect(res.data['token'], 'resp-secret-token');
  });

  test('redacts nested maps and lists without mutating them', () async {
    final body = {
      'user': {'new_password': 'nested-pw', 'name': 'n'},
      'items': [
        {'api_key': 'key-123'},
        'plain',
      ],
    };
    await dio.post('/x', data: body);

    final out = logs.join('\n');
    expect(out, isNot(contains('nested-pw')));
    expect(out, isNot(contains('key-123')));
    expect(out, contains('plain'));
    expect((body['user'] as Map)['new_password'], 'nested-pw');
  });

  test('handles string bodies', () async {
    await dio.post('/x', data: 'raw-string-body');
    expect(logs.join('\n'), contains('raw-string-body'));
  });
}
