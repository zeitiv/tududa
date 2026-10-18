import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/auth/session/credential_store.dart';
import 'package:tududa/auth/session/session_controller.dart';
import 'package:tududa/auth/session/session_providers.dart';
import 'package:tududa/core/api/api_error.dart';
import 'package:tududa/core/api/api_providers.dart';

import '../support/fake_tududi/fake_tududi.dart';
import 'auth_harness.dart';

const _email = 'a@b.test';
const _password = 'hunter2-secret';

FakeTududi _serverWithUser() => FakeTududi()..addUser(_email, _password);

void main() {
  group('bootstrap', () {
    test('no server -> noServer', () async {
      final h = await AuthHarness.create(withServerUrl: false);
      await h.session.bootstrap();
      expect(h.state, isA<SessionNoServer>());
    });

    test('{user:null} -> signedOut', () async {
      final h = await AuthHarness.create(server: _serverWithUser());
      await h.session.bootstrap();
      expect(h.state, isA<SessionSignedOut>());
    });

    test('valid cookie -> signedIn and caches the user', () async {
      final h = await AuthHarness.create(server: _serverWithUser());
      await h.session.login(_email, _password);
      final h2 = await AuthHarness.create(
        server: h.server,
        jar: h.jar,
        prefs: {'user_data': jsonEncode(h.session.cachedUser!.toJson())},
      );
      await h2.session.bootstrap();
      final s = h2.state as SessionSignedIn;
      expect(s.user.email, _email);
      expect(s.offline, isFalse);
    });

    test('offline with cached user and cookie -> signedIn(offline)', () async {
      final server = _serverWithUser();
      final h = await AuthHarness.create(server: server);
      await h.session.login(_email, _password);
      final cached = jsonEncode(h.session.cachedUser!.toJson());

      server.offline = true;
      final h2 = await AuthHarness.create(
        server: server,
        jar: h.jar,
        prefs: {'user_data': cached},
      );
      await h2.session.bootstrap();
      expect((h2.state as SessionSignedIn).offline, isTrue);
    });

    test('offline without cache -> signedOut', () async {
      final server = _serverWithUser()..offline = true;
      final h = await AuthHarness.create(server: server);
      await h.session.bootstrap();
      expect(h.state, isA<SessionSignedOut>());
    });

    test('offline with cache but empty jar -> signedOut', () async {
      final server = _serverWithUser();
      final h = await AuthHarness.create(server: server);
      await h.session.login(_email, _password);
      final cached = jsonEncode(h.session.cachedUser!.toJson());
      server.offline = true;
      final h2 = await AuthHarness.create(
        server: server,
        prefs: {'user_data': cached},
      );
      await h2.session.bootstrap();
      final s = h2.state as SessionSignedOut;
      expect(s.lastEmail, _email);
    });
  });

  group('login', () {
    test('success stores user, credentials and cache', () async {
      final h = await AuthHarness.create(server: _serverWithUser());
      final user = await h.session.login(' $_email ', _password);
      expect(user.email, _email);
      expect(user.uid, isNotEmpty);
      expect((h.state as SessionSignedIn).user, user);
      final creds = await h.credentials.read();
      expect(creds?.email, _email);
      expect(creds?.password, _password);
      expect(h.session.cachedUser, user);
    });

    test('invalid credentials', () async {
      final h = await AuthHarness.create(server: _serverWithUser());
      await expectLater(
        h.session.login(_email, 'wrong'),
        throwsA(isA<InvalidCredentialsError>()),
      );
      expect((h.state as SessionSignedOut).lastEmail, _email);
      expect(await h.credentials.read(), isNull);
    });

    test('email not verified', () async {
      final server = _serverWithUser()
        ..failNext('/login', 403, body: {'error': 'Email not verified'});
      final h = await AuthHarness.create(server: server);
      await expectLater(
        h.session.login(_email, _password),
        throwsA(isA<EmailNotVerifiedError>()),
      );
    });

    test('password login disabled', () async {
      final server = _serverWithUser()
        ..failNext(
          '/login',
          403,
          body: {'error': 'Password login is disabled for this account'},
        );
      final h = await AuthHarness.create(server: server);
      await expectLater(
        h.session.login(_email, _password),
        throwsA(isA<PasswordLoginDisabledError>()),
      );
    });

    test('network failure', () async {
      final server = _serverWithUser()..offline = true;
      final h = await AuthHarness.create(server: server);
      await expectLater(
        h.session.login(_email, _password),
        throwsA(
          isA<ApiError>().having((e) => e.isTransient, 'transient', true),
        ),
      );
      expect(h.state, isA<SessionSignedOut>());
    });

    test('5 bad logins lock out with retry-after', () async {
      final h = await AuthHarness.create(server: _serverWithUser());
      for (var i = 0; i < 4; i++) {
        await expectLater(
          h.session.login(_email, 'bad$i'),
          throwsA(isA<InvalidCredentialsError>()),
        );
      }
      await expectLater(
        h.session.login(_email, 'bad5'),
        throwsA(
          isA<RateLimitedError>().having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 900),
          ),
        ),
      );
    });

    test('failed login never leaks the password in the error', () async {
      final h = await AuthHarness.create(server: _serverWithUser());
      Object? caught;
      try {
        await h.session.login(_email, '${_password}x');
      } catch (e) {
        caught = e;
      }
      expect(caught, isA<InvalidCredentialsError>());
      final err = caught! as ApiError;
      expect(err.message, isNot(contains(_password)));
      expect(err.toString(), isNot(contains(_password)));
      expect(
        const Credentials(email: _email, password: _password).toString(),
        isNot(contains(_password)),
      );
    });

    test('account switch clears previous credentials and cache', () async {
      final server = _serverWithUser()..addUser('c@d.test', 'pw2');
      final h = await AuthHarness.create(server: server);
      await h.session.login(_email, _password);
      final firstUid = (h.state as SessionSignedIn).user.uid;

      await expectLater(
        h.session.login('c@d.test', 'wrong'),
        throwsA(isA<InvalidCredentialsError>()),
      );
      // Old session must not survive a failed switch.
      expect(h.state, isA<SessionSignedOut>());

      await h.session.login('c@d.test', 'pw2');
      final s = h.state as SessionSignedIn;
      expect(s.user.uid, isNot(firstUid));
      expect((await h.credentials.read())!.email, 'c@d.test');
      expect(h.session.cachedUser!.email, 'c@d.test');
    });
  });

  group('logout', () {
    test('uses GET and clears jar, credentials and cache', () async {
      final h = await AuthHarness.create(server: _serverWithUser());
      await h.session.login(_email, _password);
      await h.session.logout();

      expect(
        h.server.requests
            .where((r) => r.path == '/logout')
            .map((r) => r.method),
        ['GET'],
      );
      expect(h.state, isA<SessionSignedOut>());
      expect(await h.credentials.read(), isNull);
      expect(h.session.cachedUser, isNull);
      expect(await h.jar.loadForRequest(Uri.parse(testServerUrl)), isEmpty);
      expect(h.server.sessions, isEmpty);
    });

    test('still clears locally when the server is unreachable', () async {
      final h = await AuthHarness.create(server: _serverWithUser());
      await h.session.login(_email, _password);
      h.server.offline = true;
      await h.session.logout();
      expect(h.state, isA<SessionSignedOut>());
      expect(await h.credentials.read(), isNull);
    });
  });

  group('re-authentication', () {
    test('expired session is renewed once for 3 parallel requests', () async {
      final h = await AuthHarness.create(server: _serverWithUser());
      await h.session.login(_email, _password);
      final dio = h.container.read(dioProvider);
      h.server.expireAllSessions();
      final loginsBefore = h.server.requests
          .where((r) => r.path == '/login')
          .length;

      final results = await Future.wait([
        dio.get<Object?>('/tasks'),
        dio.get<Object?>('/tasks'),
        dio.get<Object?>('/tasks'),
      ]);
      expect(results.map((r) => r.statusCode), [200, 200, 200]);
      expect(
        h.server.requests.where((r) => r.path == '/login').length,
        loginsBefore + 1,
      );
      expect(h.state, isA<SessionSignedIn>());
    });

    test('refused credentials -> expired and credentials cleared', () async {
      final server = _serverWithUser();
      final h = await AuthHarness.create(server: server);
      await h.session.login(_email, _password);
      final dio = h.container.read(dioProvider);
      server
        ..expireAllSessions()
        ..users[_email] = FakeUser(
          uid: 'u',
          email: _email,
          password: 'changed',
        );

      await expectLater(
        dio.get<Object?>('/tasks'),
        throwsA(isA<DioException>()),
      );
      final s = h.state as SessionExpired;
      expect(s.lastEmail, _email);
      expect(await h.credentials.read(), isNull);
    });

    test('network failure during reauth does not expire', () async {
      final server = _serverWithUser();
      final h = await AuthHarness.create(server: server);
      await h.session.login(_email, _password);
      final dio = h.container.read(dioProvider);
      server.expireAllSessions();
      server.failNextConnection('/login', times: 5);

      await expectLater(
        dio.get<Object?>('/tasks'),
        throwsA(isA<DioException>()),
      );
      expect(h.state, isA<SessionSignedIn>());
      expect(await h.credentials.read(), isNotNull);
    });

    test('no stored credentials -> expired, no loop', () async {
      final server = _serverWithUser();
      final h = await AuthHarness.create(
        server: server,
        credentials: const NoopCredentialStore(),
      );
      await h.session.login(_email, _password);
      final dio = h.container.read(dioProvider);
      server.expireAllSessions();
      await expectLater(
        dio.get<Object?>('/tasks'),
        throwsA(isA<DioException>()),
      );
      expect(h.state, isA<SessionExpired>());
      expect(server.requests.where((r) => r.path == '/login').length, 1);
    });
  });

  test('userClock follows the signed-in user timezone and skew', () async {
    final server = _serverWithUser();
    server.users[_email]!.timezone = 'Asia/Tokyo';
    final h = await AuthHarness.create(server: server);
    final clock = h.container.read(userClockProvider);
    expect(clock.zoneName, 'UTC');
    await h.session.login(_email, _password);
    await Future<void>.delayed(Duration.zero);
    expect(clock.zoneName, 'Asia/Tokyo');
  });
}
