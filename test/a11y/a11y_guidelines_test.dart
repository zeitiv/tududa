import 'package:flutter_test/flutter_test.dart';

import 'a11y_cases.dart';
import 'a11y_support.dart';

/// Flutter's accessibility guidelines on every screen, light and dark, in
/// English and German.
void main() {
  for (final c in a11yCases) {
    group(c.name, () {
      for (final brightness in a11yBrightnesses) {
        for (final locale in a11yLocales) {
          final label = '${brightness.name} ${locale.languageCode}';
          a11yTest('${c.name} $label', (tester, rig, data) async {
            await pumpCase(
              tester,
              rig,
              data,
              c,
              brightness: brightness,
              locale: locale,
            );
            expect(tester.takeException(), isNull);
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            await expectLater(tester, meetsGuideline(textContrastGuideline));
          });
        }
      }
    });
  }
}
