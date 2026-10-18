import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/api/api_error.dart';
import 'package:tududa/core/ids.dart';
import 'package:tududa/inbox/data/inbox_api.dart';
import 'package:tududa/inbox/data/inbox_dto.dart';
import 'package:tududa/inbox/domain/inbox_item.dart';

import 'inbox_support.dart';

void main() {
  group('InboxItemDto', () {
    test('parses a full row', () {
      final dto = InboxItemDto.fromJson(
        jsonDecode('''
{"uid":"abc","title":"t","content":"Buy milk","status":"ignored",
 "source":"telegram","created_at":"2025-03-01T08:00:00.000Z",
 "updated_at":"2025-03-02T08:00:00.000Z","attachments":[]}''')
            as Map<String, dynamic>,
      );
      final item = dto.toDomain();
      expect(item.uid, const InboxUid('abc'));
      expect(item.content, 'Buy milk');
      expect(item.isIgnored, isTrue);
      expect(item.source, 'telegram');
      expect(item.createdAt, DateTime.utc(2025, 3, 1, 8));
    });

    test('minimal row falls back to defaults; unknown status is unknown', () {
      final item = InboxItemDto.fromJson({'uid': 'x', 'title': 'Only title'})
          .toDomain();
      expect(item.content, 'Only title');
      expect(item.status, InboxStatus.added);
      expect(item.source, 'manual');
      expect(
        InboxItemDto.fromJson({'uid': 'x', 'status': 'trashed'})
            .toDomain()
            .status,
        InboxStatus.unknown,
      );
    });
  });

  group('InboxApi against the fake', () {
    test(
      'capture sends content+source with csrf and returns the item',
      () async {
        final stack = await inboxStack();
        final api = InboxApi(stack.dio);
        final dto = await api.create('Call mom', source: 'mobile');
        expect(dto.content, 'Call mom');
        expect(dto.source, 'mobile');
        final req = stack.server.requests.lastWhere((r) => r.method == 'POST');
        expect(req.path, '/inbox');
        expect(req.body, {'content': 'Call mom', 'source': 'mobile'});
        expect(req.status, 201);
        expect(req.headers['x-csrf-token'], isNotEmpty);
      },
    );

    test('empty content -> ValidationError', () async {
      final api = InboxApi((await inboxStack()).dio);
      await expectLater(api.create('  '), throwsA(isA<ValidationError>()));
    });

    test('list paginates with limit/offset', () async {
      final stack = await inboxStack(seed: 5);
      final api = InboxApi(stack.dio);
      final p1 = await api.list(limit: 2);
      expect(p1.items.map((i) => i.content), ['Item 5', 'Item 4']);
      expect(p1.total, 5);
      expect(p1.hasMore, isTrue);
      final p3 = await api.list(limit: 2, offset: 4);
      expect(p3.items.map((i) => i.content), ['Item 1']);
      expect(p3.hasMore, isFalse);
      expect(stack.server.requests.last.query, {'limit': '2', 'offset': '4'});
    });

    test('update/ignore, process (with target) and delete', () async {
      final stack = await inboxStack(seed: 3);
      final api = InboxApi(stack.dio);
      final ignored = await api.update(
        const InboxUid('inbox-1'),
        status: InboxStatus.ignored,
      );
      expect(ignored.status, 'ignored');

      await api.process(
        const InboxUid('inbox-2'),
        target: const ProcessedAsTask('task-9'),
      );
      final proc = stack.server.requests.lastWhere(
        (r) => r.path == '/inbox/inbox-2/process',
      );
      expect(proc.method, 'PATCH');
      expect(proc.body, {'task_uid': 'task-9'});
      expect(proc.headers['x-csrf-token'], isNotEmpty);

      await api.delete(const InboxUid('inbox-3'));
      final left = await api.list();
      expect(left.items.map((i) => i.uid.value), ['inbox-1']);
      await expectLater(
        api.get(const InboxUid('inbox-3')),
        throwsA(isA<NotFoundError>()),
      );
    });

    test('process without target sends an empty body', () async {
      final stack = await inboxStack(seed: 1);
      await InboxApi(stack.dio).process(const InboxUid('inbox-1'));
      expect(stack.server.requests.last.path, '/inbox/inbox-1/process');
      expect(stack.server.requests.last.status, 200);
    });

    test('analyzeText posts content and parses tags', () async {
      final stack = await inboxStack();
      final a = await InboxApi(stack.dio).analyzeText('Pay rent #bills +home');
      expect(a.tags, ['bills']);
      expect(a.projects, ['home']);
      expect(a.cleanedContent, 'Pay rent');
      expect(stack.server.requests.last.body, {
        'content': 'Pay rent #bills +home',
      });
    });

    test(
      'expired session re-authenticates and the write goes through',
      () async {
        final stack = await inboxStack();
        stack.server.expireAllSessions();
        final dto = await InboxApi(stack.dio).create('After expiry');
        expect(dto.content, 'After expiry');
        expect(stack.callbacks.calls, 1);
      },
    );
  });
}
