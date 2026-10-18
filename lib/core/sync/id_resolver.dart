import 'package:drift/drift.dart' show Variable;

import '../db/app_database.dart';
import '../db/entity_access.dart';

/// Thrown by [IdResolver.requireUid] / [IdResolver.requireServerId] when the
/// referenced row has not been created on the server yet. The engine turns it
/// into `PushResult.waitForDependency`.
class DependencyPendingException implements Exception {
  const DependencyPendingException(this.entity, this.localId);
  final String entity;
  final String localId;

  @override
  String toString() => 'DependencyPendingException($entity $localId)';
}

/// Maps between local ids and server identifiers for any entity.
///
/// Handlers resolve references at send time:
/// `project_uid: await ctx.ids.requireUid('project', row.projectLocalId!)`.
class IdResolver {
  IdResolver(this._db);
  final AppDatabase _db;

  /// Server uid of a local row, or null if unknown or not pushed yet.
  Future<String?> uidOf(String entity, String localId) async =>
      await _db.entityColumn(entity, localId, 'uid') as String?;

  /// Numeric server id of a local row, or null.
  Future<int?> serverIdOf(String entity, String localId) async =>
      await _db.entityColumn(entity, localId, 'server_id') as int?;

  /// [uidOf], but throws [DependencyPendingException] when missing.
  Future<String> requireUid(String entity, String localId) async =>
      await uidOf(entity, localId) ??
      (throw DependencyPendingException(entity, localId));

  /// [serverIdOf], but throws [DependencyPendingException] when missing
  /// (e.g. `parent_task_id`).
  Future<int> requireServerId(String entity, String localId) async =>
      await serverIdOf(entity, localId) ??
      (throw DependencyPendingException(entity, localId));

  /// Local id of the row with server [uid], or null if not pulled yet.
  Future<String?> localIdOfUid(String entity, String uid) async {
    final rows = await _db
        .customSelect(
          'SELECT local_id FROM ${_db.tableNameOf(entity)} WHERE uid = ?',
          variables: [Variable(uid)],
        )
        .get();
    return rows.isEmpty ? null : rows.first.read<String>('local_id');
  }

  /// Local id of the row with numeric server [id], or null.
  Future<String?> localIdOfServerId(String entity, int id) async {
    final rows = await _db
        .customSelect(
          'SELECT local_id FROM ${_db.tableNameOf(entity)} WHERE server_id = ?',
          variables: [Variable(id)],
        )
        .get();
    return rows.isEmpty ? null : rows.first.read<String>('local_id');
  }

  /// Local id for [uid], creating nothing: use when applying pulled data whose
  /// references may point at rows pulled earlier in the same cycle.
  Future<Map<String, String>> localIdsByUid(String entity) async {
    final rows = await _db
        .customSelect(
          'SELECT local_id, uid FROM ${_db.tableNameOf(entity)} '
          'WHERE uid IS NOT NULL',
        )
        .get();
    return {
      for (final r in rows) r.read<String>('uid'): r.read<String>('local_id'),
    };
  }
}
