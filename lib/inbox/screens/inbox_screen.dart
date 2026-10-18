import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/tokens.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/sync/sync_handler.dart' show SyncReason;
import '../../l10n/l10n_ext.dart';
import '../../notes/domain/note.dart';
import '../../notes/providers/note_provider.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/providers/task_provider.dart';
import '../../tasks/quick_add/quick_add_sheet.dart' show QuickAddSheet;
import '../../tasks/widgets/api_error_message.dart';
import '../../tasks/widgets/task_tile.dart';
import '../domain/inbox_item.dart';
import '../providers/inbox_provider.dart';
import '../widgets/inbox_capture_field.dart';
import '../widgets/inbox_item_card.dart';
import '../widgets/inbox_states.dart';

/// Tasks that still need a home: no project and no due date.
List<Task> unsortedTasks(Iterable<Task> tasks) => [
  for (final t in tasks)
    if (t.projectUid == null &&
        t.projectName == null &&
        t.dueDate == null &&
        !t.isCompleted)
      t,
];

/// The quick-add sheet prefilled with [text]; the created task, if any.
Future<Task?> openQuickAddForText(BuildContext context, String text) async {
  final router = GoRouter.maybeOf(context);
  Task? saved;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => QuickAddSheet(
      initialText: text,
      onSaved: (task) => saved = task,
      onMoreOptions: router == null ? null : (_) => router.push('/tasks/new'),
    ),
  );
  return saved;
}

/// Inbox screen: capture field, inbox items as cards, and the tasks that have
/// no project or date yet.
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key, this.openQuickAdd = openQuickAddForText});

  /// Opens quick add prefilled with the item's text; resolves to the task it
  /// created, or null when the user closed it without saving.
  final Future<Task?> Function(BuildContext context, String text) openQuickAdd;

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  /// Items swiped away whose undo window is still open. They are committed
  /// (processed / deleted) when the snackbar closes for any reason but undo.
  final _hidden = <String>{};

  Future<void> _removeWithUndo(InboxItem item, {required bool delete}) async {
    final notifier = ref.read(inboxProvider.notifier);
    final strings = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _hidden.add(item.uid.value));
    messenger.hideCurrentSnackBar();
    final reason = await messenger
        .showSnackBar(
          SnackBar(
            persist: false,
            content: Text(
              delete ? strings.inboxV2Deleted : strings.inboxV2MarkedProcessed,
            ),
            action: SnackBarAction(
              label: strings.inboxV2Undo,
              onPressed: () {},
            ),
          ),
        )
        .closed;
    if (reason == SnackBarClosedReason.action) {
      if (mounted) setState(() => _hidden.remove(item.uid.value));
      return;
    }
    if (delete) {
      await notifier.delete(item.uid);
    } else {
      await notifier.process(item.uid);
    }
    if (mounted) setState(() => _hidden.remove(item.uid.value));
  }

  Future<void> _convertToTask(InboxItem item) async {
    final notifier = ref.read(inboxProvider.notifier);
    final task = await widget.openQuickAdd(context, item.content);
    // Closing the sheet without saving keeps the item in the inbox.
    if (task == null) return;
    await notifier.process(item.uid, target: ProcessedAsTask(task.uid.value));
  }

  Future<void> _convertToNote(InboxItem item) async {
    final notifier = ref.read(inboxProvider.notifier);
    final strings = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.maybeOf(context);
    final Note note;
    try {
      note = await ref
          .read(noteListProvider.notifier)
          .create(NoteDraft(content: item.content));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(strings.noteSaveFailed)));
      return;
    }
    final target = note.uid?.value ?? note.localId?.value;
    await notifier.process(
      item.uid,
      target: target == null ? null : ProcessedAsNote(target),
    );
    final routeId = note.routeId;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        persist: false,
        content: Text(strings.inboxV2SavedAsNote),
        action: router == null || routeId == null
            ? null
            : SnackBarAction(
                label: strings.inboxV2OpenNote,
                onPressed: () =>
                    router.push('/notes/${Uri.encodeComponent(routeId)}'),
              ),
      ),
    );
  }

  void _onAction(InboxItem item, InboxItemAction action) {
    switch (action) {
      case InboxItemAction.process:
        _removeWithUndo(item, delete: false);
      case InboxItemAction.ignore:
        ref.read(inboxProvider.notifier).ignore(item.uid);
      case InboxItemAction.delete:
        _removeWithUndo(item, delete: true);
    }
  }

  Widget _dismissBackground(
    BuildContext context, {
    required bool start,
    required Color color,
    required Color onColor,
    required IconData icon,
  }) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
    ),
    alignment: start ? Alignment.centerLeft : Alignment.centerRight,
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Icon(icon, color: onColor),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<AppTokens>();
    final async = ref.watch(inboxProvider);
    final notifier = ref.read(inboxProvider.notifier);
    final strings = context.l10n;
    final items = [
      for (final i in async.value?.items ?? const <InboxItem>[])
        if (!_hidden.contains(i.uid.value)) i,
    ];
    final unsorted = unsortedTasks(
      ref.watch(taskViewListProvider(TaskView.all)).value ?? const <Task>[],
    );
    final loading = !async.hasValue && async.isLoading;
    final failed = !async.hasValue && async.hasError;

    return Scaffold(
      appBar: AppBar(title: Text(strings.navInbox)),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(syncEngineProvider).requestSync(SyncReason.manual),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: InboxCaptureField()),
            if (loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (failed)
              SliverToBoxAdapter(
                child: InboxErrorState(
                  message: apiErrorMessage(strings, async.error!),
                  onRetry: () => ref.invalidate(inboxProvider),
                ),
              )
            else if (items.isEmpty)
              const SliverToBoxAdapter(child: InboxEmptyState())
            else
              SliverList.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  if (index >= items.length - 3) {
                    Future.microtask(notifier.loadMore);
                  }
                  final item = items[index];
                  return Dismissible(
                    key: ValueKey('${item.uid.value}:${item.status.name}'),
                    background: _dismissBackground(
                      context,
                      start: true,
                      color: tokens?.success ?? scheme.primary,
                      onColor: scheme.surface,
                      icon: Icons.check_rounded,
                    ),
                    secondaryBackground: _dismissBackground(
                      context,
                      start: false,
                      color: scheme.error,
                      onColor: scheme.onError,
                      icon: Icons.delete_outline,
                    ),
                    onDismissed: (direction) => _removeWithUndo(
                      item,
                      delete: direction == DismissDirection.endToStart,
                    ),
                    child: InboxItemCard(
                      item: item,
                      onConvertToTask: () => _convertToTask(item),
                      onConvertToNote: () => _convertToNote(item),
                      onAction: (a) => _onAction(item, a),
                    ),
                  );
                },
              ),
            if (unsorted.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: InboxSectionHeader(
                  title: strings.inboxV2UnsortedTasks,
                  hint: strings.inboxV2UnsortedHint,
                ),
              ),
              SliverList.builder(
                itemCount: unsorted.length,
                itemBuilder: (context, i) => TaskTile(
                  task: unsorted[i],
                  showProject: false,
                  showDueDate: false,
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }
}
