import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/auth/session/server_config.dart';
import 'package:tududa/auth/session/session_controller.dart';
import 'package:tududa/core/api/api_error.dart';

import '../support/fake_tududi/dio_adapter.dart';
import '../support/fake_tududi/fake_tududi.dart';
import 'auth_harness.dart';

void main() {
  group('normalizeServerUrl', () {
    const table = {
      'tududi.example.com': 'https://tududi.example.com',
      '  tududi.example.com/  ': 'https://tududi.example.com',
      'HTTPS://Tududi.Example.COM': 'https://tududi.example.com',
      'https://tududi.example.com/api': 'https://tududi.example.com',
      'https://tududi.example.com/api/': 'https://tududi.example.com',
      'https://example.com/tududi/api': 'https://example.com/tududi',
      'https://example.com/tududi///': 'https://example.com/tududi',
      'http://192.168.1.5:3002': 'http://192.168.1.5:3002',
      'localhost:3002': 'https://localhost:3002',
    };
    table.forEach((input, expected) {
      test('"$input" -> $expected', () {
        expect(normalizeServerUrl(input), expected);
      });
    });

    for (final bad in [
      '',
      '   ',
      'http://',
      'https://',
      'ftp://example.com',
      'not a url',
      'https://user:pw@example.com',
    ]) {
      test('rejects "$bad"', () {
        expect(
          () => normalizeServerUrl(bad),
          throwsA(isA<InvalidServerUrlError>()),
        );
      });
    }
  });

  group('ServerValidator', () {
    test('https server returns version', () async {
      final server = FakeTududi();
      final info = await ServerValidator(adapter: FakeTududiAdapter(server))
          .validate('fake.tududi.test/');
      expect(info.url, 'https://fake.tududi.test');
      expect(info.version, '1.9.4');
      expect(info.isInsecure, isFalse);
      expect(server.requests.map((r) => r.path), ['/health', '/version']);
    });

    test(
      'plain http needs allowInsecure and sends nothing before that',
      () async {
        final server = FakeTududi();
        final v = ServerValidator(adapter: FakeTududiAdapter(server));
        await expectLater(
          v.validate('http://10.0.0.2:3002'),
          throwsA(
            isA<InsecureServerError>().having(
              (e) => e.url,
              'url',
              'http://10.0.0.2:3002',
            ),
          ),
        );
        expect(server.requests, isEmpty);

        final info = await v.validate(
          'http://10.0.0.2:3002',
          allowInsecure: true,
        );
        expect(info.isInsecure, isTrue);
      },
    );

    test('health failure surfaces a typed ApiError', () async {
      final server = FakeTududi()..offline = true;
      await expectLater(
        ServerValidator(adapter: FakeTududiAdapter(server))
            .validate('fake.tududi.test'),
        throwsA(isA<ApiError>()),
      );
      server.offline = false;
      server.failNext('/health', 502);
      await expectLater(
        ServerValidator(adapter: FakeTududiAdapter(server))
            .validate('fake.tududi.test'),
        throwsA(isA<ServerError>()),
      );
    });

    test('missing /version is fine', () async {
      final server = FakeTududi()..failNext('/version', 404);
      final info = await ServerValidator(adapter: FakeTududiAdapter(server))
          .validate('fake.tududi.test');
      expect(info.version, isNull);
    });
  });

  group('configureServer', () {
    test('persists url under server_url and allowInsecure flag', () async {
      final h = await AuthHarness.create(withServerUrl: false);
      await h.session.bootstrap();
      expect(h.state, isA<SessionNoServer>());

      await expectLater(
        h.session.configureServer('http://fake.tududi.test'),
        throwsA(isA<InsecureServerError>()),
      );
      expect(h.container.read(serverConfigProvider), isNull);

      await h.session.configureServer(
        'http://fake.tududi.test/api',
        allowInsecure: true,
      );
      final cfg = h.container.read(serverConfigProvider)!;
      expect(cfg.url, 'http://fake.tududi.test');
      expect(cfg.allowInsecure, isTrue);
      expect(h.state, isA<SessionSignedOut>());
    });
  });
}
