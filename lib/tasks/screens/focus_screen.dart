import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../common/widgets/surface_card.dart';
import '../../core/design/tokens.dart';
import '../../l10n/l10n_ext.dart';
import '../domain/task.dart';
import '../providers/task_provider.dart';
import '../providers/today_provider.dart';
import '../widgets/postpone_sheet.dart';
import '../widgets/today_header.dart';

/// One task at a time from today's remaining tasks. Showing a task starts it
/// (status "in progress"). Keys: `focus.title`, `focus.done`, `focus.postpone`,
/// `focus.skip`, `focus.empty`.
class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  final Set<String> _skipped = {};
  String? _started;

  static String _key(Task t) => t.localId ?? t.uid.value;

  /// Tasks already in progress first, then today's order.
  List<Task> _queue(List<Task> remaining) {
    final inProgress = [
      for (final t in remaining)
        if (t.status == TaskStatus.inProgress) t,
    ];
    return [
      ...inProgress,
      for (final t in remaining)
        if (t.status != TaskStatus.inProgress) t,
    ];
  }

  void _start(Task task) {
    if (_started == _key(task)) return;
    _started = _key(task);
    if (task.status == TaskStatus.inProgress) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(taskActionsProvider).setStatus(task, TaskStatus.inProgress);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final remaining = ref
        .watch(todaySectionsProvider)
        .whenData((s) => _queue(s.remaining));
    final queue = remaining.value;

    Widget body;
    if (queue == null) {
      body = remaining.hasError
          ? Center(child: Text(l10n.todayErrorTitle))
          : const Center(child: CircularProgressIndicator());
    } else if (queue.isEmpty) {
      body = const _FocusEmpty();
    } else {
      var pool = [
        for (final t in queue)
          if (!_skipped.contains(_key(t))) t,
      ];
      if (pool.isEmpty) pool = queue; // skipped everything: start over
      final task = pool.first;
      _start(task);
      body = _FocusBody(
        task: task,
        index: queue.indexWhere((t) => _key(t) == _key(task)) + 1,
        total: queue.length,
        onSkip: () => setState(() {
          _skipped.add(_key(task));
          // Skipped the whole queue: go round again.
          if (queue.every((t) => _skipped.contains(_key(t)))) _skipped.clear();
        }),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.focusTitle)),
      body: SafeArea(child: body),
    );
  }
}

class _FocusBody extends ConsumerWidget {
  const _FocusBody({
    required this.task,
    required this.index,
    required this.total,
    required this.onSkip,
  });

  final Task task;
  final int index;
  final int total;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final subtasks = task.localId == null
        ? task.subtasks
        : ref.watch(taskSubtasksProvider(task.localId!)).value ?? task.subtasks;
    final actions = ref.read(taskActionsProvider);

    return ListView(
      padding: EdgeInsets.all(tokens.space6),
      children: [
        Text(
          l10n.focusPosition(index, total),
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: tokens.space6),
        Text(
          task.name,
          key: const Key('focus.title'),
          style: theme.textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        if (task.estimatedMinutes != null) ...[
          SizedBox(height: tokens.space2),
          Text(
            formatMinutes(context, task.estimatedMinutes!),
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
        if (task.note != null && task.note!.isNotEmpty) ...[
          SizedBox(height: tokens.space4),
          Text(task.note!, style: theme.textTheme.bodyLarge),
        ],
        if (subtasks.isNotEmpty) ...[
          SizedBox(height: tokens.space6),
          Text(l10n.focusSubtasks, style: theme.textTheme.titleSmall),
          SizedBox(height: tokens.space2),
          SurfaceCard(
            child: Column(
              children: [
                for (final s in subtasks)
                  CheckboxListTile(
                    key: ValueKey('focus.sub.${s.localId ?? s.uid.value}'),
                    value: s.isCompleted,
                    onChanged: (_) => actions.toggleComplete(s),
                    title: Text(
                      s.name,
                      style: s.isCompleted
                          ? const TextStyle(
                              decoration: TextDecoration.lineThrough,
                            )
                          : null,
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
              ],
            ),
          ),
        ],
        SizedBox(height: tokens.space8),
        FilledButton.icon(
          key: const Key('focus.done'),
          onPressed: () => actions.complete(task),
          icon: const Icon(Icons.check),
          label: Text(l10n.focusDone),
        ),
        SizedBox(height: tokens.space3),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: tokens.space3,
          runSpacing: tokens.space2,
          children: [
            OutlinedButton.icon(
              key: const Key('focus.postpone'),
              onPressed: () => showPostponeSheet(context, ref, [task]),
              icon: const Icon(Icons.event_repeat),
              label: Text(l10n.focusPostpone),
            ),
            OutlinedButton.icon(
              key: const Key('focus.skip'),
              onPressed: onSkip,
              icon: const Icon(Icons.skip_next),
              label: Text(l10n.focusSkip),
            ),
          ],
        ),
      ],
    );
  }
}

class _FocusEmpty extends StatelessWidget {
  const _FocusEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return Center(
      key: const Key('focus.empty'),
      child: Padding(
        padding: EdgeInsets.all(tokens.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.task_alt, size: 56, color: tokens.success),
            SizedBox(height: tokens.space3),
            Text(
              context.l10n.focusEmptyTitle,
              style: theme.textTheme.titleMedium,
            ),
            SizedBox(height: tokens.space1),
            Text(
              context.l10n.focusEmptyBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            SizedBox(height: tokens.space4),
            OutlinedButton(
              onPressed: () => context.canPop() ? context.pop() : null,
              child: Text(context.l10n.focusBack),
            ),
          ],
        ),
      ),
    );
  }
}
