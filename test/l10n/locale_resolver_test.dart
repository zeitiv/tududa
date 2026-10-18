import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/l10n/locale_resolver.dart';

void main() {
  test('system resolution', () {
    expect(
      resolveLocale('system', [const Locale('en', 'US')]),
      const Locale('en'),
    );
    expect(
      resolveLocale('system', [const Locale('de', 'AT')]),
      const Locale('de'),
    );
    expect(
      resolveLocale('system', [
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ]),
      const Locale('zh'),
    );
    expect(
      resolveLocale('system', [const Locale('zh', 'TW')]),
      const Locale('zh'),
    );
    expect(resolveLocale('system', [const Locale('fr')]), const Locale('en'));
    expect(
      resolveLocale('system', [const Locale('fr'), const Locale('zh')]),
      const Locale('zh'),
    );
    expect(resolveLocale('system', const []), const Locale('en'));
    expect(resolveLocale('bogus', [const Locale('de')]), const Locale('de'));
  });

  test('explicit override wins both directions', () {
    expect(resolveLocale('en', [const Locale('de')]), const Locale('en'));
    expect(resolveLocale('de', [const Locale('en')]), const Locale('de'));
    expect(resolveLocale('zh', const []), const Locale('zh'));
  });
}
