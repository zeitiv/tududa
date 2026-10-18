import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/inbox_provider.dart';
import '../../l10n/strings.dart';

/// Inbox screen - items from Telegram and other sources.
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(inboxProvider);
    final list = async.value;
    final items = list?.items ?? const [];
    final notifier = ref.read(inboxProvider.notifier);
    final strings = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(strings.inbox)),
      body: list == null && async.isLoading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    strings.inboxEmpty,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    strings.inboxTelegramHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => notifier.refresh(),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  if (index >= items.length - 3) {
                    Future.microtask(notifier.loadMore);
                  }
                  final item = items[index];
                  return Dismissible(
                    key: ValueKey('${item.uid.value}:${item.status.name}'),
                    direction: DismissDirection.horizontal,
                    background: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 24),
                      color: Colors.green,
                      child: const Icon(Icons.check, color: Colors.white),
                    ),
                    secondaryBackground: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      color: theme.colorScheme.error,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (direction) {
                      if (direction == DismissDirection.startToEnd) {
                        notifier.process(item.uid);
                      } else {
                        notifier.ignore(item.uid);
                      }
                    },
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: item.isProcessed
                            ? Colors.green.withValues(alpha: 0.1)
                            : item.isIgnored
                            ? theme.colorScheme.surfaceContainerHighest
                            : theme.colorScheme.primaryContainer,
                        child: Icon(
                          item.isProcessed
                              ? Icons.check
                              : item.isIgnored
                              ? Icons.do_not_disturb
                              : Icons.mail_outline,
                          color: item.isProcessed
                              ? Colors.green
                              : item.isIgnored
                              ? theme.colorScheme.outline
                              : theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        item.content,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: item.createdAt != null
                          ? Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                DateFormat.yMMMd().add_jm().format(
                                  item.createdAt!,
                                ),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : null,
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) {
                          if (action == 'process') {
                            notifier.process(item.uid);
                          } else if (action == 'ignore') {
                            notifier.ignore(item.uid);
                          } else if (action == 'delete') {
                            notifier.delete(item.uid);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'process',
                            child: Text(strings.markProcessed),
                          ),
                          PopupMenuItem(
                            value: 'ignore',
                            child: Text(strings.ignore),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(strings.delete),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
