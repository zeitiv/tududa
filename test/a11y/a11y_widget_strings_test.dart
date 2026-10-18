import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The native home-screen widget's strings (android/app/src/main/res): every
/// key exists in en, de and zh, none is empty, and every string the widget's
/// Kotlin code and layouts refer to is defined. A missing translation would
/// show the English fallback (or crash on a missing default) in a screen
/// reader.
const _res = 'android/app/src/main/res';
const _locales = {'en': 'values', 'de': 'values-de', 'zh': 'values-zh'};

final _entry = RegExp(
  r'<string\s+name="([^"]+)"[^>]*>(.*?)</string>',
  dotAll: true,
);

Map<String, String> _load(String dir) {
  final xml = File('$_res/$dir/strings.xml').readAsStringSync();
  return {for (final m in _entry.allMatches(xml)) m[1]!: m[2]!.trim()};
}

Set<String> _referenced() {
  final names = <String>{};
  final kotlin = RegExp(r'R\.string\.(\w+)');
  final xmlRef = RegExp(r'@string/(\w+)');
  for (final f in Directory('android/app/src/main').listSync(recursive: true)) {
    if (f is! File) continue;
    final p = f.path;
    if (p.contains('/values')) continue;
    final text = p.endsWith('.kt') || p.endsWith('.java')
        ? f.readAsStringSync()
        : p.endsWith('.xml')
        ? f.readAsStringSync()
        : null;
    if (text == null) continue;
    for (final m in kotlin.allMatches(text)) {
      names.add(m[1]!);
    }
    for (final m in xmlRef.allMatches(text)) {
      names.add(m[1]!);
    }
  }
  return names;
}

void main() {
  final strings = {for (final e in _locales.entries) e.key: _load(e.value)};

  test('en has strings', () {
    expect(strings['en'], isNotEmpty);
  });

  for (final locale in ['de', 'zh']) {
    test('$locale defines exactly the keys of en', () {
      final en = strings['en']!.keys.toSet();
      final other = strings[locale]!.keys.toSet();
      expect(en.difference(other), isEmpty, reason: 'missing in $locale');
      expect(other.difference(en), isEmpty, reason: 'extra in $locale');
    });
  }

  for (final e in strings.entries) {
    test('${e.key} has no empty strings', () {
      expect(
        e.value.entries.where((s) => s.value.isEmpty).map((s) => s.key),
        isEmpty,
      );
    });
  }

  test('placeholders (%1\$s, %d) match between locales', () {
    final spec = RegExp(r'%(\d\$)?[sd]');
    for (final key in strings['en']!.keys) {
      final want = spec.allMatches(strings['en']![key]!).length;
      for (final locale in ['de', 'zh']) {
        final got = spec.allMatches(strings[locale]![key] ?? '').length;
        expect(got, want, reason: '$locale/$key');
      }
    }
  });

  test('every string the widget code and layouts use is defined', () {
    final used = _referenced();
    // Android framework strings (android.R.string.*) are not ours.
    final missing = used.difference(strings['en']!.keys.toSet());
    expect(missing, isEmpty);
  });
}
