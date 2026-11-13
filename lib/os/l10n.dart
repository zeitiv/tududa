import 'l10n_table.dart';

/// Strings are written in English where they are used; this looks up the
/// German and Chinese for them. `{name}` marks a value to fill in.
class L {
  L._();
  static String code = 'en';
  static const names = {'en': 'English', 'de': 'Deutsch', 'zh': '中文'};
}

String tr(String key, [Map<String, Object>? args]) {
  var out = key;
  if (L.code != 'en') {
    final row = table[key];
    if (row != null) out = row[L.code == 'de' ? 0 : 1];
  }
  if (args != null) {
    args.forEach((k, v) => out = out.replaceAll('{$k}', '$v'));
  }
  return out;
}
