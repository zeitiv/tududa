import 'package:drift/drift.dart';

import 'app_database.dart';

/// Generic, entity-name based access to the synced tables, for code that
/// handles all entities alike (the outbox, id resolution, reconcile). Lanes
/// use their typed DAOs instead.
extension EntityAccess on AppDatabase {
  /// SQL table name of a `SyncEntity`.
  String tableNameOf(String entity) => switch (entity) {
    SyncEntity.task => 'tasks',
    SyncEntity.project => 'projects',
    SyncEntity.area => 'areas',
    SyncEntity.note => 'notes',
    SyncEntity.tag => 'tags',
    SyncEntity.inbox => 'inbox_items',
    _ => throw ArgumentError.value(entity, 'entity', 'Unknown sync entity'),
  };

  /// Drift tables touched by writes to [entity] (for stream invalidation).
  Set<TableInfo> _touched(String entity) => switch (entity) {
    SyncEntity.task => {tasks, taskTags},
    SyncEntity.project => {projects},
    SyncEntity.area => {areas},
    SyncEntity.note => {notes, noteTags},
    SyncEntity.tag => {tags, taskTags, noteTags},
    SyncEntity.inbox => {inboxItems},
    _ => throw ArgumentError.value(entity, 'entity', 'Unknown sync entity'),
  };

  /// The column [column] (`uid`, `server_id`) of one row, or null.
  Future<Object?> entityColumn(
    String entity,
    String localId,
    String column,
  ) async {
    final rows = await customSelect(
      'SELECT $column AS v FROM ${tableNameOf(entity)} WHERE local_id = ?',
      variables: [Variable<String>(localId)],
    ).get();
    return rows.isEmpty ? null : rows.first.data['v'];
  }

  /// Whether a row with [localId] exists.
  Future<bool> entityExists(String entity, String localId) async =>
      (await customSelect(
        'SELECT 1 AS v FROM ${tableNameOf(entity)} WHERE local_id = ?',
        variables: [Variable<String>(localId)],
      ).get()).isNotEmpty;

  /// Removes a row and its join rows (task_tags / note_tags). The search index
  /// follows through triggers.
  Future<void> deleteEntityRow(String entity, String localId) async {
    final id = [Variable<String>(localId)];
    final touched = _touched(entity);
    await transaction(() async {
      if (entity == SyncEntity.task) {
        await customUpdate(
          'DELETE FROM task_tags WHERE task_local_id = ?',
          variables: id,
          updates: touched,
          updateKind: UpdateKind.delete,
        );
      } else if (entity == SyncEntity.note) {
        await customUpdate(
          'DELETE FROM note_tags WHERE note_local_id = ?',
          variables: id,
          updates: touched,
          updateKind: UpdateKind.delete,
        );
      }
      await customUpdate(
        'DELETE FROM ${tableNameOf(entity)} WHERE local_id = ?',
        variables: id,
        updates: touched,
        updateKind: UpdateKind.delete,
      );
    });
  }

  /// Full-reconcile helper: deletes every *clean* row of [entity] that has a
  /// uid the server did not list in [serverUids]. A row is clean when it has
  /// no dirty fields, is not pending delete and has no outbox entry. Rows
  /// without a uid (never pushed) are never touched. Returns the removed
  /// local ids.
  Future<List<String>> removeCleanMissing(
    String entity,
    Set<String> serverUids,
  ) async {
    final rows = await customSelect(
      'SELECT local_id, uid FROM ${tableNameOf(entity)} '
      "WHERE uid IS NOT NULL AND dirty_fields = '{}' AND pending_delete = 0 "
      'AND NOT EXISTS (SELECT 1 FROM outbox o '
      "WHERE o.entity = '$entity' AND o.local_id = ${tableNameOf(entity)}.local_id)",
    ).get();
    final gone = [
      for (final r in rows)
        if (!serverUids.contains(r.read<String>('uid')))
          r.read<String>('local_id'),
    ];
    if (gone.isEmpty) return gone;
    await transaction(() async {
      for (final id in gone) {
        await deleteEntityRow(entity, id);
      }
    });
    return gone;
  }
}
