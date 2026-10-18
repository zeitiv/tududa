import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/auth/providers/auth_provider.dart';
import 'package:tududa/core/router/auth_redirect.dart';

void main() {
  const pending = [AuthStatus.initial, AuthStatus.loading];
  const unauth = [AuthStatus.unauthenticated, AuthStatus.error];
  const locations = [
    '/today',
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
        expect(run(s, true, '/today'), '/login?from=%2Ftoday');
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
        expect(run(AuthStatus.authenticated, server, '/today'), isNull);
        expect(run(AuthStatus.authenticated, server, '/projects/1'), isNull);
      });
      test('auth route without from -> /today server=$server', () {
        expect(run(AuthStatus.authenticated, server, '/login'), '/today');
        expect(
          run(AuthStatus.authenticated, server, '/server-config'),
          '/today',
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
      expect(login('//evil.com'), '/today');
      expect(login('http://evil'), '/today');
      expect(login('https://evil.com/x'), '/today');
      expect(login('evil.com'), '/today');
      expect(login('/\\evil.com'), '/today');
      expect(login(''), '/today');
      expect(login('/login'), '/today');
      expect(login('/login?from=/tasks'), '/today');
      expect(login('/server-config'), '/today');
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
        '/today',
      );
    });
  });
}
