import 'package:flutter/material.dart';

/// Bundled variable Inter (wght axis). CJK glyphs fall back to the system font.
const String kFontFamily = 'Inter';

TextStyle _inter(TextStyle? s) {
  if (s == null) return const TextStyle(fontFamily: kFontFamily);
  final w = s.fontWeight ?? FontWeight.w400;
  return s.copyWith(
    fontFamily: kFontFamily,
    fontVariations: [FontVariation('wght', w.value.toDouble())],
  );
}

/// Material 2021 type scale in Inter, coloured for [brightness].
TextTheme buildTextTheme(Brightness brightness, {Color? color}) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
  ).textTheme.apply(displayColor: color, bodyColor: color);
  return TextTheme(
    displayLarge: _inter(base.displayLarge),
    displayMedium: _inter(base.displayMedium),
    displaySmall: _inter(base.displaySmall),
    headlineLarge: _inter(base.headlineLarge),
    headlineMedium: _inter(base.headlineMedium),
    headlineSmall: _inter(
      base.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
    ),
    titleLarge: _inter(base.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
    titleMedium: _inter(
      base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    titleSmall: _inter(base.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
    bodyLarge: _inter(base.bodyLarge),
    bodyMedium: _inter(base.bodyMedium),
    bodySmall: _inter(base.bodySmall),
    labelLarge: _inter(base.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
    labelMedium: _inter(
      base.labelMedium?.copyWith(fontWeight: FontWeight.w500),
    ),
    labelSmall: _inter(base.labelSmall?.copyWith(fontWeight: FontWeight.w500)),
  );
}
