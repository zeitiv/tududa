import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/design/app_theme.dart';
import 'auth/providers/auth_provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'settings/providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences
  final sharedPrefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      // Retries belong to the repositories, not to provider rebuilds.
      retry: (_, _) => null,
      overrides: [sharedPreferencesProvider.overrideWithValue(sharedPrefs)],
      child: const _AppStartup(),
    ),
  );
}

/// Handles initial auth check before showing the app.
class _AppStartup extends ConsumerStatefulWidget {
  const _AppStartup();

  @override
  ConsumerState<_AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends ConsumerState<_AppStartup> {
  @override
  void initState() {
    super.initState();
    // Trigger auth check on startup
    Future.microtask(() => ref.read(authProvider.notifier).checkAuth());
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Show splash / loading while checking auth
    if (authState.status == AuthStatus.initial) {
      final scheme = ColorScheme.fromSeed(
        seedColor: kSeedColor,
        brightness: MediaQuery.platformBrightnessOf(context),
      );
      return ColoredBox(
        color: scheme.surface,
        child: Center(child: CircularProgressIndicator(color: scheme.primary)),
      );
    }

    return const TududiApp();
  }
}
