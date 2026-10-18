import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/api/api_client.dart';
import 'package:tududa/core/api/api_error.dart';

import '../../support/api_stack.dart';
import '../../support/fake_tududi/fake_tududi.dart';

void main() {
  test('login -> mutation -> session expiry -> transparent re-login', () async {
    final server = FakeTududi()..addUser('a@b.c', 'pw');
    final callbacks = FakeAuthCallbacks();
    final stack = TestStack(server, callbacks: callbacks);
    final dio = stack.dio;
    callbacks.onReauth = () async {
      await dio.post('/login', data: {'email': 'a@b.c', 'password': 'pw'});
      return true;
    };

    // Login needs no CSRF token.
    await dio.post('/login', data: {'email': 'a@b.c', 'password': 'pw'});
    expect(stack.count('GET', '/csrf-token'), 0);

    // The first mutation fetches one automatically.
    final created = await dio.post('/task', data: {'name': 'one'});
    expect(created.statusCode, 201);
    expect(stack.count('GET', '/csrf-token'), 1);

    // Server forgets the session: 401 -> reauthenticate -> replay.
    server.expireAllSessions();
    final second = await dio.post('/task', data: {'name': 'two'});
    expect(second.statusCode, 201);
    expect(callbacks.calls, 1);
    expect(server.tasks.values.map((t) => t['name']), ['one', 'two']);
    expect(stack.count('GET', '/csrf-token'), 2);
  });

  test('base url, trailing slash and guard() mapping', () async {
    final server = FakeTududi()..addUser('a@b.c', 'pw');
    final stack = TestStack(server);
    expect(stack.dio.options.baseUrl, 'http://fake.tududi.test/api');
    expect(stack.dio.options.connectTimeout, const Duration(seconds: 10));
    expect(stack.dio.options.sendTimeout, const Duration(seconds: 20));
    expect(stack.dio.options.receiveTimeout, const Duration(seconds: 20));

    await expectLater(
      guard(
        () => stack.dio.post(
          '/login',
          data: {'email': 'a@b.c', 'password': 'bad'},
        ),
      ),
      throwsA(isA<InvalidCredentialsError>()),
    );
    await expectLater(
      guard(() => stack.dio.get('/task/nope')),
      throwsA(isA<UnauthorizedError>()),
    );
    // ApiError passes through untouched.
    await expectLater(
      guard<void>(() async => throw const NotFoundError('x')),
      throwsA(isA<NotFoundError>()),
    );
    await expectLater(
      guard<void>(() async => throw const FormatException('bad')),
      throwsA(isA<DecodingError>()),
    );
  });

  test('skew is reported from the Date header', () async {
    final server = FakeTududi()
      ..addUser('a@b.c', 'pw')
      ..serverSkew = const Duration(minutes: 5);
    final device = DateTime.utc(2025, 1, 1, 12);
    server.clock = () => device;
    Duration? seen;
    final stack = TestStack(server, onSkew: (d) => seen = d, now: () => device);
    await stack.dio.get('/health');
    expect(seen, const Duration(minutes: 5));
  });

  test('typedef DioFactory is usable', () {
    Dio f({
      required String serverUrl,
      required CookieJar jar,
      required SessionAuthCallbacks callbacks,
    }) => createDio(serverUrl: serverUrl, jar: jar, callbacks: callbacks);
    final DioFactory factory = f;
    expect(
      factory(
        serverUrl: 'http://x/',
        jar: TestStack(FakeTududi()).jar,
        callbacks: FakeAuthCallbacks(),
      ),
      isA<Dio>().having((d) => d.options.baseUrl, 'baseUrl', 'http://x/api'),
    );
  });
}
