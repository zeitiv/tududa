import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/platform/session_bridge.dart';
import 'package:tududa/core/platform/widget_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InMemorySessionBridge', () {
    test('provision / getCredentials / state / clear', () async {
      final b = InMemorySessionBridge();
      expect((await b.state()).provisioned, isFalse);
      expect(await b.getCredentials(), isNull);
      await b.provision(
        serverUrl: 'https://s',
        allowInsecureHttp: false,
        email: 'a@b',
        password: 'pw',
        accountUid: 'u1',
      );
      final c = (await b.getCredentials())!;
      expect((c.email, c.password), ('a@b', 'pw'));
      expect(c.toString(), isNot(contains('pw')));
      final s = await b.state();
      expect(
        (s.provisioned, s.accountUid, s.serverUrl),
        (true, 'u1', 'https://s'),
      );
      await b.clear();
      expect((await b.state()).provisioned, isFalse);
      expect(await b.getCredentials(), isNull);
    });

    test(
      'cookies per host; empty list removes; account change resets',
      () async {
        final b = InMemorySessionBridge();
        await b.writeCookies('h', ['a=1']);
        expect(await b.readCookies('h'), ['a=1']);
        await b.writeCookies('h', const []);
        expect(await b.readCookies('h'), isEmpty);
        await b.writeCookies('h', ['a=1']);
        await b.provision(
          serverUrl: 's',
          allowInsecureHttp: false,
          email: 'e',
          password: 'p',
          accountUid: 'u',
        );
        expect(await b.readCookies('h'), isEmpty);
      },
    );
  });

  group('InMemoryWidgetBridge', () {
    test('log, sinceSeq, ack, events', () async {
      final b = InMemoryWidgetBridge();
      final seen = <int>[];
      final sub = b.changes.listen(seen.add);
      await pumpEventQueue();
      b.logChange('a', 2);
      b.logChange('b', 2);
      await pumpEventQueue();
      expect(seen, [0, 1, 2]);
      expect((await b.pendingChanges(1)).map((c) => c.uid), ['b']);
      await b.ack(1);
      expect((await b.pendingChanges(0)).map((c) => c.seq), [2]);
      await b.overlay('a', 2);
      await b.refresh();
      expect(b.overlays.single.uid, 'a');
      expect(b.refreshCount, 1);
      await sub.cancel();
    });
  });

  group('MethodChannel implementations speak the contract', () {
    final calls = <MethodCall>[];
    Object? reply;

    setUp(() {
      calls.clear();
      reply = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('tududa/session'), (
            c,
          ) async {
            calls.add(c);
            return reply;
          });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('tududa/widget'), (
            c,
          ) async {
            calls.add(c);
            return reply;
          });
    });

    test('session', () async {
      final b = MethodChannelSessionBridge();
      await b.provision(
        serverUrl: 'https://s',
        allowInsecureHttp: true,
        email: 'e',
        password: 'p',
        accountUid: 'u',
      );
      expect(calls.single.method, 'provision');
      expect(calls.single.arguments, {
        'serverUrl': 'https://s',
        'allowInsecureHttp': true,
        'email': 'e',
        'password': 'p',
        'accountUid': 'u',
      });
      reply = {'serverUrl': 's', 'email': 'e', 'password': 'p'};
      expect((await b.getCredentials())!.email, 'e');
      reply = null;
      expect(await b.getCredentials(), isNull);
      reply = ['x=1'];
      expect(await b.readCookies('h'), ['x=1']);
      await b.writeCookies('h', ['x=1']);
      expect(calls.last.arguments, {
        'host': 'h',
        'cookies': ['x=1'],
      });
      reply = {
        'provisioned': true,
        'serverUrl': 's',
        'accountUid': 'u',
        'loginFailed': true,
      };
      final s = await b.state();
      expect((s.provisioned, s.loginFailed), (true, true));
    });

    test('widget', () async {
      final b = MethodChannelWidgetBridge();
      await b.refresh();
      await b.overlay('u', 2);
      expect(calls.last.arguments, {'uid': 'u', 'status': 2});
      reply = [
        {'seq': 3, 'uid': 'u', 'status': 2, 'atMillis': 99},
      ];
      final list = await b.pendingChanges(2);
      expect(calls.last.arguments, {'sinceSeq': 2});
      expect(
        (list.single.seq, list.single.uid, list.single.atMillis),
        (3, 'u', 99),
      );
      await b.ack(3);
      expect(calls.last.method, 'ack');
    });
  });
}
