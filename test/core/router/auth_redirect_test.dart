import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/auth/providers/auth_provider.dart';
import 'package:tududa/core/router/auth_redirect.dart';

void main() {
  const pending = [AuthStatus.initial, AuthStatus.loading];
  const unauth = [AuthStatus.unauthenticated, AuthStatus.error];
  const locations = [
    '/tasks',
    '/tasks/5?x=1',
    '/projects',
    '/login',
    '/server-config',
  ];

  String? run(AuthStatus s, bool server, String loc) =>
      authRedirect(status: s, hasServer: server, location: Uri.parse(loc));

  group('pending statuses never redirect', () {
    for (final s in pending) {
      for (final server in [true, false]) {
        for (final loc in locations) {
          test('$s server=$server $loc', () {
            expect(run(s, server, loc), isNull);
          });
        }
      }
    }
  });

  group('unauthenticated without server', () {
    for (final s in unauth) {
      for (final loc in locations) {
        test('$s $loc', () {
          expect(
            run(s, false, loc),
            loc == '/server-config' ? isNull : '/server-config',
          );
        });
      }
    }
  });

  group('unauthenticated with server', () {
    for (final s in unauth) {
      test('$s auth routes stay', () {
        expect(run(s, true, '/login'), isNull);
        expect(run(s, true, '/server-config'), isNull);
      });
      test('$s protected adds from', () {
        expect(run(s, true, '/tasks'), '/login?from=%2Ftasks');
      });
      test('$s from encodes query', () {
        final r = run(s, true, '/tasks/5?x=1&y=a b')!;
        final uri = Uri.parse(r);
        expect(uri.path, '/login');
        expect(uri.queryParameters['from'], '/tasks/5?x=1&y=a%20b');
      });
    }
  });

  group('authenticated', () {
    for (final server in [true, false]) {
      test('protected stays server=$server', () {
        expect(run(AuthStatus.authenticated, server, '/tasks'), isNull);
        expect(run(AuthStatus.authenticated, server, '/projects/1'), isNull);
      });
      test('auth route without from -> /tasks server=$server', () {
        expect(run(AuthStatus.authenticated, server, '/login'), '/tasks');
        expect(
          run(AuthStatus.authenticated, server, '/server-config'),
          '/tasks',
        );
      });
    }

    String? login(String from) => authRedirect(
      status: AuthStatus.authenticated,
      hasServer: true,
      location: Uri(path: '/login', queryParameters: {'from': from}),
    );

    test('safe from is honored', () {
      expect(login('/projects/3'), '/projects/3');
      expect(login('/tasks/5?x=1&y=2'), '/tasks/5?x=1&y=2');
    });
    test('unsafe from falls back', () {
      expect(login('//evil.com'), '/tasks');
      expect(login('http://evil'), '/tasks');
      expect(login('https://evil.com/x'), '/tasks');
      expect(login('evil.com'), '/tasks');
      expect(login('/\\evil.com'), '/tasks');
      expect(login(''), '/tasks');
      expect(login('/login'), '/tasks');
      expect(login('/login?from=/tasks'), '/tasks');
      expect(login('/server-config'), '/tasks');
    });
    test('raw encoded from is decoded', () {
      expect(
        authRedirect(
          status: AuthStatus.authenticated,
          hasServer: true,
          location: Uri.parse('/login?from=%2Fnotes%2F7'),
        ),
        '/notes/7',
      );
      expect(
        authRedirect(
          status: AuthStatus.authenticated,
          hasServer: true,
          location: Uri.parse('/login?from=%2F%2Fevil.com'),
        ),
        '/tasks',
      );
    });
  });
}
