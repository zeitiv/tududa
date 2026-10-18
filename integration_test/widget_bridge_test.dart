// Runs on an Android emulator/device (NOT part of `flutter test`):
//   flutter test integration_test/widget_bridge_test.dart -d emulator-5554
//
// A shelf fake Tududi listens on 127.0.0.1 of the device (the debug network
// security config allows cleartext to localhost). Signing in through the UI
// must provision the native vault through `tududa/session`; signing out must
// clear it.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:tududa/app.dart';
import 'package:tududa/auth/session/session_controller.dart';
import 'package:tududa/core/platform/session_bridge.dart';
import 'package:tududa/settings/providers/settings_provider.dart';

import '../test/support/fake_tududi/fake_tududi.dart';

const _email = 'widget@tududa.test';
const _password = 'widget-pw-1';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login provisions the native vault, logout clears it', (
    tester,
  ) async {
    final fake = FakeTududi()..addUser(_email, _password);
    final http = await shelf_io.serve(fake.handler, '127.0.0.1', 0);
    addTearDown(() => http.close(force: true));
    final url = 'http://127.0.0.1:${http.port}';

    final bridge = MethodChannelSessionBridge();
    await bridge.clear();
    expect((await bridge.state()).provisioned, isFalse);

    SharedPreferences.setMockInitialValues({
      'server_url': url,
      'allow_insecure_http': true,
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const TududiApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Login screen: the first two text fields are email and password.
    final fields = find.byType(TextFormField);
    expect(fields, findsAtLeastNWidgets(2));
    await tester.enterText(fields.at(0), _email);
    await tester.enterText(fields.at(1), _password);
    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final provisioned = await bridge.state();
    expect(provisioned.provisioned, isTrue);
    expect(provisioned.serverUrl, url);
    expect(provisioned.accountUid, fake.users[_email]!.uid);
    final creds = await bridge.getCredentials();
    expect(creds?.email, _email);
    expect(creds?.password, _password);
    // The Dart cookie jar persists in the vault, not in appDocs/.cookies.
    expect(await bridge.readCookies('dart-jar/.index'), isNotEmpty);

    // Logout through the session controller (same path as Settings).
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TududiApp)),
    );
    await container.read(sessionControllerProvider.notifier).logout();
    await tester.pumpAndSettle();

    final cleared = await bridge.state();
    expect(cleared.provisioned, isFalse);
    expect(await bridge.getCredentials(), isNull);
    expect(await bridge.readCookies('dart-jar/.index'), isEmpty);
    expect(Platform.isAndroid, isTrue);
  });
}
