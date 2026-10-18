import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../db/entity_access.dart';

/// Queue counts shown in the UI.
class OutboxCounts {
  const OutboxCounts({this.pending = 0, this.failed = 0, this.stuck = 0});

  /// Waiting or in flight.
  final int pending;

  /// Last attempt failed transiently; will be retried automatically.
  final int failed;

  /// Gave up after the maximum attempts; needs a manual sync.
  final int stuck;

  @override
  bool operator ==(Object other) =>
      other is OutboxCounts &&
      other.pending == pending &&
      other.failed == failed &&
      other.stuck == stuck;

  @override
  int get hashCode => Object.hash(pending, failed, stuck);

  @override
  String toString() => 'OutboxCounts($pending, $failed, $stuck)';
}

/// The outbox queue.
///
/// [enqueue] must be called in the same `db.transaction` as the row write and
/// dirty-field marks it belongs to. It coalesces with entries already queued
/// for the same `(entity, local_id)` that are not in flight:
///
/// | queued \ new     | create | update      | delete                  | complete(true)  | complete(false)  |
/// |------------------|--------|-------------|-------------------------|-----------------|------------------|
/// | create           | add    | absorbed    | both removed + row gone | add             | add              |
/// | update           | add    | one entry   | updates removed, add    | add             | add              |
/// | delete           | add    | ignored     | one entry               | ignored         | ignored          |
/// | complete(true)   | add    | add         | complete removed, add   | one entry       | both removed     |
/// | complete(false)  | add    | add         | removed, add            | both removed    | one entry        |
/// | reorder          | add    | add         | removed, add            | add             | add              |
///
/// `reorder`+`reorder` keeps one entry with the newer `extra_json`;
/// `skip_occurrence` and `inbox_process` are never merged except that an
/// identical pending one is not queued twice. A queued `create` that is
/// absorbed keeps its original `not_before`; update+update moves `not_before`
/// to the newer value (debounce).
class OutboxDao {
  OutboxDao(this._db, {DateTime Function()? now})
    : _now = now ?? (() => DateTime.now().toUtc());

  final AppDatabase _db;
  final DateTime Function() _now;

  $OutboxTable get _t => _db.outbox;

  /// Queues [op] for a row. Returns the id of the entry that now represents
  /// the change, or null when nothing remains queued (cancelled, absorbed
  /// into nothing, or ignored because the row is pending delete).
  ///
  /// [notBefore] defaults to now; pass `now + 5s` for the undo window.
  Future<int?> enqueue({
    required String entity,
    required String localId,
    required String op,
    String? extraJson,
    DateTime? notBefore,
    DateTime? now,
  }) => _db.transaction(() async {
    final at = (now ?? _now()).toUtc();
    final nb = (notBefore ?? at).toUtc();

    // Entries that are in flight are never touched.
    final existing =
        await (_db.select(_t)
              ..where(
                (t) =>
                    t.entity.equals(entity) &
                    t.localId.equals(localId) &
                    t.state.equals(OutboxState.inflight).not(),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.id)]))
            .get();

    Future<int> insert() => _t.insertOne(
      OutboxCompanion.insert(
        entity: entity,
        localId: localId,
        op: op,
        extraJson: Value(extraJson),
        createdAt: at,
        notBefore: nb,
      ),
    );

    Future<void> removeIds(Iterable<int> ids) =>
        (_db.delete(_t)..where((t) => t.id.isIn(ids.toList()))).go();

    // A pending delete swallows everything that follows.
    final pendingDelete = existing.where((e) => e.op == OutboxOp.delete);
    if (pendingDelete.isNotEmpty) {
      return op == OutboxOp.delete ? pendingDelete.first.id : null;
    }

    switch (op) {
      case OutboxOp.update:
        final create = existing.where((e) => e.op == OutboxOp.create);
        if (create.isNotEmpty) return create.first.id;
        final update = existing.where((e) => e.op == OutboxOp.update);
        if (update.isNotEmpty) {
          final e = update.first;
          await (_db.update(_t)..where((t) => t.id.equals(e.id))).write(
            OutboxCompanion(
              notBefore: Value(nb),
              extraJson: Value(extraJson ?? e.extraJson),
              state: const Value(OutboxState.pending),
              nextAttemptAt: const Value(null),
            ),
          );
          return e.id;
        }
        return insert();

      case OutboxOp.delete:
        final creates = existing.where((e) => e.op == OutboxOp.create);
        if (creates.isNotEmpty) {
          // The server never saw this row: forget it entirely.
          await removeIds(existing.map((e) => e.id));
          await _db.deleteEntityRow(entity, localId);
          return null;
        }
        await removeIds(existing.map((e) => e.id));
        return insert();

      case OutboxOp.complete:
        final completed = _completedFlag(extraJson);
        final complete = existing.where(
          (e) => e.op == OutboxOp.complete && _completedFlag(e.extraJson),
        );
        final uncomplete = existing.where(
          (e) => e.op == OutboxOp.complete && !_completedFlag(e.extraJson),
        );
        final opposite = completed ? uncomplete : complete;
        if (opposite.isNotEmpty) {
          await removeIds([opposite.last.id]);
          return null;
        }
        final same = completed ? complete : uncomplete;
        if (same.isNotEmpty) return same.first.id;
        return insert();

      case OutboxOp.reorder:
        final reorder = existing.where((e) => e.op == OutboxOp.reorder);
        if (reorder.isNotEmpty) {
          final e = reorder.first;
          await (_db.update(_t)..where((t) => t.id.equals(e.id))).write(
            OutboxCompanion(
              extraJson: Value(extraJson),
              notBefore: Value(nb),
              state: const Value(OutboxState.pending),
              nextAttemptAt: const Value(null),
            ),
          );
          return e.id;
        }
        return insert();

      case OutboxOp.skipOccurrence:
      case OutboxOp.inboxProcess:
        final same = existing.where(
          (e) => e.op == op && e.extraJson == extraJson,
        );
        return same.isNotEmpty ? same.first.id : insert();

      default:
        return insert();
    }
  });

  /// `extra_json` of a `complete` entry: `{"completed": false}` is the
  /// uncomplete; anything else (including no extra) is a complete.
  static bool _completedFlag(String? extraJson) {
    if (extraJson == null) return true;
    try {
      final v = jsonDecode(extraJson);
      return !(v is Map && v['completed'] == false);
    } on FormatException {
      return true;
    }
  }

  /// Removes entry [id] (user discarded it, or it was sent).
  Future<void> remove(int id) =>
      (_db.delete(_t)..where((t) => t.id.equals(id))).go();

  /// Alias of [remove] for UI "discard" actions.
  Future<void> cancel(int id) => remove(id);

  Future<OutboxEntry?> byId(int id) =>
      (_db.select(_t)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Every queued entry, oldest first.
  Future<List<OutboxEntry>> all() =>
      (_db.select(_t)..orderBy([
            (t) => OrderingTerm.asc(t.createdAt),
            (t) => OrderingTerm.asc(t.id),
          ]))
          .get();

  /// Entries that have not failed terminally (pending, inflight, failed).
  Future<List<OutboxEntry>> pending() =>
      (_db.select(_t)
            ..where((t) => t.state.equals(OutboxState.stuck).not())
            ..orderBy([
              (t) => OrderingTerm.asc(t.createdAt),
              (t) => OrderingTerm.asc(t.id),
            ]))
          .get();

  /// Entries to send at [now]: pending or failed, past `not_before` and
  /// `next_attempt_at`, oldest first. [includeStuck] also returns stuck ones.
  Future<List<OutboxEntry>> due(DateTime now, {bool includeStuck = false}) {
    final at = now.toUtc();
    return (_db.select(_t)
          ..where(
            (t) =>
                (t.state.isIn([
                  OutboxState.pending,
                  OutboxState.failed,
                  if (includeStuck) OutboxState.stuck,
                ])) &
                t.notBefore.isSmallerOrEqualValue(at) &
                (t.nextAttemptAt.isNull() |
                    t.nextAttemptAt.isSmallerOrEqualValue(at)),
          )
          ..orderBy([
            (t) => OrderingTerm.asc(t.createdAt),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
  }

  /// The earliest instant after [after] at which a waiting entry becomes due
  /// (max of `not_before` and `next_attempt_at`), or null. Stuck entries are
  /// ignored. The engine schedules a wake-up for it.
  Future<DateTime?> nextDueAfter(DateTime after) async {
    final rows =
        await (_db.select(_t)..where(
              (t) => t.state.isIn([OutboxState.pending, OutboxState.failed]),
            ))
            .get();
    DateTime? best;
    for (final e in rows) {
      var at = e.notBefore;
      final n = e.nextAttemptAt;
      if (n != null && n.isAfter(at)) at = n;
      if (!at.isAfter(after)) continue;
      if (best == null || at.isBefore(best)) best = at;
    }
    return best;
  }

  Future<void> markInflight(int id) => _set(id, state: OutboxState.inflight);

  /// Puts an entry back to waiting without counting an attempt (dependency
  /// not ready, or the cycle was aborted).
  Future<void> markPending(int id) => _set(id, state: OutboxState.pending);

  /// Transient failure: counts an attempt and schedules the retry.
  Future<void> markFailed(
    int id, {
    required String error,
    required DateTime nextAttemptAt,
  }) async {
    final e = await byId(id);
    if (e == null) return;
    await _set(
      id,
      state: OutboxState.failed,
      attempts: e.attempts + 1,
      nextAttemptAt: nextAttemptAt.toUtc(),
      lastError: error,
    );
  }

  /// Gave up automatic retries; kept in the queue.
  Future<void> markStuck(int id, {required String error}) async {
    final e = await byId(id);
    if (e == null) return;
    await _set(
      id,
      state: OutboxState.stuck,
      attempts: e.attempts + 1,
      lastError: error,
    );
  }

  /// Makes failed and stuck entries due immediately (manual sync / "retry").
  /// Resets the attempt counter of stuck ones.
  Future<void> retryNow({int? id}) async {
    await (_db.update(_t)..where(
          (t) =>
              t.state.isIn([OutboxState.failed, OutboxState.stuck]) &
              (id == null ? const Constant(true) : t.id.equals(id)),
        ))
        .write(
          const OutboxCompanion(
            state: Value(OutboxState.pending),
            attempts: Value(0),
            nextAttemptAt: Value(null),
          ),
        );
  }

  /// After a crash: entries left `inflight` go back to pending.
  Future<void> recoverInflight() =>
      (_db.update(_t)..where((t) => t.state.equals(OutboxState.inflight)))
          .write(const OutboxCompanion(state: Value(OutboxState.pending)));

  Future<void> _set(
    int id, {
    required String state,
    int? attempts,
    DateTime? nextAttemptAt,
    String? lastError,
  }) => (_db.update(_t)..where((t) => t.id.equals(id))).write(
    OutboxCompanion(
      state: Value(state),
      attempts: attempts == null ? const Value.absent() : Value(attempts),
      nextAttemptAt: state == OutboxState.failed
          ? Value(nextAttemptAt)
          : const Value(null),
      lastError: lastError == null ? const Value.absent() : Value(lastError),
    ),
  );

  Future<OutboxCounts> countsNow() async {
    final rows = await _db.select(_t).get();
    return _count(rows);
  }

  static OutboxCounts _count(List<OutboxEntry> rows) {
    var pending = 0, failed = 0, stuck = 0;
    for (final r in rows) {
      switch (r.state) {
        case OutboxState.failed:
          failed++;
        case OutboxState.stuck:
          stuck++;
        default:
          pending++;
      }
    }
    return OutboxCounts(pending: pending, failed: failed, stuck: stuck);
  }

  /// Live (pending, failed, stuck) counts.
  Stream<OutboxCounts> counts() =>
      _db.select(_t).watch().map(_count).distinct();

  /// Live list of all entries (for the sync screen).
  Stream<List<OutboxEntry>> watchAll() =>
      (_db.select(_t)..orderBy([
            (t) => OrderingTerm.asc(t.createdAt),
            (t) => OrderingTerm.asc(t.id),
          ]))
          .watch();
}
