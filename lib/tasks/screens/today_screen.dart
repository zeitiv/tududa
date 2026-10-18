import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;

import '../../search/command_palette/command_palette.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../common/widgets/surface_card.dart';
import '../../core/design/tokens.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/sync/sync_handler.dart';
import '../../l10n/l10n_ext.dart';
import '../domain/task.dart';
import '../providers/task_provider.dart';
import '../providers/today_provider.dart';
import '../widgets/postpone_sheet.dart';
import '../widgets/task_tile.dart';
import '../widgets/today_header.dart';

/// Today tab: progress, then the day's tasks by part of the day.
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  /// Section ids the user collapsed; "completed" starts collapsed.
  final Set<String> _collapsed = {'completed'};

  void _toggle(String id) => setState(
    () => _collapsed.contains(id) ? _collapsed.remove(id) : _collapsed.add(id),
  );

  // Pull-to-refresh: a sync cycle merges, never overwrites, local edits.
  Future<void> _refresh() =>
      ref.read(syncEngineProvider).requestSync(SyncReason.manual);

  void _retry() {
    for (final v in [
      TaskView.overdue,
      TaskView.dueToday,
      TaskView.todayPlan,
      TaskView.completedToday,
    ]) {
      ref.invalidate(taskViewListProvider(v));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(todaySectionsProvider);
    final sections = async.value;
    final today = ref.watch(taskDayProvider).date;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.todayTitle),
        actions: [
          IconButton(
            key: const Key('today.focus'),
            icon: const Icon(Icons.center_focus_strong_outlined),
            tooltip: l10n.todayFocus,
            onPressed: () => context.push('/today/focus'),
          ),
          IconButton(
            key: const Key('today.review'),
            icon: const Icon(Icons.fact_check_outlined),
            tooltip: l10n.todayReview,
            onPressed: () => context.push('/today/review'),
          ),
          // Tap: global search. Long-press: command palette.
          // The gesture is invisible to screen readers: they get the palette
          // as a custom action on the button instead.
          Semantics(
            customSemanticsActions: {
              CustomSemanticsAction(label: l10n.paletteTitle): () =>
                  showCommandPalette(context),
            },
            child: GestureDetector(
              excludeFromSemantics: true,
              onLongPress: () => showCommandPalette(context),
              child: IconButton(
                key: const Key('today.search'),
                icon: const Icon(Icons.search),
                tooltip: l10n.searchTitle,
                onPressed: () => context.push('/search'),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: switch (async) {
          AsyncError(:final error) when sections == null => _scrollable([
            _TodayError(error: error, onRetry: _retry),
          ]),
          _ when sections == null => _scrollable([const _TodaySkeleton()]),
          _ => _scrollable([
            TodayHeader(sections: sections, date: today),
            if (sections.isEmpty) const _TodayEmpty(),
            ..._sections(context, sections),
          ]),
        },
      ),
    );
  }

  List<Widget> _sections(BuildContext context, TodaySections s) {
    final l10n = context.l10n;
    Widget section(
      String id,
      String title,
      List<Task> tasks, {
      Widget? action,
    }) {
      if (tasks.isEmpty) return const SizedBox.shrink();
      return TodaySection(
        id: id,
        title: title,
        tasks: tasks,
        collapsed: _collapsed.contains(id),
        onToggle: () => _toggle(id),
        action: action,
      );
    }

    return [
      section(
        'overdue',
        l10n.todaySectionOverdue,
        s.overdue,
        action: TextButton(
          key: const Key('today.rescheduleAll'),
          onPressed: () => showPostponeSheet(context, ref, s.overdue),
          child: Text(l10n.todayRescheduleAll),
        ),
      ),
      section('morning', l10n.todaySectionMorning, s.morning),
      section('afternoon', l10n.todaySectionAfternoon, s.afternoon),
      section('evening', l10n.todaySectionEvening, s.evening),
      section('anytime', l10n.todaySectionAnytime, s.anytime),
      section('completed', l10n.todaySectionCompleted, s.completed),
    ];
  }

  Widget _scrollable(List<Widget> children) {
    final space = context.tokens.space4;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(space),
      children: [
        for (final c in children)
          Padding(
            padding: EdgeInsets.only(bottom: space),
            child: c,
          ),
      ],
    );
  }
}

/// A collapsible group of tasks with its count. Keys: `today.section.<id>`
/// (header) and `today.section.<id>.count`.
class TodaySection extends StatelessWidget {
  const TodaySection({
    super.key,
    required this.id,
    required this.title,
    required this.tasks,
    required this.collapsed,
    required this.onToggle,
    this.action,
  });

  final String id;
  final String title;
  final List<Task> tasks;
  final bool collapsed;
  final VoidCallback onToggle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final color = id == 'overdue'
        ? tokens.overdue
        : theme.colorScheme.onSurface;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  key: Key('today.section.$id'),
                  onTap: onToggle,
                  borderRadius: BorderRadius.circular(tokens.radiusMedium),
                  child: Padding(
                    padding: EdgeInsets.all(tokens.space3),
                    child: Row(
                      children: [
                        Icon(
                          collapsed ? Icons.chevron_right : Icons.expand_more,
                          color: color,
                        ),
                        SizedBox(width: tokens.space2),
                        Flexible(
                          child: Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: color,
                            ),
                          ),
                        ),
                        SizedBox(width: tokens.space2),
                        Text(
                          '${tasks.length}',
                          key: Key('today.section.$id.count'),
                          style: theme.textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Flexible: at large text sizes the button wraps instead of
              // overflowing the card.
              if (action != null) Flexible(child: action!),
            ],
          ),
          if (!collapsed)
            for (final t in tasks)
              TaskTile(key: ValueKey(t.localId ?? t.uid.value), task: t),
        ],
      ),
    );
  }
}

class _TodayEmpty extends StatelessWidget {
  const _TodayEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return Padding(
      key: const Key('today.empty'),
      padding: EdgeInsets.symmetric(vertical: tokens.space8),
      child: Column(
        children: [
          Icon(Icons.task_alt, size: 56, color: tokens.success),
          SizedBox(height: tokens.space3),
          Text(
            context.l10n.todayEmptyTitle,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: tokens.space1),
          Text(
            context.l10n.todayEmptyBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TodayError extends StatelessWidget {
  const _TodayError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return Padding(
      key: const Key('today.error'),
      padding: EdgeInsets.symmetric(vertical: tokens.space8),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
          SizedBox(height: tokens.space3),
          Text(
            context.l10n.todayErrorTitle,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: tokens.space3),
          FilledButton(
            key: const Key('today.retry'),
            onPressed: onRetry,
            child: Text(context.l10n.todayRetry),
          ),
        ],
      ),
    );
  }
}

class _TodaySkeleton extends StatelessWidget {
  const _TodaySkeleton();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget bar(double h) => Container(
      height: h,
      margin: EdgeInsets.only(bottom: tokens.space3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
      ),
    );
    return Column(
      key: const Key('today.loading'),
      children: [bar(96), bar(40), bar(56), bar(56), bar(56)],
    );
  }
}
