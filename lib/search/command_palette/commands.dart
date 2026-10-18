import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/sync/sync_actions.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../notes/providers/note_provider.dart';
import '../../projects/data/project_repository.dart';
import '../../settings/providers/settings_provider.dart';
import '../../tasks/data/offline_task_repository.dart';
import '../../tasks/data/task_query.dart';
import '../../tasks/quick_add/quick_add_sheet.dart';

/// What a command can use when it runs. [context] must belong to the screen
/// that opened the palette (the palette dialog is already closed).
class PaletteContext {
  const PaletteContext({
    required this.context,
    required this.container,
    this.query = '',
  });

  final BuildContext context;
  final ProviderContainer container;

  /// The text typed into the palette.
  final String query;

  GoRouter get router => GoRouter.of(context);
}

/// One palette entry. Plain data so it can be tested without any UI.
class PaletteCommand {
  const PaletteCommand({
    required this.id,
    required this.label,
    required this.icon,
    required this.run,
    this.keywords = const [],
    this.kind,
  });

  final String id;
  final String label;
  final List<String> keywords;
  final IconData icon;

  /// Localized kind ("Task", ...) for "open item" entries.
  final String? kind;
  final FutureOr<void> Function(PaletteContext c) run;
}

/// The built-in commands, localized with [l10n].
List<PaletteCommand> buildPaletteCommands(AppLocalizations l10n) {
  PaletteCommand go(
    String id,
    String label,
    IconData icon,
    String route, {
    List<String> keywords = const [],
  }) => PaletteCommand(
    id: id,
    label: label,
    icon: icon,
    keywords: keywords,
    run: (c) => c.router.go(route),
  );

  return [
    PaletteCommand(
      id: 'add-task',
      label: l10n.paletteAddTask,
      icon: Icons.add_task,
      keywords: const ['new', 'create', 'quick'],
      run: (c) => showQuickAddSheet(c.context),
    ),
    go('go-today', l10n.paletteGoToday, Icons.today, '/today'),
    go('go-inbox', l10n.paletteGoInbox, Icons.inbox, '/inbox'),
    go('go-upcoming', l10n.paletteGoUpcoming, Icons.upcoming, '/upcoming'),
    go('go-projects', l10n.paletteGoProjects, Icons.folder, '/projects'),
    go('go-overdue', l10n.paletteGoOverdue, Icons.warning_amber, '/overdue'),
    go('go-someday', l10n.paletteGoSomeday, Icons.bedtime_outlined, '/someday'),
    go(
      'go-completed',
      l10n.paletteGoCompleted,
      Icons.check_circle_outline,
      '/completed',
    ),
    go('go-notes', l10n.paletteGoNotes, Icons.notes, '/notes'),
    go(
      'go-areas',
      l10n.paletteGoAreas,
      Icons.dashboard_outlined,
      '/more/areas',
    ),
    go('go-settings', l10n.paletteGoSettings, Icons.settings, '/more'),
    go('go-sync', l10n.paletteGoSync, Icons.sync, '/more/sync'),
    PaletteCommand(
      id: 'search',
      label: l10n.paletteSearch,
      icon: Icons.search,
      keywords: const ['find'],
      run: (c) => c.router.push(
        c.query.trim().isEmpty
            ? '/search'
            : '/search?q=${Uri.encodeQueryComponent(c.query.trim())}',
      ),
    ),
    PaletteCommand(
      id: 'run-sync',
      label: l10n.paletteRunSync,
      icon: Icons.sync_alt,
      keywords: const ['refresh'],
      run: (c) => c.container.read(syncActionsProvider).syncNow(),
    ),
    PaletteCommand(
      id: 'change-theme',
      label: l10n.paletteChangeTheme,
      icon: Icons.brightness_6_outlined,
      keywords: const ['dark', 'light', 'appearance'],
      run: (c) {
        final n = c.container.read(settingsProvider.notifier);
        final cur = c.container.read(settingsProvider).themeMode;
        const values = AppThemeMode.values;
        return n.setThemeMode(values[(cur.index + 1) % values.length]);
      },
    ),
    PaletteCommand(
      id: 'toggle-reduce-motion',
      label: l10n.paletteToggleReduceMotion,
      icon: Icons.animation,
      keywords: const ['animation', 'accessibility'],
      run: (c) => c.container
          .read(settingsProvider.notifier)
          .setReduceMotion(!c.container.read(settingsProvider).reduceMotion),
    ),
  ];
}

/// Max number of "open item" entries.
const int kPaletteMaxItems = 5;

/// Top local tasks/projects/notes whose name matches [query] (>= 2 chars),
/// read from the offline repositories. Empty for shorter queries.
Future<List<PaletteCommand>> findPaletteItems(
  ProviderContainer container,
  AppLocalizations l10n,
  String query,
) async {
  final q = query.trim();
  if (q.length < 2) return const [];
  final lower = q.toLowerCase();
  final out = <PaletteCommand>[];

  final tasks = await container
      .read(taskRepositoryProvider)
      .fetch(TaskQuery(search: q, limit: kPaletteMaxItems * 4));
  for (final t in tasks.items) {
    if (t.uid.value.isEmpty || !t.name.toLowerCase().contains(lower)) continue;
    out.add(
      PaletteCommand(
        id: 'task:${t.uid.value}',
        label: t.name,
        kind: l10n.paletteKindTask,
        icon: Icons.check_circle_outline,
        run: (c) => c.router.push('/tasks/${t.uid.value}'),
      ),
    );
  }
  final projects = await container.read(projectRepositoryProvider).list();
  for (final p in projects) {
    if (!p.name.toLowerCase().contains(lower)) continue;
    out.add(
      PaletteCommand(
        id: 'project:${p.uid.value}',
        label: p.name,
        kind: l10n.paletteKindProject,
        icon: Icons.folder_outlined,
        run: (c) => c.router.push('/projects/${p.uid.value}'),
      ),
    );
  }
  final notes = await container.read(noteRepositoryProvider).list();
  for (final n in notes) {
    final title = n.title ?? '';
    final id = n.routeId;
    if (id == null || !title.toLowerCase().contains(lower)) continue;
    out.add(
      PaletteCommand(
        id: 'note:$id',
        label: title,
        kind: l10n.paletteKindNote,
        icon: Icons.notes,
        run: (c) => c.router.push('/notes/$id'),
      ),
    );
  }
  // Best name matches first (prefix, then shorter), stable otherwise.
  final ranked = rankItems(out, q);
  return ranked.take(kPaletteMaxItems).toList();
}

/// Orders item entries: label starts with [query] first, then shorter labels.
List<PaletteCommand> rankItems(List<PaletteCommand> items, String query) {
  final q = query.toLowerCase();
  final indexed = items.indexed.toList()
    ..sort((a, b) {
      final ap = a.$2.label.toLowerCase().startsWith(q) ? 0 : 1;
      final bp = b.$2.label.toLowerCase().startsWith(q) ? 0 : 1;
      if (ap != bp) return ap - bp;
      final len = a.$2.label.length - b.$2.label.length;
      return len != 0 ? len : a.$1 - b.$1;
    });
  return [for (final e in indexed) e.$2];
}

/// Subsequence match of [query] in [text] (case-insensitive). Null when not a
/// subsequence; otherwise higher is better. Rewards prefixes, word starts and
/// consecutive runs, and penalizes gaps and long texts.
int? fuzzyScore(String query, String text) {
  final q = query.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  if (q.isEmpty) return 0;
  final t = text.toLowerCase();
  var score = 0;
  var ti = 0;
  var prev = -2;
  for (var qi = 0; qi < q.length; qi++) {
    final found = t.indexOf(q[qi], ti);
    if (found < 0) return null;
    final wordStart = found == 0 || !_isAlnum(t.codeUnitAt(found - 1));
    score += 10;
    if (found == prev + 1) score += 15;
    if (wordStart) score += 12;
    if (found == 0) score += 8;
    if (prev >= 0 && found > prev + 1) score -= (found - prev - 1).clamp(0, 6);
    prev = found;
    ti = found + 1;
  }
  if (t == q) score += 40;
  if (t.startsWith(q)) score += 20;
  return score - t.length ~/ 4;
}

bool _isAlnum(int c) =>
    (c >= 48 && c <= 57) || (c >= 97 && c <= 122) || c > 127;

/// Commands matching [query] (label, or keywords at a discount), best first.
/// An empty query keeps the original order.
List<PaletteCommand> rankCommands(List<PaletteCommand> all, String query) {
  if (query.trim().isEmpty) return List.of(all);
  final scored = <(int, int, PaletteCommand)>[];
  for (var i = 0; i < all.length; i++) {
    final c = all[i];
    var best = fuzzyScore(query, c.label);
    for (final k in c.keywords) {
      final s = fuzzyScore(query, k);
      if (s != null) {
        final d = s * 3 ~/ 4;
        if (best == null || d > best) best = d;
      }
    }
    if (best != null) scored.add((best, i, c));
  }
  scored.sort((a, b) => a.$1 != b.$1 ? b.$1 - a.$1 : a.$2 - b.$2);
  return [for (final s in scored) s.$3];
}
