import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tududa/auth/session/credential_store.dart';
import 'package:tududa/auth/session/session_controller.dart';
import 'package:tududa/auth/session/session_providers.dart';
import 'package:tududa/core/api/api_providers.dart';
import 'package:tududa/settings/providers/settings_provider.dart';

import '../support/fake_tududi/dio_adapter.dart';
import '../support/fake_tududi/fake_tududi.dart';

const testServerUrl = 'https://fake.tududi.test';

/// A container running the production session stack against [server].
class AuthHarness {
  AuthHarness._(this.server, this.container, this.jar, this.credentials);

  final FakeTududi server;
  final ProviderContainer container;
  final CookieJar jar;
  final CredentialStore credentials;

  SessionController get session =>
      container.read(sessionControllerProvider.notifier);
  SessionState get state => container.read(sessionControllerProvider);

  static Future<AuthHarness> create({
    FakeTududi? server,
    Map<String, Object> prefs = const {},
    bool withServerUrl = true,
    CredentialStore? credentials,
    CookieJar? jar,
    List<Override> overrides = const [],
  }) async {
    server ??= FakeTududi();
    SharedPreferences.setMockInitialValues({
      if (withServerUrl) 'server_url': testServerUrl,
      ...prefs,
    });
    final sp = await SharedPreferences.getInstance();
    final theJar = jar ?? CookieJar();
    final store = credentials ?? InMemoryCredentialStore();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        cookieJarProvider.overrideWithValue(theJar),
        credentialStoreProvider.overrideWithValue(store),
        dioTuningProvider.overrideWithValue(
          DioTuning(
            adapter: FakeTududiAdapter(server),
            enableLogging: false,
            retryDelay: (_) async {},
          ),
        ),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    return AuthHarness._(server, container, theJar, store);
  }
}
