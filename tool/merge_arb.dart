// Merges the per-feature l10n fragments into one ARB file per locale.
//
// Fragments live in `lib/l10n/src/**/*.json` so parallel work streams never
// edit the same file. Each key maps to one message in every locale:
//
//   "taskNew": {
//     "en": "New task", "de": "Neue Aufgabe", "zh": "新建任务",
//     "description": "Title of the create-task screen",
//     "placeholders": {"count": {"type": "int"}}   // optional
//   }
//
// Usage:
//   dart run tool/merge_arb.dart          write lib/l10n/arb/app_<locale>.arb
//   dart run tool/merge_arb.dart --check  fail on problems or stale output
import 'dart:convert';
import 'dart:io';

const _locales = ['en', 'de', 'zh'];
const _templateLocale = 'en';
final _srcDir = Directory('lib/l10n/src');
final _arbDir = Directory('lib/l10n/arb');

// Matches `{name}` / `{name, plural, ...}`, not ICU branches like `other{x}`.
final _placeholder = RegExp(r'(?<![\w=])\{\s*([A-Za-z_]\w*)\s*[,}]');

void main(List<String> args) => exit(_run(args));

int _run(List<String> args) {
  final check = args.contains('--check');
  final errors = <String>[];
  final messages = <String, Map<String, dynamic>>{};
  final origin = <String, String>{};

  final files =
      _srcDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final Object? decoded;
    try {
      decoded = jsonDecode(file.readAsStringSync());
    } on FormatException catch (e) {
      errors.add('${file.path}: invalid JSON (${e.message})');
      continue;
    }
    if (decoded is! Map<String, dynamic>) {
      errors.add('${file.path}: top level must be an object');
      continue;
    }
    for (final entry in decoded.entries) {
      final key = entry.key;
      final value = entry.value;
      if (!RegExp(r'^[a-z][A-Za-z0-9]*$').hasMatch(key)) {
        errors.add('${file.path}: "$key" is not a lowerCamelCase key');
        continue;
      }
      if (origin.containsKey(key)) {
        errors.add(
          '${file.path}: duplicate key "$key" (also in ${origin[key]})',
        );
        continue;
      }
      if (value is! Map<String, dynamic>) {
        errors.add('${file.path}: "$key" must be an object');
        continue;
      }
      origin[key] = file.path;
      messages[key] = value;
      for (final locale in _locales) {
        final text = value[locale];
        if (text is! String || text.trim().isEmpty) {
          errors.add('${file.path}: "$key" has no "$locale" text');
        }
      }
      final template = value[_templateLocale];
      if (template is String) {
        final expected = _placeholders(template);
        final declared = ((value['placeholders'] as Map?) ?? {}).keys.toSet();
        if (!expected.containsAll(declared) ||
            !declared.containsAll(expected)) {
          errors.add(
            '${file.path}: "$key" placeholders in text $expected differ from '
            'declared $declared',
          );
        }
        for (final locale in _locales) {
          final text = value[locale];
          if (text is! String) continue; // already reported above
          final found = _placeholders(text);
          if (found.length != expected.length || !found.containsAll(expected)) {
            errors.add(
              '${file.path}: "$key" $locale placeholders $found differ from '
              '$expected',
            );
          }
        }
      }
    }
  }

  final outputs = <String, String>{};
  for (final locale in _locales) {
    final arb = <String, Object?>{'@@locale': locale};
    final keys = messages.keys.toList()..sort();
    for (final key in keys) {
      final m = messages[key]!;
      arb[key] = m[locale] ?? '';
      if (locale == _templateLocale) {
        final meta = <String, Object?>{};
        if (m['description'] != null) meta['description'] = m['description'];
        final ph = m['placeholders'] as Map?;
        if (ph != null && ph.isNotEmpty) meta['placeholders'] = ph;
        if (meta.isNotEmpty) arb['@$key'] = meta;
      }
    }
    outputs['${_arbDir.path}/app_$locale.arb'] =
        '${const JsonEncoder.withIndent('  ').convert(arb)}\n';
  }

  if (check) {
    for (final e in outputs.entries) {
      final f = File(e.key);
      if (!f.existsSync() || f.readAsStringSync() != e.value) {
        errors.add('${e.key} is stale: run `dart run tool/merge_arb.dart`');
      }
    }
  }
  if (errors.isNotEmpty) {
    stderr.writeln(errors.join('\n'));
    return 1;
  }
  if (!check) {
    _arbDir.createSync(recursive: true);
    for (final e in outputs.entries) {
      File(e.key).writeAsStringSync(e.value);
    }
    stdout.writeln(
      'Merged ${messages.length} messages from ${files.length} '
      'fragments into ${outputs.length} ARB files.',
    );
  }
  return 0;
}

Set<String> _placeholders(String text) =>
    _placeholder.allMatches(text).map((m) => m.group(1)!).toSet();
