import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/design/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/sync/sync_triggers.dart';
import 'l10n/gen/app_localizations.dart';
import 'l10n/locale_resolver.dart';
import 'settings/providers/settings_provider.dart';

/// Root application widget.
class TududiApp extends ConsumerStatefulWidget {
  const TududiApp({super.key});

  @override
  ConsumerState<TududiApp> createState() => _TududiAppState();
}

class _TududiAppState extends ConsumerState<TududiApp>
    with WidgetsBindingObserver {
  late bool _osReduceMotion;

  bool _readOsReduceMotion() => WidgetsBinding
      .instance
      .platformDispatcher
      .accessibilityFeatures
      .disableAnimations;

  @override
  void initState() {
    super.initState();
    _osReduceMotion = _readOsReduceMotion();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAccessibilityFeatures() {
    final v = _readOsReduceMotion();
    if (v != _osReduceMotion) setState(() => _osReduceMotion = v);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    // Keeps the sync engine reacting to connectivity, resume and local writes.
    ref.watch(syncTriggersProvider);
    final settings = ref.watch(settingsProvider);

    final mode = switch (settings.themeMode) {
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
      AppThemeMode.system => ThemeMode.system,
    };
    // System language: null lets localeListResolutionCallback decide.
    final locale = settings.language == AppLanguage.system
        ? null
        : Locale(settings.language.code);
    final reduceMotion = settings.reduceMotion || _osReduceMotion;

    ThemeData theme(
      Brightness b,
      ColorScheme? dynamic, {
      ContrastLevel? contrast,
    }) => buildTheme(
      brightness: b,
      dynamicScheme: settings.dynamicColor ? dynamic : null,
      contrast: contrast ?? settings.contrast,
      density: settings.density,
      reduceMotion: reduceMotion,
    );

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) => MaterialApp.router(
        onGenerateTitle: (context) => 'Tududa',
        debugShowCheckedModeBanner: false,
        theme: theme(Brightness.light, lightDynamic),
        darkTheme: theme(Brightness.dark, darkDynamic),
        highContrastTheme: theme(
          Brightness.light,
          lightDynamic,
          contrast: ContrastLevel.high,
        ),
        highContrastDarkTheme: theme(
          Brightness.dark,
          darkDynamic,
          contrast: ContrastLevel.high,
        ),
        themeMode: mode,
        themeAnimationDuration: reduceMotion
            ? Duration.zero
            : kThemeAnimationDuration,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        localeListResolutionCallback: (locales, supported) =>
            resolveLocale(AppLanguage.system.code, locales ?? const []),
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          // Text scaling is left untouched on purpose.
          return MediaQuery(
            data: mq.copyWith(
              disableAnimations: mq.disableAnimations || reduceMotion,
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
        routerConfig: router,
      ),
    );
  }
}
