import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/merge.dart';
import '../../core/sync/sync_actions.dart';
import '../../core/sync/sync_status.dart';

/// Live outbox contents.
final outboxEntriesProvider = StreamProvider.autoDispose<List<OutboxEntry>>(
  (ref) => ref.watch(appDatabaseProvider).outboxDao.watchAll(),
);

/// "5 minutes ago" style text; 'never' when [t] is null.
String relativeSyncTime(DateTime? t, {DateTime? now}) {
  if (t == null) return 'never';
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) {
    return '${d.inMinutes} ${d.inMinutes == 1 ? 'minute' : 'minutes'} ago';
  }
  if (d.inHours < 24) {
    return '${d.inHours} ${d.inHours == 1 ? 'hour' : 'hours'} ago';
  }
  return '${d.inDays} ${d.inDays == 1 ? 'day' : 'days'} ago';
}

String _phaseLabel(SyncPhase p) => switch (p) {
  SyncPhase.idle => 'Up to date',
  SyncPhase.syncing => 'Syncing',
  SyncPhase.offline => 'Offline',
  SyncPhase.error => 'Sync problem',
  SyncPhase.signedOut => 'Signed out',
};

String _entryState(String state) => switch (state) {
  'failed' => 'Failed, will retry',
  'stuck' => 'Stuck',
  'inflight' => 'Sending',
  _ => 'Pending',
};

String _title(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');

/// Sync status, queued changes and conflict notices.
class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final status = ref.watch(syncStatusProvider);
    final entries = ref.watch(outboxEntriesProvider);
    final actions = ref.read(syncActionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sync')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_phaseLabel(status.phase), style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Last synced ${relativeSyncTime(status.lastSyncAt)}',
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
                label: const Text('Sync now'),
              ),
              OutlinedButton(
                onPressed: actions.retryAll,
                child: const Text('Retry all'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Queued changes', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          entries.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Text(
              'Could not load queued changes: $e',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            data: (list) => list.isEmpty
                ? const Text('Nothing queued. All changes are synced.')
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
                  'Recent conflicts',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (status.notices.isNotEmpty)
                TextButton(
                  onPressed: actions.dismissNotices,
                  child: const Text('Dismiss'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (status.notices.isEmpty)
            const Text('No conflicts to review.')
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
              '${_entryState(entry.state)} - '
              '${entry.attempts} ${entry.attempts == 1 ? 'attempt' : 'attempts'}',
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
                  child: const Text('Retry'),
                ),
                TextButton(
                  onPressed: () => _confirmDiscard(context, actions),
                  child: const Text('Discard'),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard this change?'),
        content: const Text(
          'The change will be undone on this device and never sent to the '
          'server.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
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
    final what = notice.field == '*' ? 'change' : notice.field;
    final kept = notice.winner == ConflictWinner.server
        ? 'server version kept'
        : 'your version kept';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.merge_type),
      title: Text('${_title(notice.entity)}: $what - $kept'),
      subtitle: notice.message == null ? null : Text(notice.message!),
    );
  }
}
