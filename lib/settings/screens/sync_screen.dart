import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/merge.dart';
import '../../core/sync/sync_actions.dart';
import '../../core/sync/sync_status.dart';
import '../../l10n/l10n_ext.dart';

/// Live outbox contents.
final outboxEntriesProvider = StreamProvider.autoDispose<List<OutboxEntry>>(
  (ref) => ref.watch(appDatabaseProvider).outboxDao.watchAll(),
);

/// "5 minutes ago" style text; 'never' when [t] is null.
String relativeSyncTime(AppLocalizations l, DateTime? t, {DateTime? now}) {
  if (t == null) return l.syncTimeNever;
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inSeconds < 60) return l.syncTimeJustNow;
  if (d.inMinutes < 60) return l.syncTimeMinutesAgo(d.inMinutes);
  if (d.inHours < 24) return l.syncTimeHoursAgo(d.inHours);
  return l.syncTimeDaysAgo(d.inDays);
}

String _phaseLabel(AppLocalizations l, SyncPhase p) => switch (p) {
  SyncPhase.idle => l.syncPhaseIdle,
  SyncPhase.syncing => l.syncPhaseSyncing,
  SyncPhase.offline => l.syncPhaseOffline,
  SyncPhase.error => l.syncPhaseError,
  SyncPhase.signedOut => l.syncPhaseSignedOut,
};

String _entryState(AppLocalizations l, String state) => switch (state) {
  'failed' => l.syncEntryFailed,
  'stuck' => l.syncEntryStuck,
  'inflight' => l.syncEntrySending,
  _ => l.syncEntryPending,
};

String _title(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');

/// Sync status, queued changes and conflict notices.
class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final status = ref.watch(syncStatusProvider);
    final entries = ref.watch(outboxEntriesProvider);
    final actions = ref.read(syncActionsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.syncTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_phaseLabel(l, status.phase), style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            l.syncLastSynced(relativeSyncTime(l, status.lastSyncAt)),
            style: theme.textTheme.bodyMedium,
          ),
          if (status.lastError != null) ...[
            const SizedBox(height: 4),
            Text(
              status.lastError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: status.phase == SyncPhase.syncing
                    ? null
                    : actions.syncNow,
                icon: const Icon(Icons.sync),
                label: Text(l.syncNow),
              ),
              OutlinedButton(
                onPressed: actions.retryAll,
                child: Text(l.syncRetryAll),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(l.syncQueuedChanges, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          entries.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Text(
              l.syncLoadError('$e'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
            data: (list) => list.isEmpty
                ? Text(l.syncNothingQueued)
                : Column(
                    children: [
                      for (final e in list)
                        _EntryTile(key: ValueKey(e.id), entry: e),
                    ],
                  ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  l.syncRecentConflicts,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (status.notices.isNotEmpty)
                TextButton(
                  onPressed: actions.dismissNotices,
                  child: Text(l.syncDismiss),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (status.notices.isEmpty)
            Text(l.syncNoConflicts)
          else
            for (final n in status.notices.reversed) _NoticeTile(notice: n),
        ],
      ),
    );
  }
}

class _EntryTile extends ConsumerWidget {
  const _EntryTile({super.key, required this.entry});

  final OutboxEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final actions = ref.read(syncActionsProvider);
    final bad = entry.state == 'failed' || entry.state == 'stuck';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_title(entry.entity)}: ${_title(entry.op)}',
              style: theme.textTheme.titleSmall,
            ),
            Text(
              l.syncEntryLine(_entryState(l, entry.state), entry.attempts),
              style: theme.textTheme.bodySmall?.copyWith(
                color: bad ? theme.colorScheme.error : null,
              ),
            ),
            if (entry.lastError != null)
              Text(entry.lastError!, style: theme.textTheme.bodySmall),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => actions.retry(entry.id),
                  child: Text(l.syncRetry),
                ),
                TextButton(
                  onPressed: () => _confirmDiscard(context, actions),
                  child: Text(l.syncDiscard),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDiscard(
    BuildContext context,
    SyncActions actions,
  ) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.syncDiscardTitle),
        content: Text(l.syncDiscardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.syncCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.syncDiscard),
          ),
        ],
      ),
    );
    if (ok ?? false) await actions.discard(entry);
  }
}

class _NoticeTile extends StatelessWidget {
  const _NoticeTile({required this.notice});

  final ConflictNotice notice;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final what = notice.field == '*' ? l.syncNoticeWholeChange : notice.field;
    final kept = notice.winner == ConflictWinner.server
        ? l.syncNoticeServerKept
        : l.syncNoticeLocalKept;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.merge_type),
      title: Text(l.syncNoticeLine(_title(notice.entity), what, kept)),
      subtitle: notice.message == null ? null : Text(notice.message!),
    );
  }
}
