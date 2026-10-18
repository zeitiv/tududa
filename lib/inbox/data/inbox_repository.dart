import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_providers.dart';
import '../../core/api/page.dart';
import '../../core/ids.dart';
import '../domain/inbox_item.dart';
import 'inbox_api.dart';

abstract interface class InboxRepository {
  Future<Page<InboxItem>> list({int limit, int offset});
  Future<InboxItem> capture(String text, {String source});
  Future<InboxItem> setStatus(InboxUid uid, InboxStatus status);
  Future<void> process(InboxUid uid, {InboxProcessTarget? target});
  Future<void> delete(InboxUid uid);
  Future<InboxAnalysis> analyzeText(String text, {CancelToken? cancelToken});
}

class RemoteInboxRepository implements InboxRepository {
  RemoteInboxRepository(this._api);
  final InboxApi _api;

  @override
  Future<Page<InboxItem>> list({int limit = 20, int offset = 0}) async {
    final p = await _api.list(limit: limit, offset: offset);
    return Page(
      items: [for (final d in p.items) d.toDomain()],
      total: p.total,
      limit: p.limit,
      offset: p.offset,
      hasMore: p.hasMore,
    );
  }

  @override
  Future<InboxItem> capture(String text, {String source = 'mobile'}) async =>
      (await _api.create(text, source: source)).toDomain();

  @override
  Future<InboxItem> setStatus(InboxUid uid, InboxStatus status) async =>
      (await _api.update(uid, status: status)).toDomain();

  @override
  Future<void> process(InboxUid uid, {InboxProcessTarget? target}) async {
    await _api.process(uid, target: target);
  }

  @override
  Future<void> delete(InboxUid uid) => _api.delete(uid);

  @override
  Future<InboxAnalysis> analyzeText(String text, {CancelToken? cancelToken}) =>
      _api.analyzeText(text, cancelToken: cancelToken);
}

/// The server-facing repository. The offline repository pages the server
/// through it; the sync handler talks to `InboxApi` directly.
final remoteInboxRepositoryProvider = Provider<RemoteInboxRepository>(
  (ref) => RemoteInboxRepository(InboxApi(ref.watch(dioProvider))),
);
