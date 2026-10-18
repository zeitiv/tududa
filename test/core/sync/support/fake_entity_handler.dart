import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:tududa/core/api/api_client.dart';
import 'package:tududa/core/api/api_error.dart';
import 'package:tududa/core/api/page.dart';
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/db/dirty_fields.dart';
import 'package:tududa/core/db/entity_access.dart';
import 'package:tududa/core/sync/merge.dart';
import 'package:tududa/core/sync/pull_paged.dart';
import 'package:tududa/core/sync/sync_handler.dart';

import '../../../support/fake_tududi/dio_adapter.dart';
import '../../../support/fake_tududi/fake_tududi.dart';

/// A plain Dio (no CSRF/auth interceptors) wired to [server]; failures are
/// turned into ApiErrors by `guard` in the handler.
Dio plainDio(FakeTududi server) =>
    Dio(BaseOptions(baseUrl: 'http://fake.tududi.test/api'))
      ..httpClientAdapter = FakeTududiAdapter(server);

/// In-memory server side for [FakeEntityHandler]: `/fake/projects` and
/// `/fake/notes` (create is `POST .../new`, so a test can fail it without
/// touching the list GET), both `{uid, id, name, parent_uid?, updated_at}`. A name of
/// `bad` is rejected with 400.
class FakeEntityServer {
  FakeEntityServer(this.server) {
    for (final path in const ['projects', 'notes']) {
      final items = store[path] = {};
      server.route(
        'GET',
        '/fake/$path',
        (ctx) {
          return FakeTududi.json(200, items.values.toList());
        },
        auth: false,
        csrf: false,
      );
      server.route(
        'POST',
        '/fake/$path/new',
        (ctx) {
          final body = ctx.bodyMap;
          if (body['name'] == 'bad') {
            return FakeTududi.json(400, {'error': 'Invalid name'});
          }
          final id = server.nextId();
          final item = <String, dynamic>{
            'id': id,
            'uid': '$path-$id',
            'name': body['name'],
            'parent_uid': body['parent_uid'],
            'updated_at': now().toIso8601String(),
          };
          items[item['uid'] as String] = item;
          return FakeTududi.json(201, item);
        },
        auth: false,
        csrf: false,
      );
      server.route(
        'PATCH',
        '/fake/$path/:uid',
        (ctx) {
          final item = items[ctx.params['uid']];
          if (item == null) return FakeTududi.json(404, {'error': 'Not found'});
          if (ctx.bodyMap['name'] == 'bad') {
            return FakeTududi.json(422, {'error': 'Invalid name'});
          }
          item.addAll(ctx.bodyMap);
          item['updated_at'] = now().toIso8601String();
          return FakeTududi.json(200, item);
        },
        auth: false,
        csrf: false,
      );
      server.route(
        'DELETE',
        '/fake/$path/:uid',
        (ctx) {
          return items.remove(ctx.params['uid']) == null
              ? FakeTududi.json(404, {'error': 'Not found'})
              : FakeTududi.json(200, {'ok': true});
        },
        auth: false,
        csrf: false,
      );
    }
  }

  final FakeTududi server;
  DateTime Function() now = () => DateTime.now().toUtc();

  /// path (`projects` | `notes`) -> uid -> item
  final Map<String, Map<String, Map<String, dynamic>>> store = {};

  int requests(String method, String path) =>
      server.requests.where((r) => r.method == method && r.path == path).length;
}

/// Minimal handler used to exercise the engine without the real lanes.
///
/// - `SyncEntity.project` rows live in `projects` (`name`);
/// - `SyncEntity.note` rows live in `notes` (`title` as the name, and
///   `project_local_id` as the parent reference that must have a uid).
class FakeEntityHandler extends SyncHandler {
  FakeEntityHandler(this.entity);

  @override
  final String entity;

  /// Calls recorded for assertions.
  final List<String> calls = [];

  bool get _isNote => entity == SyncEntity.note;
  String get _path => _isNote ? 'notes' : 'projects';
  String get _table => _isNote ? 'notes' : 'projects';
  String get _nameCol => _isNote ? 'title' : 'name';
  String get _field => 'name';

  Future<Map<String, Object?>?> _row(SyncContext ctx, String localId) async {
    final r = await ctx.db
        .customSelect(
          'SELECT * FROM $_table WHERE local_id = ?',
          variables: [Variable(localId)],
        )
        .get();
    return r.isEmpty ? null : r.first.data;
  }

  @override
  Future<void> pull(SyncContext ctx) async {
    calls.add('pull');
    await pullPaged<Map<String, dynamic>>(
      fetch: (offset) => guard(() async {
        final res = await ctx.dio.get<Object?>('/fake/$_path');
        return Page.fromJson(res.data, (j) => j);
      }),
      updatedAt: (j) => DateTime.tryParse('${j['updated_at']}'),
      cursor: ctx.pullCursor,
      onPage: (items) async {
        for (final j in items) {
          await _apply(ctx, j);
        }
      },
    );
  }

  @override
  Future<void> fullReconcile(SyncContext ctx) async {
    calls.add('fullReconcile');
    final res = await guard(() => ctx.dio.get<Object?>('/fake/$_path'));
    final items = [
      for (final j in res.data as List) Map<String, dynamic>.from(j as Map),
    ];
    for (final j in items) {
      await _apply(ctx, j);
    }
    await ctx.db.removeCleanMissing(entity, {
      for (final j in items) j['uid'] as String,
    });
  }

  Future<void> _apply(SyncContext ctx, Map<String, dynamic> j) async {
    final uid = j['uid'] as String;
    final localId = await ctx.ids.localIdOfUid(entity, uid);
    final serverUpdated = DateTime.parse(j['updated_at'] as String);
    final snapshot = {_field: j['name']};
    if (localId == null) {
      await ctx.db.customInsert(
        'INSERT INTO $_table (local_id, uid, server_id, $_nameCol, '
        'server_updated_at, local_updated_at, base_json) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable('pulled-$uid'),
          Variable(uid),
          Variable(j['id'] as int),
          Variable(j['name'] as String),
          Variable(serverUpdated.toIso8601String()),
          Variable(ctx.now.toIso8601String()),
          Variable(BaseJson.encode(snapshot)),
        ],
      );
      return;
    }
    final row = (await _row(ctx, localId))!;
    final dirty = DirtyFields.decode(row['dirty_fields'] as String?);
    var name = j['name'];
    var newDirty = dirty;
    if (dirty.isNotEmpty) {
      final merged = mergeFields(
        BaseJson.decode(row['base_json'] as String?),
        {_field: row[_nameCol]},
        snapshot,
        dirty.toMap(),
        entity: entity,
        localId: localId,
        serverUpdatedAt: serverUpdated,
        skew: ctx.skew,
      );
      merged.notices.forEach(ctx.notice);
      name = merged.value[_field];
      newDirty = DirtyFields(merged.dirtyFields);
    }
    await ctx.db.customUpdate(
      'UPDATE $_table SET $_nameCol = ?, server_updated_at = ?, '
      'dirty_fields = ?, base_json = ? WHERE local_id = ?',
      variables: [
        Variable(name as String),
        Variable(serverUpdated.toIso8601String()),
        Variable(newDirty.encode()),
        Variable(BaseJson.encode(snapshot)),
        Variable(localId),
      ],
    );
  }

  @override
  Future<PushResult> push(SyncContext ctx, OutboxEntry e) async {
    calls.add('push ${e.op} ${e.localId}');
    final row = await _row(ctx, e.localId);
    if (e.op == OutboxOp.delete) {
      final uid = row?['uid'] as String?;
      if (row != null && uid == null) return PushResult.dropped;
      if (uid != null) {
        try {
          await guard(() => ctx.dio.delete<Object?>('/fake/$_path/$uid'));
        } on NotFoundError {
          // Already gone: the goal is reached.
        }
      }
      await ctx.db.deleteEntityRow(entity, e.localId);
      return PushResult.ok;
    }
    if (row == null) return PushResult.dropped;

    final name = row[_nameCol] as String?;
    final dirty = DirtyFields.decode(row['dirty_fields'] as String?);
    if (e.op == OutboxOp.create) {
      String? parentUid;
      if (_isNote && row['project_local_id'] != null) {
        parentUid = await ctx.ids.requireUid(
          SyncEntity.project,
          row['project_local_id']! as String,
        );
      }
      final res = await guard(
        () => ctx.dio.post<Object?>(
          '/fake/$_path/new',
          data: {'name': name, 'parent_uid': parentUid},
        ),
      );
      final j = Map<String, dynamic>.from(res.data! as Map);
      await ctx.db.customUpdate(
        'UPDATE $_table SET uid = ?, server_id = ?, server_updated_at = ?, '
        'dirty_fields = ?, base_json = ? WHERE local_id = ?',
        variables: [
          Variable(j['uid'] as String),
          Variable(j['id'] as int),
          Variable(j['updated_at'] as String),
          Variable(dirty.clearSent(dirty.toMap()).encode()),
          Variable(BaseJson.encode({_field: j['name']})),
          Variable(e.localId),
        ],
      );
      return PushResult.ok;
    }

    final uid = row['uid'] as String?;
    if (uid == null) return PushResult.waitForDependency;
    final body = {if (dirty.isDirty(_field)) 'name': name};
    if (body.isEmpty) return PushResult.dropped;
    final res = await guard(
      () => ctx.dio.patch<Object?>('/fake/$_path/$uid', data: body),
    );
    final j = Map<String, dynamic>.from(res.data! as Map);
    await ctx.db.customUpdate(
      'UPDATE $_table SET server_updated_at = ?, dirty_fields = ?, '
      'base_json = ? WHERE local_id = ?',
      variables: [
        Variable(j['updated_at'] as String),
        Variable(dirty.clearSent({_field: dirty.editedAt(_field)!}).encode()),
        Variable(BaseJson.encode({_field: j['name']})),
        Variable(e.localId),
      ],
    );
    return PushResult.ok;
  }

  @override
  Future<void> rollback(SyncContext ctx, OutboxEntry e, ApiError error) async {
    calls.add('rollback ${e.op} ${e.localId}');
    final row = await _row(ctx, e.localId);
    if (row == null) return;
    final base = BaseJson.decode(row['base_json'] as String?);
    if (row['uid'] == null || base == null || error is NotFoundError) {
      await ctx.db.deleteEntityRow(entity, e.localId);
    } else {
      await ctx.db.customUpdate(
        'UPDATE $_table SET $_nameCol = ?, dirty_fields = ?, '
        'pending_delete = 0 WHERE local_id = ?',
        variables: [
          Variable('${base[_field]}'),
          Variable(jsonEncode(<String, int>{})),
          Variable(e.localId),
        ],
      );
    }
    ctx.notice(
      ConflictNotice.rolledBack(
        entity: entity,
        localId: e.localId,
        message: error.message,
      ),
    );
  }
}
