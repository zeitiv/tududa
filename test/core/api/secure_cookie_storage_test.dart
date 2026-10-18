import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/api/secure_cookie_storage.dart';
import 'package:tududa/core/platform/session_bridge.dart';

void main() {
  late Directory docs;
  late InMemorySessionBridge bridge;
  late SecureCookieStorage storage;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('cookies');
    addTearDown(() => docs.deleteSync(recursive: true));
    bridge = InMemorySessionBridge();
    storage = SecureCookieStorage(bridge, documentsDirectory: () async => docs);
  });

  test('read / write / delete / deleteAll', () async {
    await storage.init(true, false);
    expect(await storage.read('host'), isNull);
    await storage.write('host', '[{"a":1}]');
    expect(await storage.read('host'), '[{"a":1}]');
    await storage.write('other', 'x');
    await storage.delete('host');
    expect(await storage.read('host'), isNull);
    await storage.deleteAll(['other', 'missing']);
    expect(await storage.read('other'), isNull);
    expect(bridge.cookies, isEmpty);
  });

  test('migrates the old .cookies folder once, then deletes it', () async {
    final legacy = Directory('${docs.path}/.cookies/ie0_ps1')
      ..createSync(recursive: true);
    File('${legacy.path}/fake.tududi.test').writeAsStringSync('LEGACY');
    File('${legacy.path}/.index').writeAsStringSync('["fake.tududi.test"]');
    // A jar with other flags is not imported (but the folder still goes).
    final otherJar = Directory('${docs.path}/.cookies/ie1_ps0')
      ..createSync(recursive: true);
    File('${otherJar.path}/skip').writeAsStringSync('NO');

    await storage.init(true, false);

    expect(await storage.read('fake.tududi.test'), 'LEGACY');
    expect(await storage.read('.index'), '["fake.tududi.test"]');
    expect(await storage.read('skip'), isNull);
    expect(Directory('${docs.path}/.cookies').existsSync(), isFalse);

    // Second start: nothing to migrate, data intact.
    await storage.init(true, false);
    expect(await storage.read('fake.tududi.test'), 'LEGACY');
  });

  test('migration never overwrites vault data', () async {
    await storage.write('h', 'NEW');
    final legacy = Directory('${docs.path}/.cookies/ie0_ps1')
      ..createSync(recursive: true);
    File('${legacy.path}/h').writeAsStringSync('OLD');
    await storage.init(true, false);
    expect(await storage.read('h'), 'NEW');
  });

  test('a failing vault keeps the old folder and does not throw', () async {
    final legacy = Directory('${docs.path}/.cookies/ie0_ps1')
      ..createSync(recursive: true);
    File('${legacy.path}/h').writeAsStringSync('OLD');
    bridge.failWith = StateError('vault down');
    await storage.init(true, false);
    expect(Directory('${docs.path}/.cookies').existsSync(), isTrue);
  });

  test('works as PersistCookieJar storage', () async {
    final jar = PersistCookieJar(storage: storage);
    final uri = Uri.parse('https://fake.tududi.test/api');
    await jar.saveFromResponse(uri, [Cookie('connect.sid', 'abc')]);

    final again = PersistCookieJar(storage: storage);
    final loaded = await again.loadForRequest(uri);
    expect(loaded.single.value, 'abc');
    await again.deleteAll();
    expect(
      await PersistCookieJar(storage: storage).loadForRequest(uri),
      isEmpty,
    );
  });
}
