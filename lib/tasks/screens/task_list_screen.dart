import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/widgets/async_states.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/sync/sync_handler.dart' show SyncReason;
import '../../core/time/calendar_date.dart';
import '../../core/time/date_formatters.dart';
import '../../l10n/l10n_ext.dart';
import '../domain/task.dart';
import '../providers/task_provider.dart';
import '../quick_add/inline_add_row.dart';
import '../widgets/api_error_message.dart';
import '../widgets/bulk_action_bar.dart';
import '../widgets/task_tile.dart';

/// Which smart list a [TaskListScreen] shows.
enum TaskListView { upcoming, overdue, someday, completed }

/// Tasks of one day (null: no date) in the Upcoming list.
class TaskDayGroup {
  const TaskDayGroup(this.day, this.tasks);

  final CalendarDate? day;
  final List<Task> tasks;
}

/// Groups [tasks] by due day (or the day they are deferred to), earliest
/// first; tasks with neither (recurring templates) go last. Order inside a
/// day is kept.
List<TaskDayGroup> groupTasksByDay(Iterable<Task> tasks) {
  final byDay = <CalendarDate?, List<Task>>{};
  for (final t in tasks) {
    final defer = t.deferUntil;
    final day =
        t.dueDate ??
        (defer == null ? null : CalendarDate.fromDateTime(defer.toLocal()));
    byDay.putIfAbsent(day, () => []).add(t);
  }
  final days = byDay.keys.whereType<CalendarDate>().toList()..sort();
  return [
    for (final d in days) TaskDayGroup(d, byDay[d]!),
    if (byDay.containsKey(null)) TaskDayGroup(null, byDay[null]!),
  ];
}

/// How many completed tasks show before "Load more".
const completedPageSize = 30;

/// Smart-list screen: Upcoming (grouped by day), Overdue, Someday and
/// Completed. All of them read the local database; pull-to-refresh runs a
/// sync cycle, which merges server changes without touching local edits.
class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key, required this.view});

  final TaskListView view;

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  // The repository returns the whole (30 day) completed list from the local
  // database in one query; paging is done here over that list.
  int _completedShown = completedPageSize;
  bool _rescheduling = false;

  TaskView get _taskView => switch (widget.view) {
    TaskListView.upcoming => TaskView.upcoming,
    TaskListView.overdue => TaskView.overdue,
    TaskListView.someday => TaskView.someday,
    TaskListView.completed => TaskView.completed,
  };

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _refresh() async {
    try {
      await ref.read(syncEngineProvider).requestSync(SyncReason.manual);
    } catch (e) {
      if (mounted) _snack(apiErrorMessage(context.l10n, e));
    }
  }

  Future<void> _rescheduleAll(List<Task> tasks) async {
    final l = context.l10n;
    final today = ref.read(taskDayProvider).date;
    final actions = ref.read(taskActionsProvider);
    setState(() => _rescheduling = true);
    var moved = 0;
    Object? failure;
    for (final t in tasks) {
      final r = await actions.postpone(t, today);
      if (r.ok) {
        moved++;
      } else {
        failure = r.error;
      }
    }
    if (!mounted) return;
    setState(() => _rescheduling = false);
    _snack(
      failure != null ? apiErrorMessage(l, failure) : l.listRescheduled(moved),
    );
  }

  String _title() {
    final l = context.l10n;
    return switch (widget.view) {
      TaskListView.upcoming => l.navUpcoming,
      TaskListView.overdue => l.listOverdue,
      TaskListView.someday => l.taskFilterSomeday,
      TaskListView.completed => l.taskFilterCompleted,
    };
  }

  (IconData, String, String) _empty() {
    final l = context.l10n;
    return switch (widget.view) {
      TaskListView.upcoming => (
        Icons.upcoming_outlined,
        l.listEmptyUpcomingTitle,
        l.listEmptyUpcomingHint,
      ),
      TaskListView.overdue => (
        Icons.check_circle_outline,
        l.listEmptyOverdueTitle,
        l.listEmptyOverdueHint,
      ),
      TaskListView.someday => (
        Icons.cloud_outlined,
        l.listEmptySomedayTitle,
        l.listEmptySomedayHint,
      ),
      TaskListView.completed => (
        Icons.task_alt_outlined,
        l.listEmptyCompletedTitle,
        l.listEmptyCompletedHint,
      ),
    };
  }

  List<Task> _prepare(List<Task> tasks) {
    if (widget.view != TaskListView.completed) return tasks;
    final sorted = List<Task>.of(tasks)
      ..sort((a, b) {
        final x = a.completedAt ?? a.updatedAt;
        final y = b.completedAt ?? b.updatedAt;
        if (x == null && y == null) return 0;
        if (x == null) return 1;
        if (y == null) return -1;
        return y.compareTo(x);
      });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(taskViewListProvider(_taskView));
    final (icon, emptyTitle, emptyHint) = _empty();
    return Scaffold(
      appBar: AppBar(title: Text(_title())),
      bottomNavigationBar: const BulkActionBar(),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: AsyncStateView<List<Task>>(
          value: async,
          emptyIcon: icon,
          emptyTitle: emptyTitle,
          emptyHint: emptyHint,
          onRetry: () => ref.invalidate(taskViewListProvider(_taskView)),
          data: (tasks) => _buildList(context, _prepare(tasks)),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<Task> tasks) {
    final l = context.l10n;
    final children = <Widget>[];

    switch (widget.view) {
      case TaskListView.upcoming:
        final today = ref.watch(taskDayProvider).date;
        final fmt = DateFormats(Localizations.localeOf(context));
        for (final g in groupTasksByDay(tasks)) {
          children.add(
            _DayHeader(
              key: ValueKey('day-${g.day?.toIso() ?? 'none'}'),
              title: g.day == null
                  ? l.listNoDate
                  : today.daysUntil(g.day!) <= 1
                  ? fmt.relativeDay(g.day!, today, l)
                  : fmt.weekdayName(g.day!.weekday, style: WeekdayStyle.long),
              subtitle: g.day == null ? null : fmt.mediumDate(g.day!),
            ),
          );
          children.addAll([for (final t in g.tasks) _tile(t)]);
        }
        children.add(InlineAddRow(defaultDue: today.addDays(1)));
      case TaskListView.overdue:
        children.add(
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextButton.icon(
                key: const ValueKey('reschedule-all'),
                onPressed: _rescheduling ? null : () => _rescheduleAll(tasks),
                icon: const Icon(Icons.event_repeat_outlined),
                label: Text(l.listRescheduleAll),
              ),
            ),
          ),
        );
        children.addAll([for (final t in tasks) _tile(t)]);
      case TaskListView.someday:
        children.addAll([for (final t in tasks) _tile(t)]);
        children.add(const InlineAddRow());
      case TaskListView.completed:
        final shown = tasks.take(_completedShown).toList();
        children.addAll([for (final t in shown) _tile(t)]);
        if (shown.length < tasks.length) {
          children.add(
            Padding(
              padding: const EdgeInsets.all(8),
              child: Center(
                child: TextButton(
                  key: const ValueKey('load-more'),
                  onPressed: () =>
                      setState(() => _completedShown += completedPageSize),
                  child: Text(l.listLoadMore),
                ),
              ),
            ),
          );
        }
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 96),
      children: children,
    );
  }

  Widget _tile(Task t) =>
      TaskTile(key: ValueKey('task-${t.uid.value}'), task: t);
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Container(
        color: theme.colorScheme.surface,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
