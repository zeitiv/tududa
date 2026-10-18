import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_ext.dart';
import '../../tasks/quick_add/quick_add_sheet.dart';
import 'offline_banner.dart';

/// Width from which the bottom bar becomes a navigation rail.
const double kRailBreakpoint = 720;

/// Branch indices of the main tabs (order of `StatefulShellRoute` branches).
const int kTabToday = 0, kTabInbox = 1, kTabUpcoming = 2, kTabProjects = 3;

/// App shell: bottom navigation (rail on wide screens), offline banner and the
/// global quick-add button. Each tab keeps its own navigation stack.
class ShellScaffold extends StatelessWidget {
  const ShellScaffold({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _select(int i) =>
      shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final index = shell.currentIndex;
    final wide = MediaQuery.sizeOf(context).width >= kRailBreakpoint;
    final showAdd = index <= kTabUpcoming;

    final destinations = <({IconData icon, IconData selected, String label})>[
      (icon: Icons.today_outlined, selected: Icons.today, label: l10n.navToday),
      (icon: Icons.inbox_outlined, selected: Icons.inbox, label: l10n.navInbox),
      (
        icon: Icons.upcoming_outlined,
        selected: Icons.upcoming,
        label: l10n.navUpcoming,
      ),
      (
        icon: Icons.folder_outlined,
        selected: Icons.folder,
        label: l10n.navProjects,
      ),
      (
        icon: Icons.more_horiz_outlined,
        selected: Icons.more_horiz,
        label: l10n.navMore,
      ),
    ];

    final fab = showAdd
        ? FloatingActionButton(
            heroTag: 'shell-quick-add',
            tooltip: l10n.shellQuickAdd,
            onPressed: () => showQuickAddSheet(context),
            child: const Icon(Icons.add),
          )
        : null;

    if (wide) {
      return Scaffold(
        floatingActionButton: fab,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: _select,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selected),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  const OfflineBanner(),
                  Expanded(child: shell),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      floatingActionButton: fab,
      body: shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const OfflineBanner(),
          NavigationBar(
            selectedIndex: index,
            onDestinationSelected: _select,
            destinations: [
              for (final d in destinations)
                NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selected),
                  label: d.label,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
