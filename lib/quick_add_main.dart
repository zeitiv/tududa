import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/design/app_theme.dart';
import 'core/sync/sync_triggers.dart';
import 'core/time/date_formatters.dart';
import 'l10n/gen/app_localizations.dart';
import 'l10n/locale_resolver.dart';
import 'settings/providers/settings_provider.dart';
import 'tasks/quick_add/quick_add_sheet.dart';

const _channel = MethodChannel('tududa/quickadd');

/// Second Dart entrypoint: the native QuickAddActivity (opened from the
/// home-screen widget) runs this to show quick add over a transparent
/// window. It uses the app's providers, so saves go through the outbox.
@pragma('vm:entry-point')
Future<void> quickAddMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DateFormats.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const QuickAddApp(),
    ),
  );
}

/// Asks the native side to finish the activity. A missing channel (tests,
/// other platforms) is ignored.
Future<void> closeQuickAdd() async {
  try {
    await _channel.invokeMethod<void>('close');
  } catch (_) {}
}

/// The minimal app behind [quickAddMain].
class QuickAddApp extends ConsumerWidget {
  const QuickAddApp({super.key, this.onClose});

  /// Overrides how the app closes (default: the `close` method channel call).
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps the sync engine pushing local writes.
    ref.watch(syncTriggersProvider);
    final settings = ref.watch(settingsProvider);
    final mode = switch (settings.themeMode) {
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
      AppThemeMode.system => ThemeMode.system,
    };
    final locale = settings.language == AppLanguage.system
        ? null
        : Locale(settings.language.code);

    ThemeData theme(Brightness b, ColorScheme? dynamic) => buildTheme(
      brightness: b,
      dynamicScheme: settings.dynamicColor ? dynamic : null,
      contrast: settings.contrast,
      density: settings.density,
      reduceMotion: settings.reduceMotion,
    );

    void close() => (onClose ?? closeQuickAdd)();

    return DynamicColorBuilder(
      builder: (light, dark) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme(Brightness.light, light),
        darkTheme: theme(Brightness.dark, dark),
        themeMode: mode,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        localeListResolutionCallback: (locales, supported) =>
            resolveLocale(AppLanguage.system.code, locales ?? const []),
        home: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) close();
          },
          child: Builder(
            builder: (ctx) => Scaffold(
              backgroundColor: Colors.transparent,
              body: Stack(
                children: [
                  // Tapping the transparent area dismisses.
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: close,
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SafeArea(
                      child: Material(
                        color: Theme.of(ctx).colorScheme.surfaceContainerHigh,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: QuickAddSheet(onClose: close),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
