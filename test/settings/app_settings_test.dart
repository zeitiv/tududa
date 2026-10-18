import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tududa/settings/providers/settings_provider.dart';

Future<ProviderContainer> make(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('defaults: system language', () async {
    final s = (await make({})).read(settingsProvider);
    expect(s.language, AppLanguage.system);
    expect(s.dynamicColor, isTrue);
    expect(s.reduceMotion, isFalse);
    expect(s.themeMode, AppThemeMode.system);
  });

  test('migrates legacy app_locale', () async {
    expect(
      (await make({'app_locale': 'zh'})).read(settingsProvider).language,
      AppLanguage.zh,
    );
    expect(
      (await make({'app_locale': 'en'})).read(settingsProvider).language,
      AppLanguage.en,
    );
  });

  test('setters persist and reload', () async {
    final c = await make({'app_locale': 'zh'});
    final n = c.read(settingsProvider.notifier);
    await n.setLanguage(AppLanguage.de);
    await n.setThemeMode(AppThemeMode.dark);
    await n.setDynamicColor(false);
    await n.setContrast(ContrastLevel.high);
    await n.setReduceMotion(true);
    await n.setDensity(DensityLevel.compact);
    final prefs = await SharedPreferences.getInstance();
    final c2 = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c2.dispose);
    final s = c2.read(settingsProvider);
    expect(s.language, AppLanguage.de);
    expect(s.themeMode, AppThemeMode.dark);
    expect(s.dynamicColor, isFalse);
    expect(s.contrast, ContrastLevel.high);
    expect(s.reduceMotion, isTrue);
    expect(s.density, DensityLevel.compact);
  });
}
