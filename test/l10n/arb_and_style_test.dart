import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every locale has exactly the keys of the English template', () {
    Set<String> keys(String l) =>
        (jsonDecode(File('lib/l10n/arb/app_$l.arb').readAsStringSync())
                as Map<String, dynamic>)
            .keys
            .where((k) => !k.startsWith('@'))
            .toSet();
    final en = keys('en');
    expect(en, isNotEmpty);
    expect(keys('de'), en);
    expect(keys('zh'), en);
  });

  test('lib/ has no BackdropFilter (no glassmorphism)', () {
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.contains('/gen/'))
        .where((f) => f.readAsStringSync().contains('BackdropFilter('))
        .map((f) => f.path)
        .toList();
    expect(offenders, isEmpty);
  });
}
