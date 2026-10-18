import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/auth/session/credential_store.dart';
import 'package:tududa/auth/session/native_credential_store.dart';
import 'package:tududa/core/platform/session_bridge.dart';

void main() {
  test('round trip through the bridge; write is provision-only', () async {
    final bridge = InMemorySessionBridge();
    final store = NativeCredentialStore(bridge);
    expect(await store.read(), isNull);

    await store.write(const Credentials(email: 'x', password: 'y'));
    expect(await store.read(), isNull, reason: 'write never stores');

    await bridge.provision(
      serverUrl: 'https://s',
      allowInsecureHttp: false,
      email: 'a@b.test',
      password: 'secret',
      accountUid: 'u',
    );
    final c = (await store.read())!;
    expect((c.email, c.password), ('a@b.test', 'secret'));
    expect(c.toString(), isNot(contains('secret')));

    await store.clear();
    expect(await store.read(), isNull);
    expect(bridge.clearCount, 1);
  });

  test('bridge failures read as no credentials', () async {
    final bridge = InMemorySessionBridge()..failWith = StateError('x');
    final store = NativeCredentialStore(bridge);
    expect(await store.read(), isNull);
    await store.clear();
  });
}
