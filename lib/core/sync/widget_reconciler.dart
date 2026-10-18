// ignore_for_file: prefer_initializing_formals -- named params cannot be private.
import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/session/session_controller.dart';
import '../../tasks/data/remote_task_repository.dart';
import '../../tasks/data/task_dao.dart';
import '../../tasks/data/task_fields.dart';
import '../../tasks/domain/task.dart' show TaskStatus;
import '../api/api_error.dart';
import '../db/app_database.dart';
import '../db/dirty_fields.dart';
import '../ids.dart';
import '../platform/widget_bridge.dart';
import 'sync_engine.dart';
import 'sync_handler.dart';

/// Brings completions made on the home-screen widget into the local store.
///
/// The widget's change log only holds changes the server already confirmed,
/// so each one is applied like a pulled server change: the task is marked in
/// Drift WITHOUT an outbox entry (nothing to send), the task's `base_json`
/// moves with it so a later pull does not see a conflict, and fields the user
/// edited locally stay dirty and merge on the next sync. A local edit of the
/// status itself wins (it is still queued and will be sent).
///
/// Then the tasks are refetched ([refetch]) and the log is acknowledged up to
/// the last applied sequence. Unknown uids are ignored, and running again
/// with the same log is a no-op, so triggers may overlap freely.
class WidgetReconciler with WidgetsBindingObserver {
  WidgetReconciler({
    required this.db,
    required this.bridge,
    required this.refetch,
    this.canRun,
    DateTime Function()? now,
    WidgetsBinding? binding,
  }) : _now = now ?? (() => DateTime.now().toUtc()),
       _binding = binding;

  final AppDatabase db;
  final WidgetBridge bridge;

  /// Fetches the changed tasks from the server (and lets the sync engine pull
  /// them). Errors are swallowed: the data is already applied locally.
  final Future<void> Function(List<String> uids) refetch;

  /// Gate (e.g. signed in); reconcile does nothing while it returns false.
  final bool Function()? canRun;
  final DateTime Function() _now;
  final WidgetsBinding? _binding;

  StreamSubscription<int>? _sub;
  Future<int>? _running;
  bool _again = false;
  bool _started = false;
  bool _disposed = false;

  /// Reconciles now and on every resume / event-channel message.
  void start() {
    if (_started || _disposed) return;
    _started = true;
    _binding?.addObserver(this);
    _sub = bridge.changes.listen(
      (_) => unawaited(reconcile()),
      onError: (Object _) {},
    );
    unawaited(reconcile());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(reconcile());
  }

  void dispose() {
    _disposed = true;
    _binding?.removeObserver(this);
    unawaited(_sub?.cancel());
    _sub = null;
  }

  /// Applies the widget's pending changes; returns how many log entries were
  /// processed. Overlapping calls share one run plus one follow-up.
  Future<int> reconcile() {
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    return _running = _loop().whenComplete(() => _running = null);
  }

  Future<int> _loop() async {
    var total = 0;
    do {
      _again = false;
      try {
        total += await _once();
      } catch (e) {
        if (kDebugMode) debugPrint('widget reconcile failed: ${e.runtimeType}');
        break;
      }
    } while (_again && !_disposed);
    return total;
  }

  Future<int> _once() async {
    if (_disposed || !(canRun?.call() ?? true)) return 0;
    // Always from 0: acknowledged entries are gone, and a sequence restart
    // (account switch) must not hide new ones.
    final changes = await bridge.pendingChanges(0);
    if (changes.isEmpty) return 0;
    changes.sort((a, b) => a.seq.compareTo(b.seq));

    // The newest change per task wins.
    final latest = <String, WidgetChange>{};
    for (final c in changes) {
      latest[c.uid] = c;
    }
    final touched = <String>[];
    for (final c in latest.values) {
      if (await _apply(c)) touched.add(c.uid);
    }
    final lastSeq = changes.last.seq;
    // Applied (or ignored): the log entries are done with. A failed refetch
    // is fine, the next sync pulls the tasks anyway.
    if (touched.isNotEmpty) {
      try {
        await refetch(touched);
      } catch (_) {}
    }
    await bridge.ack(lastSeq);
    return changes.length;
  }

  /// True when the task exists locally (so it should be refetched).
  Future<bool> _apply(WidgetChange c) => db.transaction(() async {
    final dao = TaskDao(db);
    final row = await dao.byUid(c.uid);
    if (row == null || row.pendingDelete) return false;

    final dirty = DirtyFields.decode(row.dirtyFields);
    // A queued local status edit wins; the engine sends it later.
    if (dirty.isDirty(TaskField.status) || row.status == c.status) return true;

    final status = TaskStatus.fromCode(c.status);
    final at = c.atMillis > 0
        ? DateTime.fromMillisecondsSinceEpoch(c.atMillis, isUtc: true)
        : _now();
    final completedAt = status.isFinished ? at : null;

    final base = BaseJson.decode(row.baseJson);
    String? newBase;
    if (base != null) {
      base[TaskField.status] = c.status;
      base[TaskField.completedAt] = isoSeconds(completedAt);
      newBase = BaseJson.encode(base);
    }

    final wasFinished = TaskStatus.fromCode(row.status).isFinished;
    await dao.updateRow(
      row.localId,
      TasksCompanion(
        status: Value(c.status),
        completedAt: Value(completedAt),
        statusBeforeDone: status.isFinished && !wasFinished
            ? Value(row.status)
            : status.isFinished
            ? const Value.absent()
            : const Value(null),
        baseJson: newBase == null ? const Value.absent() : Value(newBase),
        localUpdatedAt: Value(_now()),
      ),
    );
    return true;
  });
}

/// The app's reconciler, wired to the live providers. Watch it once at the
/// app root (next to `syncTriggersProvider`) so it runs for the session.
final widgetReconcilerProvider = Provider<WidgetReconciler>((ref) {
  final r = WidgetReconciler(
    db: ref.watch(appDatabaseProvider),
    bridge: ref.watch(widgetBridgeProvider),
    canRun: () => ref.read(sessionControllerProvider) is SessionSignedIn,
    refetch: (uids) async {
      final remote = ref.read(remoteTaskRepositoryProvider);
      for (final uid in uids) {
        try {
          await remote.get(TaskUid(uid));
        } on ApiError {
          // Offline or gone: the sync pull sorts it out.
        }
      }
      unawaited(ref.read(syncEngineProvider).requestSync(SyncReason.resume));
    },
    binding: WidgetsBinding.instance,
  )..start();
  ref.listen<SessionState>(sessionControllerProvider, (prev, next) {
    if (next is SessionSignedIn) unawaited(r.reconcile());
  });
  ref.onDispose(r.dispose);
  return r;
});
