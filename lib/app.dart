import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/sync/sync_triggers.dart';

import 'settings/providers/settings_provider.dart';

/// Root application widget.
class TududiApp extends ConsumerWidget {
  const TududiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Keeps the sync engine reacting to connectivity, resume and local writes.
    ref.watch(syncTriggersProvider);
    final settings = ref.watch(settingsProvider);

    final mode = switch (settings.themeMode) {
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
      AppThemeMode.system => ThemeMode.system,
    };

    return MaterialApp.router(
      title: 'Tududa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: mode,
      routerConfig: router,
    );
  }
}
