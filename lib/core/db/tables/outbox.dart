import 'package:drift/drift.dart';

/// Entity names used in `outbox.entity` and as `sync_state` keys.
abstract final class SyncEntity {
  static const task = 'task';
  static const project = 'project';
  static const area = 'area';
  static const note = 'note';
  static const tag = 'tag';
  static const inbox = 'inbox';

  static const all = [area, project, tag, task, note, inbox];

  /// Order in which the engine pulls (parents before children).
  static const pullOrder = [area, project, tag, task, note, inbox];
}

/// Values of `outbox.op`.
///
/// `complete` carries `extra_json = {"completed": true|false}`; `false` is the
/// "uncomplete" that cancels a pending `complete`. `reorder` carries its new
/// order in `extra_json` and replaces an earlier pending `reorder`.
abstract final class OutboxOp {
  static const create = 'create';
  static const update = 'update';
  static const delete = 'delete';
  static const complete = 'complete';
  static const skipOccurrence = 'skip_occurrence';
  static const inboxProcess = 'inbox_process';
  static const reorder = 'reorder';
}

/// Values of `outbox.state`.
///
/// - `pending`: waiting for `not_before` / `next_attempt_at`, or never tried.
/// - `inflight`: being sent right now (reset to pending after a crash).
/// - `failed`: last attempt hit a transient error; retried after
///   `next_attempt_at`.
/// - `stuck`: failed 10 times; kept and shown, retried on manual sync only.
abstract final class OutboxState {
  static const pending = 'pending';
  static const inflight = 'inflight';
  static const failed = 'failed';
  static const stuck = 'stuck';
}

/// The queue of local changes not yet confirmed by the server.
@DataClassName('OutboxEntry')
@TableIndex(name: 'idx_outbox_target', columns: {#entity, #localId})
@TableIndex(name: 'idx_outbox_state', columns: {#state, #notBefore})
class Outbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entity => text()();
  TextColumn get localId => text()();
  TextColumn get op => text()();
  TextColumn get extraJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  /// Do not send before this instant (the undo window).
  DateTimeColumn get notBefore => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  TextColumn get state => text().withDefault(const Constant('pending'))();
  TextColumn get lastError => text().nullable()();
}
