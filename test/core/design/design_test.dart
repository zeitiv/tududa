import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/design/app_theme.dart';
import 'package:tududa/core/design/component_states.dart';

void main() {
  for (final b in Brightness.values) {
    for (final c in ContrastLevel.values) {
      test('tokens meet WCAG AA ${b.name} ${c.name}', () {
        final t = buildTheme(
          brightness: b,
          contrast: c,
          density: DensityLevel.comfortable,
          reduceMotion: false,
        );
        final s = t.colorScheme;
        final tokens = t.extension<AppTokens>()!;
        for (final e in tokens.colors.entries) {
          final min = e.key == 'focus' ? 3.0 : 4.5;
          for (final bg in [s.surface, s.surfaceContainerHighest]) {
            expect(
              contrastRatio(e.value, bg),
              greaterThanOrEqualTo(min),
              reason: '${e.key} on $bg',
            );
          }
        }
        expect(
          contrastRatio(s.onSurface, s.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(s.onPrimary, s.primary),
          greaterThanOrEqualTo(4.5),
        );
        expect(contrastRatio(s.primary, s.surface), greaterThanOrEqualTo(3));
      });
    }
  }

  test('dynamic scheme and reduce motion', () {
    final dyn = ColorScheme.fromSeed(seedColor: Colors.orange);
    final t = buildTheme(
      brightness: Brightness.light,
      dynamicScheme: dyn,
      contrast: ContrastLevel.standard,
      density: DensityLevel.compact,
      reduceMotion: true,
    );
    expect(t.colorScheme.primary, dyn.primary);
    final tokens = t.extension<AppTokens>()!;
    expect(tokens.motionMedium, Duration.zero);
    expect(tokens.space4, closeTo(16 * DensityLevel.compact.scale, 1e-9));
    final normal = buildTheme(
      brightness: Brightness.dark,
      contrast: ContrastLevel.high,
      density: DensityLevel.comfortable,
      reduceMotion: false,
    );
    expect(normal.extension<AppTokens>()!.motionMedium, isNot(Duration.zero));
  });

  test('tokens lerp', () {
    final a = buildTheme(
      brightness: Brightness.light,
      contrast: ContrastLevel.standard,
      density: DensityLevel.comfortable,
      reduceMotion: false,
    ).extension<AppTokens>()!;
    final b = buildTheme(
      brightness: Brightness.dark,
      contrast: ContrastLevel.standard,
      density: DensityLevel.comfortable,
      reduceMotion: false,
    ).extension<AppTokens>()!;
    expect(a.lerp(b, 0).overdue, a.overdue);
    expect(a.lerp(b, 1).overdue, b.overdue);
  });

  test('no BackdropFilter in lib/core/design', () {
    for (final f in Directory('lib/core/design').listSync(recursive: true)) {
      if (f is File && f.path.endsWith('.dart')) {
        expect(f.readAsStringSync().contains('BackdropFilter'), isFalse);
      }
    }
  });
}
