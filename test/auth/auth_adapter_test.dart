import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/auth/providers/auth_provider.dart';
import 'package:tududa/auth/session/auth_messages.dart';
import 'package:tududa/core/api/api_error.dart';
import 'package:tududa/core/router/auth_redirect.dart';

import '../support/fake_tududi/fake_tududi.dart';
import 'auth_harness.dart';

void main() {
  test('authProvider mirrors the session and feeds the redirect', () async {
    final server = FakeTududi()..addUser('a@b.test', 'pw');
    final h = await AuthHarness.create(server: server);
    final seen = <AuthStatus>[];
    h.container.listen<AuthState>(
      authProvider,
      (_, n) => seen.add(n.status),
      fireImmediately: true,
    );

    String? redirect() {
      final a = h.container.read(authProvider);
      return authRedirect(
        status: a.status,
        hasServer: (a.serverUrl ?? '').isNotEmpty,
        location: Uri.parse('/tasks'),
      );
    }

    expect(h.container.read(authProvider).status, AuthStatus.initial);
    expect(redirect(), isNull);

    await h.container.read(authProvider.notifier).checkAuth();
    await Future<void>.delayed(Duration.zero);
    var a = h.container.read(authProvider);
    expect(a.status, AuthStatus.unauthenticated);
    expect(a.serverUrl, testServerUrl);
    expect(redirect(), startsWith('/login'));

    expect(
      await h.container.read(authProvider.notifier).login('a@b.test', 'bad'),
      isFalse,
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      h.container.read(authProvider).error,
      'Incorrect email or password.',
    );

    expect(
      await h.container.read(authProvider.notifier).login('a@b.test', 'pw'),
      isTrue,
    );
    await Future<void>.delayed(Duration.zero);
    a = h.container.read(authProvider);
    expect(a.status, AuthStatus.authenticated);
    expect(a.user?.email, 'a@b.test');
    expect(a.error, isNull);
    expect(redirect(), isNull);
    expect(seen, contains(AuthStatus.loading));

    await h.container.read(authProvider.notifier).clearServerConfig();
    await Future<void>.delayed(Duration.zero);
    a = h.container.read(authProvider);
    expect(a.serverUrl, isNull);
    expect(redirect(), '/server-config');
  });

  group('describeAuthError', () {
    test('rate limit shows minutes remaining', () {
      expect(
        describeAuthError(const RateLimitedError('x', Duration(seconds: 900))),
        contains('15 minutes'),
      );
      expect(
        describeAuthError(const RateLimitedError('x', Duration(seconds: 30))),
        contains('1 minute.'),
      );
    });

    test('typed messages', () {
      expect(
        describeAuthError(const InvalidCredentialsError()),
        contains('password'),
      );
      expect(
        describeAuthError(const EmailNotVerifiedError()),
        contains('verified'),
      );
      expect(
        describeAuthError(const PasswordLoginDisabledError()),
        contains('SSO'),
      );
      expect(describeAuthError(const NetworkError()), contains('reach'));
    });
  });
}
