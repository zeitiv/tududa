import 'dart:ui';

/// Languages the app ships translations for.
const supportedLocales = [Locale('en'), Locale('de'), Locale('zh')];

const _fallback = Locale('en');

/// Picks the app locale from the stored preference.
///
/// [pref] is `'system'`, `'en'`, `'de'` or `'zh'` (anything else is treated as
/// `'system'`). For `'system'` the first device locale with a supported
/// language wins (`de-AT` -> `de`, `zh-Hant` -> `zh`); otherwise English.
Locale resolveLocale(String pref, List<Locale> deviceLocales) {
  for (final l in supportedLocales) {
    if (l.languageCode == pref) return l;
  }
  for (final d in deviceLocales) {
    for (final l in supportedLocales) {
      if (l.languageCode == d.languageCode) return l;
    }
  }
  return _fallback;
}
