import 'package:flutter/material.dart';

/// Design tokens: a dark field, warm ink, hairlines and one accent.
class Tk {
  Tk._();

  static const bg = Color(0xFF07080B);
  static const paper = Color(0xFF0E1014);
  static const ink = Color(0xFFEDEBE6);
  static const ink2 = Color(0xFFB7B4AD);
  static const ink3 = Color(0xFF85827C);
  static const rule = Color(0x1FFFFFFF);
  static const fill = Color(0x0DFFFFFF);
  static const signal = Color(0xFFFF5A47);
  static const ok = Color(0xFF7BE0A4);
  static const warn = Color(0xFFF2C063);

  /// The accents a person can pick; the first is the default.
  static const accents = <Color>[
    Color(0xFF72CCFC),
    Color(0xFFFF5A47),
    Color(0xFFC8F560),
    Color(0xFFB5A5FF),
    Color(0xFFEDEBE6),
  ];

  static const wide = 860.0;
}

/// Archivo, with its width axis: wider for headings, normal for text.
TextStyle sans(
  double size, {
  double w = 400,
  double wdth = 100,
  Color color = Tk.ink,
  double? height,
  double ls = 0,
  TextDecoration? decoration,
}) {
  return TextStyle(
    fontFamily: 'Archivo',
    fontSize: size,
    color: color,
    height: height,
    letterSpacing: ls,
    decoration: decoration,
    decorationColor: color,
    fontWeight: FontWeight.values[((w / 100).round() - 1).clamp(0, 8)],
    fontVariations: [FontVariation('wght', w), FontVariation('wdth', wdth)],
  );
}

/// JetBrains Mono for labels, counts and anything that reads as a readout.
TextStyle mono(
  double size, {
  double w = 500,
  Color color = Tk.ink3,
  double ls = 1.2,
  double? height,
}) {
  return TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: size,
    color: color,
    height: height,
    letterSpacing: ls,
    fontWeight: FontWeight.values[((w / 100).round() - 1).clamp(0, 8)],
    fontVariations: [FontVariation('wght', w)],
  );
}

extension Accent on BuildContext {
  Color get accent => Theme.of(this).colorScheme.primary;
  bool get isWide => MediaQuery.sizeOf(this).width >= Tk.wide;
}

ThemeData osTheme(Color accent) {
  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: Brightness.dark,
  ).copyWith(primary: accent, onPrimary: Tk.bg, surface: Tk.paper, onSurface: Tk.ink);
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: Tk.bg,
    fontFamily: 'Archivo',
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: accent,
      selectionColor: accent.withValues(alpha: 0.3),
      selectionHandleColor: accent,
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      textStyle: mono(10.5, color: Tk.ink),
      decoration: BoxDecoration(
        color: const Color(0xF216181D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Tk.rule),
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: const Color(0xFF14161B),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}
