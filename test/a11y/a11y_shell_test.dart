import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/inbox/providers/inbox_provider.dart';

import 'a11y_cases.dart';
import 'a11y_support.dart';

/// The app shell (bottom navigation on phones, a rail on wide screens, the
/// quick-add button, the offline banner) around the main tabs, through the
/// real router.
void main() {
  const tabs = {
    '/today': 'Pay rent',
    '/inbox': 'weekly review',
    '/upcoming': 'Dentist',
    '/projects': 'Website relaunch',
    '/more': 'Sync',
  };
  const sizes = {'phone': Size(412, 892), 'rail': Size(900, 700)};

  for (final tab in tabs.entries) {
    for (final size in sizes.entries) {
      for (final brightness in a11yBrightnesses) {
        for (final locale in a11yLocales) {
          final label =
              '${tab.key} ${size.key} ${brightness.name} ${locale.languageCode}';
          a11yTest('shell $label', (tester, rig, data) async {
            await pumpA11yApp(
              tester,
              rig,
              location: tab.key,
              brightness: brightness,
              locale: locale,
              size: size.value,
              overrides: [inboxProvider.overrideWith(testInbox)],
            );
            expect(tester.takeException(), isNull);
            if (locale.languageCode == 'en') {
              expect(find.textContaining(tab.value), findsWidgets);
            }
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
    }
  }

  for (final locale in a11yLocales) {
    a11yTest('shell today 2.0x ${locale.languageCode}', (
      tester,
      rig,
      data,
    ) async {
      await pumpA11yApp(
        tester,
        rig,
        location: '/today',
        locale: locale,
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
