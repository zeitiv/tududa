import 'package:flutter/material.dart';

import 'component_states.dart' show ensureContrast;

/// Density of the UI; scales spacing.
enum DensityLevel {
  comfortable(1.0),
  compact(0.8);

  const DensityLevel(this.scale);
  final double scale;
}

/// Contrast preference for generated colour schemes.
enum ContrastLevel {
  standard(0.0),
  medium(0.5),
  high(1.0);

  const ContrastLevel(this.level);
  final double level;
}

/// Semantic design tokens that Material's [ColorScheme] does not cover.
/// Colours are derived from the scheme so dynamic colour keeps working and
/// every foreground meets WCAG AA (4.5:1) on surface and surfaceContainerHighest.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.priorityLow,
    required this.priorityMedium,
    required this.priorityHigh,
    required this.statusNotStarted,
    required this.statusInProgress,
    required this.statusDone,
    required this.statusArchived,
    required this.statusWaiting,
    required this.statusCancelled,
    required this.statusPlanned,
    required this.overdue,
    required this.today,
    required this.success,
    required this.warning,
    required this.info,
    required this.focus,
    required this.space1,
    required this.space2,
    required this.space3,
    required this.space4,
    required this.space5,
    required this.space6,
    required this.space8,
    required this.space12,
    required this.radiusSmall,
    required this.radiusMedium,
    required this.radiusLarge,
    required this.radiusFull,
    required this.elevationLow,
    required this.elevationMedium,
    required this.elevationHigh,
    required this.motionShort,
    required this.motionMedium,
    required this.motionLong,
  });

  factory AppTokens.fromScheme(
    ColorScheme s, {
    DensityLevel density = DensityLevel.comfortable,
    bool reduceMotion = false,
    ContrastLevel contrast = ContrastLevel.standard,
  }) {
    final bgs = [s.surface, s.surfaceContainerHighest, s.surfaceContainerLow];
    final min = contrast == ContrastLevel.high ? 7.0 : 4.5;
    final dark = s.brightness == Brightness.dark;
    // Blend a fixed-hue base slightly towards primary so it harmonises.
    Color c(int light, int darkBase) {
      final base = Color(dark ? darkBase : light);
      final mixed = Color.lerp(base, s.primary, 0.12)!;
      return ensureContrast(mixed, bgs, minRatio: min);
    }

    final sp = density.scale;
    Duration d(int ms) =>
        reduceMotion ? Duration.zero : Duration(milliseconds: ms);
    return AppTokens(
      priorityLow: c(0xFF1D7A46, 0xFF6FD39A),
      priorityMedium: c(0xFFA15C00, 0xFFF2B35B),
      priorityHigh: ensureContrast(s.error, bgs, minRatio: min),
      statusNotStarted: c(0xFF5B6470, 0xFFA7B0BC),
      statusInProgress: c(0xFF1F5FBF, 0xFF8AB4F8),
      statusDone: c(0xFF1D7A46, 0xFF6FD39A),
      statusArchived: c(0xFF6B5F52, 0xFFBFB2A3),
      statusWaiting: c(0xFF8A5A00, 0xFFE8B84A),
      statusCancelled: c(0xFF8A3B3B, 0xFFE59A9A),
      statusPlanned: c(0xFF6A3FB5, 0xFFC4A8F5),
      overdue: ensureContrast(s.error, bgs, minRatio: min),
      today: ensureContrast(s.primary, bgs, minRatio: min),
      success: c(0xFF1D7A46, 0xFF6FD39A),
      warning: c(0xFF8A5A00, 0xFFF2B35B),
      info: c(0xFF1F5FBF, 0xFF8AB4F8),
      focus: ensureContrast(s.primary, bgs, minRatio: 3.0),
      space1: 4 * sp,
      space2: 8 * sp,
      space3: 12 * sp,
      space4: 16 * sp,
      space5: 20 * sp,
      space6: 24 * sp,
      space8: 32 * sp,
      space12: 48 * sp,
      radiusSmall: 8,
      radiusMedium: 12,
      radiusLarge: 20,
      radiusFull: 999,
      elevationLow: 1,
      elevationMedium: 3,
      elevationHigh: 6,
      motionShort: d(120),
      motionMedium: d(220),
      motionLong: d(360),
    );
  }

  final Color priorityLow, priorityMedium, priorityHigh;
  final Color statusNotStarted,
      statusInProgress,
      statusDone,
      statusArchived,
      statusWaiting,
      statusCancelled,
      statusPlanned;
  final Color overdue, today, success, warning, info, focus;

  /// 4pt scale (times density).
  final double space1, space2, space3, space4, space5, space6, space8, space12;
  final double radiusSmall, radiusMedium, radiusLarge, radiusFull;
  final double elevationLow, elevationMedium, elevationHigh;
  final Duration motionShort, motionMedium, motionLong;

  /// All colour tokens, for iteration (tests, legends).
  Map<String, Color> get colors => {
    'priorityLow': priorityLow,
    'priorityMedium': priorityMedium,
    'priorityHigh': priorityHigh,
    'statusNotStarted': statusNotStarted,
    'statusInProgress': statusInProgress,
    'statusDone': statusDone,
    'statusArchived': statusArchived,
    'statusWaiting': statusWaiting,
    'statusCancelled': statusCancelled,
    'statusPlanned': statusPlanned,
    'overdue': overdue,
    'today': today,
    'success': success,
    'warning': warning,
    'info': info,
    'focus': focus,
  };

  @override
  AppTokens copyWith({Color? overdue, Color? today, Color? focus}) => AppTokens(
    priorityLow: priorityLow,
    priorityMedium: priorityMedium,
    priorityHigh: priorityHigh,
    statusNotStarted: statusNotStarted,
    statusInProgress: statusInProgress,
    statusDone: statusDone,
    statusArchived: statusArchived,
    statusWaiting: statusWaiting,
    statusCancelled: statusCancelled,
    statusPlanned: statusPlanned,
    overdue: overdue ?? this.overdue,
    today: today ?? this.today,
    success: success,
    warning: warning,
    info: info,
    focus: focus ?? this.focus,
    space1: space1,
    space2: space2,
    space3: space3,
    space4: space4,
    space5: space5,
    space6: space6,
    space8: space8,
    space12: space12,
    radiusSmall: radiusSmall,
    radiusMedium: radiusMedium,
    radiusLarge: radiusLarge,
    radiusFull: radiusFull,
    elevationLow: elevationLow,
    elevationMedium: elevationMedium,
    elevationHigh: elevationHigh,
    motionShort: motionShort,
    motionMedium: motionMedium,
    motionLong: motionLong,
  );

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    Color lc(Color a, Color b) => Color.lerp(a, b, t)!;
    double ld(double a, double b) => a + (b - a) * t;
    Duration lt(Duration a, Duration b) => Duration(
      microseconds: ld(
        a.inMicroseconds.toDouble(),
        b.inMicroseconds.toDouble(),
      ).round(),
    );
    return AppTokens(
      priorityLow: lc(priorityLow, other.priorityLow),
      priorityMedium: lc(priorityMedium, other.priorityMedium),
      priorityHigh: lc(priorityHigh, other.priorityHigh),
      statusNotStarted: lc(statusNotStarted, other.statusNotStarted),
      statusInProgress: lc(statusInProgress, other.statusInProgress),
      statusDone: lc(statusDone, other.statusDone),
      statusArchived: lc(statusArchived, other.statusArchived),
      statusWaiting: lc(statusWaiting, other.statusWaiting),
      statusCancelled: lc(statusCancelled, other.statusCancelled),
      statusPlanned: lc(statusPlanned, other.statusPlanned),
      overdue: lc(overdue, other.overdue),
      today: lc(today, other.today),
      success: lc(success, other.success),
      warning: lc(warning, other.warning),
      info: lc(info, other.info),
      focus: lc(focus, other.focus),
      space1: ld(space1, other.space1),
      space2: ld(space2, other.space2),
      space3: ld(space3, other.space3),
      space4: ld(space4, other.space4),
      space5: ld(space5, other.space5),
      space6: ld(space6, other.space6),
      space8: ld(space8, other.space8),
      space12: ld(space12, other.space12),
      radiusSmall: ld(radiusSmall, other.radiusSmall),
      radiusMedium: ld(radiusMedium, other.radiusMedium),
      radiusLarge: ld(radiusLarge, other.radiusLarge),
      radiusFull: ld(radiusFull, other.radiusFull),
      elevationLow: ld(elevationLow, other.elevationLow),
      elevationMedium: ld(elevationMedium, other.elevationMedium),
      elevationHigh: ld(elevationHigh, other.elevationHigh),
      motionShort: lt(motionShort, other.motionShort),
      motionMedium: lt(motionMedium, other.motionMedium),
      motionLong: lt(motionLong, other.motionLong),
    );
  }
}

extension AppTokensContext on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
