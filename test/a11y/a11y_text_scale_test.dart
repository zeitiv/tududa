import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'a11y_cases.dart';
import 'a11y_support.dart';

/// Text at 2.0x (the largest system setting plus headroom) must not overflow
/// any screen, in English and in German (long words).
void main() {
  for (final c in a11yCases) {
    for (final locale in a11yLocales) {
      a11yTest('${c.name} 2.0x ${locale.languageCode}', (
        tester,
        rig,
        data,
      ) async {
        // takeException only keeps the first error, so collect them all.
        final errors = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (d) => errors.add(
          '${d.exceptionAsString()} @ ${d.informationCollector?.call().join(' ') ?? d.context}',
        );
        try {
          await pumpCase(tester, rig, data, c, locale: locale, textScale: 2);
        } finally {
          FlutterError.onError = previous;
        }
        expect(tester.takeException(), isNull);
        expect(errors, isEmpty, reason: '${c.name} overflows at 2.0x');
      });
    }
  }
}
