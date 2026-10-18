import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/app_settings.dart';

export '../domain/app_settings.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(),
);

T _byName<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

class SettingsNotifier extends Notifier<AppSettings> {
  static const _themeKey = 'app_theme_mode';
  // Legacy key: 'zh' / 'en' was an explicit choice (the old default 'zh' was
  // never written), so it maps to the matching language.
  static const _localeKey = 'app_locale';
  static const _languageKey = 'app_language';
  static const _dynamicKey = 'app_dynamic_color';
  static const _contrastKey = 'app_contrast';
  static const _motionKey = 'app_reduce_motion';
  static const _densityKey = 'app_density';

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final language = prefs.containsKey(_languageKey)
        ? _byName(
            AppLanguage.values,
            prefs.getString(_languageKey),
            AppLanguage.system,
          )
        : switch (prefs.getString(_localeKey)) {
            'zh' => AppLanguage.zh,
            'en' => AppLanguage.en,
            _ => AppLanguage.system,
          };
    return AppSettings(
      language: language,
      themeMode: _byName(
        AppThemeMode.values,
        prefs.getString(_themeKey),
        AppThemeMode.system,
      ),
      dynamicColor: prefs.getBool(_dynamicKey) ?? true,
      contrast: _byName(
        ContrastLevel.values,
        prefs.getString(_contrastKey),
        ContrastLevel.standard,
      ),
      reduceMotion: prefs.getBool(_motionKey) ?? false,
      density: _byName(
        DensityLevel.values,
        prefs.getString(_densityKey),
        DensityLevel.comfortable,
      ),
    );
  }

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  Future<void> setLanguage(AppLanguage v) async {
    await _prefs.setString(_languageKey, v.name);
    state = state.copyWith(language: v);
  }

  Future<void> setThemeMode(AppThemeMode v) async {
    await _prefs.setString(_themeKey, v.name);
    state = state.copyWith(themeMode: v);
  }

  Future<void> setDynamicColor(bool v) async {
    await _prefs.setBool(_dynamicKey, v);
    state = state.copyWith(dynamicColor: v);
  }

  Future<void> setContrast(ContrastLevel v) async {
    await _prefs.setString(_contrastKey, v.name);
    state = state.copyWith(contrast: v);
  }

  Future<void> setReduceMotion(bool v) async {
    await _prefs.setBool(_motionKey, v);
    state = state.copyWith(reduceMotion: v);
  }

  Future<void> setDensity(DensityLevel v) async {
    await _prefs.setString(_densityKey, v.name);
    state = state.copyWith(density: v);
  }

  /// Compatibility with the legacy settings screen ('zh' / 'en').
  Future<void> setLocale(String locale) =>
      setLanguage(_byName(AppLanguage.values, locale, AppLanguage.system));
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(() {
  return SettingsNotifier();
});

// Legacy localized strings: 'zh' only when the resolved locale is Chinese.
