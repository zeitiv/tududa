import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_ext.dart';
import '../../common/widgets/surface_card.dart';
import 'offline_banner.dart';

/// Shell scaffold with bottom navigation bar.
class ShellScaffold extends StatelessWidget {
  final Widget child;

  const ShellScaffold({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/tasks')) return 0;
    if (location.startsWith('/projects')) return 1;
    if (location.startsWith('/notes')) return 2;
    if (location.startsWith('/inbox')) return 3;
    if (location.startsWith('/more')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);
    final strings = context.l10n;

    return Scaffold(
      extendBody: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: child,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const OfflineBanner(),
          SurfaceCard(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) {
                switch (i) {
                  case 0:
                    context.go('/tasks');
                    break;
                  case 1:
                    context.go('/projects');
                    break;
                  case 2:
                    context.go('/notes');
                    break;
                  case 3:
                    context.go('/inbox');
                    break;
                  case 4:
                    context.go('/more');
                    break;
                }
              },
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.today_outlined),
                  selectedIcon: const Icon(Icons.today),
                  label: strings.navTasks,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.folder_outlined),
                  selectedIcon: const Icon(Icons.folder),
                  label: strings.navProjects,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.note_outlined),
                  selectedIcon: const Icon(Icons.note),
                  label: strings.navNotes,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.inbox_outlined),
                  selectedIcon: const Icon(Icons.inbox),
                  label: strings.navInbox,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.more_horiz_outlined),
                  selectedIcon: const Icon(Icons.more_horiz),
                  label: strings.navMore,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
