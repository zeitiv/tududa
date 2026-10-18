import '../../core/design/tokens.dart';

export '../../core/design/tokens.dart' show ContrastLevel, DensityLevel;

enum AppLanguage {
  system,
  en,
  de,
  zh;

  /// Preference string understood by `resolveLocale`.
  String get code => name;
}

enum AppThemeMode { system, light, dark }

/// Immutable user preferences, persisted in SharedPreferences.
class AppSettings {
  final AppLanguage language;
  final AppThemeMode themeMode;
  final bool dynamicColor;
  final ContrastLevel contrast;

  /// User toggle; the OS "disable animations" flag is honoured on top of it.
  final bool reduceMotion;
  final DensityLevel density;

  const AppSettings({
    this.language = AppLanguage.system,
    this.themeMode = AppThemeMode.system,
    this.dynamicColor = true,
    this.contrast = ContrastLevel.standard,
    this.reduceMotion = false,
    this.density = DensityLevel.comfortable,
  });

  /// Compatibility for the legacy two-language settings UI: 'zh' or 'en'.
  String get locale => language == AppLanguage.zh ? 'zh' : 'en';

  AppSettings copyWith({
    AppLanguage? language,
    AppThemeMode? themeMode,
    bool? dynamicColor,
    ContrastLevel? contrast,
    bool? reduceMotion,
    DensityLevel? density,
  }) => AppSettings(
    language: language ?? this.language,
    themeMode: themeMode ?? this.themeMode,
    dynamicColor: dynamicColor ?? this.dynamicColor,
    contrast: contrast ?? this.contrast,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    density: density ?? this.density,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.language == language &&
      other.themeMode == themeMode &&
      other.dynamicColor == dynamicColor &&
      other.contrast == contrast &&
      other.reduceMotion == reduceMotion &&
      other.density == density;

  @override
  int get hashCode => Object.hash(
    language,
    themeMode,
    dynamicColor,
    contrast,
    reduceMotion,
    density,
  );
}
