import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/patch.dart';
import '../../core/design/tokens.dart';
import '../../core/time/calendar_date.dart';
import '../../core/time/date_formatters.dart';
import '../../l10n/l10n_ext.dart';
import '../data/task_patch.dart';
import '../domain/task.dart';
import '../providers/task_provider.dart';
import '../providers/today_provider.dart';

/// Steps through today's remaining tasks one by one: Done / Tomorrow / Pick
/// date / Someday / Keep, then shows a summary. The list is taken when the
/// review opens, so finished tasks do not shift the position.
/// Keys: `review.done`, `review.tomorrow`, `review.pickDate`, `review.someday`,
/// `review.keep`, `review.progress`, `review.summary`, `review.close`.
class DailyReviewScreen extends ConsumerStatefulWidget {
  const DailyReviewScreen({super.key});

  @override
  ConsumerState<DailyReviewScreen> createState() => _DailyReviewScreenState();
}

class _DailyReviewScreenState extends ConsumerState<DailyReviewScreen> {
  List<Task>? _queue;
  int _index = 0;
  bool _busy = false;
  int _done = 0, _moved = 0, _someday = 0, _kept = 0;

  Future<void> _step(
    Future<bool> Function(Task) action,
    void Function() count,
  ) async {
    if (_busy) return;
    final task = _queue![_index];
    setState(() => _busy = true);
    final applied = await action(task);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (applied) {
        count();
        _index++;
      }
    });
  }

  Future<bool> _ok(Future<TaskResult<Object?>> f) async => (await f).ok;

  Future<void> _pickDate() async {
    final today = ref.read(taskDayProvider).date;
    final first = DateTime(today.year, today.month, today.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: first.add(const Duration(days: 1)),
      firstDate: first,
      lastDate: first.add(const Duration(days: 365 * 5)),
    );
    if (picked == null || !mounted) return;
    final to = CalendarDate.fromDateTime(picked);
    final actions = ref.read(taskActionsProvider);
    await _step((t) => _ok(actions.postpone(t, to)), () => _moved++);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(todaySectionsProvider);
    if (_queue == null && async.hasValue) _queue = async.value!.remaining;
    final queue = _queue;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reviewTitle)),
      body: SafeArea(
        child: queue == null
            ? (async.hasError
                  ? Center(child: Text(l10n.todayErrorTitle))
                  : const Center(child: CircularProgressIndicator()))
            : _index >= queue.length
            ? _Summary(
                total: queue.length,
                done: _done,
                moved: _moved,
                someday: _someday,
                kept: _kept,
              )
            : _page(context, queue),
      ),
    );
  }

  Widget _page(BuildContext context, List<Task> queue) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final task = queue[_index];
    final today = ref.read(taskDayProvider).date;
    final fmt = DateFormats(Localizations.localeOf(context));
    final actions = ref.read(taskActionsProvider);
    final due = task.dueDate;

    Widget button(
      String key,
      IconData icon,
      String label,
      VoidCallback onTap,
    ) => OutlinedButton.icon(
      key: Key(key),
      onPressed: _busy ? null : onTap,
      icon: Icon(icon),
      label: Text(label),
    );

    return ListView(
      padding: EdgeInsets.all(tokens.space6),
      children: [
        LinearProgressIndicator(
          value: _index / queue.length,
          borderRadius: BorderRadius.circular(tokens.radiusFull),
        ),
        SizedBox(height: tokens.space2),
        Text(
          l10n.reviewProgress(_index + 1, queue.length),
          key: const Key('review.progress'),
          style: theme.textTheme.labelLarge,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: tokens.space8),
        Text(
          task.name,
          key: const Key('review.title'),
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        if (due != null) ...[
          SizedBox(height: tokens.space2),
          Text(
            fmt.relativeDay(due, today, l10n),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: due.isBefore(today)
                  ? tokens.overdue
                  : theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        SizedBox(height: tokens.space8),
        FilledButton.icon(
          key: const Key('review.done'),
          onPressed: _busy
              ? null
              : () => _step((t) => _ok(actions.complete(t)), () => _done++),
          icon: const Icon(Icons.check),
          label: Text(l10n.reviewDone),
        ),
        SizedBox(height: tokens.space3),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: tokens.space3,
          runSpacing: tokens.space2,
          children: [
            button(
              'review.tomorrow',
              Icons.wb_sunny_outlined,
              l10n.reviewTomorrow,
              () => _step(
                (t) => _ok(actions.postpone(t, today.addDays(1))),
                () => _moved++,
              ),
            ),
            button(
              'review.pickDate',
              Icons.event,
              l10n.reviewPickDate,
              _pickDate,
            ),
            button(
              'review.someday',
              Icons.all_inbox_outlined,
              l10n.reviewSomeday,
              () => _step(
                (t) => _ok(
                  actions.update(
                    t.uid,
                    TaskPatch(
                      dueDate: const Patch.clear(),
                      dueTime: const Patch.clear(),
                      // Plan statuses would keep it on Today.
                      status: t.status == TaskStatus.notStarted
                          ? const Patch.unset()
                          : const Patch.set(TaskStatus.notStarted),
                    ),
                  ),
                ),
                () => _someday++,
              ),
            ),
            button(
              'review.keep',
              Icons.push_pin_outlined,
              l10n.reviewKeep,
              () => _step((_) async => true, () => _kept++),
            ),
          ],
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.total,
    required this.done,
    required this.moved,
    required this.someday,
    required this.kept,
  });

  final int total, done, moved, someday, kept;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final lines = [
      if (done > 0) l10n.reviewSummaryDone(done),
      if (moved > 0) l10n.reviewSummaryMoved(moved),
      if (someday > 0) l10n.reviewSummarySomeday(someday),
      if (kept > 0) l10n.reviewSummaryKept(kept),
    ];
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.space6),
        child: Column(
          key: const Key('review.summary'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.task_alt, size: 56, color: tokens.success),
            SizedBox(height: tokens.space3),
            Text(
              total == 0 ? l10n.reviewSummaryEmpty : l10n.reviewSummaryTitle,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: tokens.space3),
            for (final line in lines)
              Text(
                line,
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            SizedBox(height: tokens.space6),
            FilledButton(
              key: const Key('review.close'),
              onPressed: () => context.canPop() ? context.pop() : null,
              child: Text(l10n.reviewClose),
            ),
          ],
        ),
      ),
    );
  }
}
