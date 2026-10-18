import 'package:flutter/material.dart';

/// WCAG 2.x contrast ratio between two opaque colours (1..21).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Moves [fg] towards black or white (whichever helps) until it reaches
/// [minRatio] against every colour in [backgrounds].
Color ensureContrast(
  Color fg,
  List<Color> backgrounds, {
  double minRatio = 4.5,
}) {
  bool ok(Color c) => backgrounds.every((b) => contrastRatio(c, b) >= minRatio);
  if (ok(fg)) return fg;
  // Lighten when the backgrounds are dark, darken otherwise.
  final avg =
      backgrounds.map((b) => b.computeLuminance()).reduce((a, b) => a + b) /
      backgrounds.length;
  final target = avg < 0.4 ? Colors.white : Colors.black;
  for (var t = 0.05; t <= 1.0; t += 0.05) {
    final c = Color.lerp(fg, target, t)!;
    if (ok(c)) return c;
  }
  return target;
}

/// Interaction-state helpers shared by the component themes.
class ComponentStates {
  ComponentStates._();

  /// Minimum interactive size (Material / WCAG target size).
  static const double minTarget = 48;

  /// Resolves [normal] for every state: disabled gets 38% onSurface.
  static WidgetStateProperty<Color?> foreground(
    ColorScheme s, {
    Color? normal,
  }) => WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) {
      return s.onSurface.withValues(alpha: 0.38);
    }
    return normal ?? s.onSurface;
  });

  /// State layer overlay (hover 8%, focus/pressed 10-12%).
  static WidgetStateProperty<Color?> overlay(Color base) =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return base.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.focused)) {
          return base.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.hovered)) {
          return base.withValues(alpha: 0.08);
        }
        return null;
      });

  /// Visible focus ring for keyboard navigation.
  static BorderSide focusSide(ColorScheme s) =>
      BorderSide(color: s.primary, width: 2);
}
