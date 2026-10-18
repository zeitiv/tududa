import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/session/session_providers.dart';
import '../api/api_error.dart';
import '../api/api_providers.dart';
import '../db/app_database.dart';
import 'sync_engine.dart';
import 'sync_handler.dart';
import 'sync_handlers.dart';

/// User-initiated sync operations behind the sync UI.
class SyncActions {
  SyncActions(this._ref);

  final Ref _ref;

  SyncEngine get _engine => _ref.read(syncEngineProvider);
  AppDatabase get _db => _ref.read(appDatabaseProvider);

  /// "Sync now": a manual cycle (ignores offline, retries failed/stuck).
  Future<void> syncNow() => _engine.requestSync(SyncReason.manual);

  /// Makes entry [entryId] due again and runs a cycle.
  Future<void> retry(int entryId) async {
    await _db.outboxDao.retryNow(id: entryId);
    await _engine.requestSync(SyncReason.manual);
  }

  /// Makes every failed/stuck entry due again and runs a cycle.
  Future<void> retryAll() async {
    await _db.outboxDao.retryNow();
    await _engine.requestSync(SyncReason.manual);
  }

  /// Gives up on [e]: the handler restores the row as if the server had
  /// rejected the change, then the entry is removed.
  ///
  /// The rollback's conflict notice is published on the engine so it shows up
  /// on the sync screen.
  Future<void> discard(OutboxEntry e) async {
    final handlers = _ref.read(syncHandlersProvider);
    final handler = handlers.where((h) => h.entity == e.entity).firstOrNull;
    if (handler != null) {
      final ctx = SyncContext(
        db: _db,
        dio: () => _ref.read(dioProvider),
        clock: _ref.read(userClockProvider),
        now: DateTime.now().toUtc(),
        ref: _ref,
        reason: SyncReason.manual,
        onNotice: _engine.addNotice,
      );
      await handler.rollback(
        ctx,
        e,
        const ValidationError('Discarded by user'),
      );
    }
    await _db.outboxDao.remove(e.id);
  }

  /// Clears the conflict notices.
  void dismissNotices() => _engine.dismissNotices();
}

final syncActionsProvider = Provider<SyncActions>(SyncActions.new);
