import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/auth/session/native_credential_store.dart';
import 'package:tududa/auth/session/session_controller.dart';
import 'package:tududa/core/platform/session_bridge.dart';

import '../support/fake_tududi/fake_tududi.dart';
import 'auth_harness.dart';

const _email = 'a@b.test';
const _password = 'hunter2-secret';

void main() {
  late InMemorySessionBridge bridge;
  late FakeTududi server;
  late AuthHarness h;
  late List<String> events;

  setUp(() async {
    bridge = InMemorySessionBridge();
    server = FakeTududi()
      ..addUser(_email, _password)
      ..addUser('c@d.test', 'other-pw');
    h = await AuthHarness.create(
      server: server,
      credentials: NativeCredentialStore(bridge),
      overrides: [sessionBridgeProvider.overrideWithValue(bridge)],
    );
    events = [];
    h.session.onAccountChanged = () async {
      events.add('wipe(clearCount=${bridge.clearCount})');
    };
  });

  test('login provisions the vault', () async {
    final user = await h.session.login(_email, _password);
    expect(bridge.provisionCount, 1);
    expect(bridge.accountUid, user.uid);
    expect(bridge.serverUrl, testServerUrl);
    expect(bridge.allowInsecureHttp, isFalse);
    final stored = (await h.credentials.read())!;
    expect((stored.email, stored.password), (_email, _password));
  });

  test('a failed login provisions nothing', () async {
    await expectLater(h.session.login(_email, 'wrong'), throwsA(anything));
    expect(bridge.provisionCount, 0);
  });

  test('a native failure never breaks sign-in', () async {
    bridge.failWith = StateError('native down');
    await h.session.login(_email, _password);
    expect(h.state, isA<SessionSignedIn>());
  });

  test('logout clears the vault before the local wipe', () async {
    await h.session.login(_email, _password);
    await h.session.logout();
    expect(bridge.clearCount, greaterThanOrEqualTo(1));
    expect(await bridge.getCredentials(), isNull);
    expect(events.first, matches(RegExp(r'wipe\(clearCount=[1-9]')));
    expect(h.state, isA<SessionSignedOut>());
  });

  test('account switch clears first, then wipes, then provisions', () async {
    final first = await h.session.login(_email, _password);
    events.clear();
    final second = await h.session.login('c@d.test', 'other-pw');
    expect(second.uid, isNot(first.uid));
    expect(events, hasLength(1));
    expect(events.single, matches(RegExp(r'wipe\(clearCount=[1-9]')));
    expect(bridge.accountUid, second.uid);
    expect((await h.credentials.read())!.email, 'c@d.test');
  });

  test('same account login does not clear', () async {
    await h.session.login(_email, _password);
    await h.session.login(_email, _password);
    expect(bridge.clearCount, 0);
    expect(events, isEmpty);
  });

  test('re-login reads the stored credentials from the vault', () async {
    await h.session.login(_email, _password);
    // Session expires on the server; only the vault still knows the password.
    server.sessions.clear();
    await h.jar.deleteAll();
    expect(await h.session.reauthenticate(), isTrue);
    expect(h.state, isA<SessionSignedIn>());
  });

  test('bootstrap provisions a vault that lost the account, once', () async {
    await h.session.login(_email, _password);
    final creds = bridge.credentials!;
    // Vault emptied of the account but still holds credentials: re-provision.
    bridge.accountUid = '';
    final before = bridge.provisionCount;
    await h.session.bootstrap();
    expect(bridge.provisionCount, before + 1);
    await h.session.bootstrap();
    expect(bridge.provisionCount, before + 1, reason: 'already in sync');
    expect(bridge.credentials!.email, creds.email);
  });

  test('clearing the server wipes the vault too', () async {
    await h.session.login(_email, _password);
    await h.session.clearServer();
    expect(bridge.clearCount, greaterThanOrEqualTo(1));
    expect((await bridge.state()).provisioned, isFalse);
  });
}
