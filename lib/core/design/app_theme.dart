import 'package:flutter/material.dart';

import 'component_states.dart';
import 'tokens.dart';
import 'typography.dart';

export 'tokens.dart'
    show AppTokens, AppTokensContext, ContrastLevel, DensityLevel;

/// Brand seed colour.
const Color kSeedColor = Color(0xFF0D9488);

/// Page transition that does nothing (reduce motion).
class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

/// Builds the colour scheme: dynamic when supplied, otherwise seeded.
ColorScheme buildColorScheme({
  required Brightness brightness,
  ColorScheme? dynamicScheme,
  ContrastLevel contrast = ContrastLevel.standard,
}) {
  if (dynamicScheme != null) {
    // Minimal harmonisation: make sure the scheme matches the brightness and
    // keep the semantic error colours from the seed scheme.
    final seed = ColorScheme.fromSeed(
      seedColor: kSeedColor,
      brightness: brightness,
      contrastLevel: contrast.level,
    );
    return dynamicScheme.copyWith(
      brightness: brightness,
      error: seed.error,
      onError: seed.onError,
      errorContainer: seed.errorContainer,
      onErrorContainer: seed.onErrorContainer,
    );
  }
  return ColorScheme.fromSeed(
    seedColor: kSeedColor,
    brightness: brightness,
    contrastLevel: contrast.level,
  );
}

ThemeData buildTheme({
  required Brightness brightness,
  ColorScheme? dynamicScheme,
  required ContrastLevel contrast,
  required DensityLevel density,
  required bool reduceMotion,
}) {
  final s = buildColorScheme(
    brightness: brightness,
    dynamicScheme: dynamicScheme,
    contrast: contrast,
  );
  final tokens = AppTokens.fromScheme(
    s,
    density: density,
    reduceMotion: reduceMotion,
    contrast: contrast,
  );
  final text = buildTextTheme(brightness, color: s.onSurface);
  final compact = density == DensityLevel.compact;
  final visualDensity = compact
      ? const VisualDensity(horizontal: -1, vertical: -1)
      : VisualDensity.standard;
  const target = Size(ComponentStates.minTarget, ComponentStates.minTarget);
  final shapeM = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(tokens.radiusMedium),
  );
  final shapeFull = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(tokens.radiusFull),
  );

  final focusOverlay = ComponentStates.overlay;
  ButtonStyle button({required Color fg, Color? bg, BorderSide? side}) =>
      ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(target),
        tapTargetSize: MaterialTapTargetSize.padded,
        shape: WidgetStatePropertyAll(shapeFull),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: tokens.space6),
        ),
        foregroundColor: ComponentStates.foreground(s, normal: fg),
        backgroundColor: bg == null
            ? null
            : WidgetStateProperty.resolveWith(
                (st) => st.contains(WidgetState.disabled)
                    ? s.onSurface.withValues(alpha: 0.12)
                    : bg,
              ),
        overlayColor: focusOverlay(fg),
        side: side == null
            ? null
            : WidgetStateProperty.resolveWith(
                (st) => st.contains(WidgetState.focused)
                    ? ComponentStates.focusSide(s)
                    : st.contains(WidgetState.disabled)
                    ? BorderSide(color: s.onSurface.withValues(alpha: 0.12))
                    : side,
              ),
      );

  OutlineInputBorder border(Color color, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(tokens.radiusMedium),
    borderSide: BorderSide(color: color, width: w),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: s,
    textTheme: text,
    fontFamily: kFontFamily,
    visualDensity: visualDensity,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    scaffoldBackgroundColor: s.surface,
    extensions: [tokens],
    pageTransitionsTheme: reduceMotion
        ? const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: _NoTransitionsBuilder(),
              TargetPlatform.iOS: _NoTransitionsBuilder(),
              TargetPlatform.macOS: _NoTransitionsBuilder(),
              TargetPlatform.windows: _NoTransitionsBuilder(),
              TargetPlatform.linux: _NoTransitionsBuilder(),
              TargetPlatform.fuchsia: _NoTransitionsBuilder(),
            },
          )
        : null,
    splashFactory: reduceMotion ? NoSplash.splashFactory : null,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 2,
      backgroundColor: s.surface,
      surfaceTintColor: s.surfaceTint,
      foregroundColor: s.onSurface,
      titleTextStyle: text.titleLarge?.copyWith(color: s.onSurface),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      elevation: 2,
      backgroundColor: s.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      indicatorColor: s.secondaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (st) => text.labelMedium?.copyWith(
          color: st.contains(WidgetState.selected)
              ? s.onSurface
              : s.onSurfaceVariant,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (st) => IconThemeData(
          color: st.contains(WidgetState.selected)
              ? s.onSecondaryContainer
              : s.onSurfaceVariant,
        ),
      ),
      overlayColor: focusOverlay(s.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: s.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
        side: BorderSide(color: s.outlineVariant),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: s.surfaceContainerHighest,
      contentPadding: EdgeInsets.symmetric(
        horizontal: tokens.space4,
        vertical: tokens.space3,
      ),
      border: border(s.outline),
      enabledBorder: border(s.outline),
      focusedBorder: border(s.primary, 2),
      errorBorder: border(s.error),
      focusedErrorBorder: border(s.error, 2),
      disabledBorder: border(s.onSurface.withValues(alpha: 0.12)),
      hintStyle: text.bodyLarge?.copyWith(color: s.onSurfaceVariant),
      labelStyle: text.bodyLarge?.copyWith(color: s.onSurfaceVariant),
    ),
    chipTheme: ChipThemeData(
      shape: shapeM,
      side: BorderSide(color: s.outlineVariant),
      backgroundColor: s.surfaceContainerLow,
      selectedColor: s.secondaryContainer,
      disabledColor: s.onSurface.withValues(alpha: 0.12),
      labelStyle: text.labelLarge?.copyWith(color: s.onSurface),
      secondaryLabelStyle: text.labelLarge?.copyWith(
        color: s.onSecondaryContainer,
      ),
      iconTheme: IconThemeData(color: s.onSurfaceVariant, size: 18),
      padding: EdgeInsets.symmetric(horizontal: tokens.space2),
    ),
    listTileTheme: ListTileThemeData(
      minTileHeight: ComponentStates.minTarget,
      iconColor: s.onSurfaceVariant,
      textColor: s.onSurface,
      selectedColor: s.onSecondaryContainer,
      selectedTileColor: s.secondaryContainer,
      contentPadding: EdgeInsets.symmetric(horizontal: tokens.space4),
      shape: shapeM,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: s.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: s.surfaceContainerLow,
      elevation: 3,
      showDragHandle: true,
      dragHandleColor: s.onSurfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(tokens.radiusLarge),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: s.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusLarge),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: s.inverseSurface,
      contentTextStyle: text.bodyMedium?.copyWith(color: s.onInverseSurface),
      actionTextColor: s.inversePrimary,
      shape: shapeM,
    ),
    dividerTheme: DividerThemeData(color: s.outlineVariant, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: button(fg: s.onPrimary, bg: s.primary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: button(fg: s.primary, bg: s.surfaceContainerLow),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: button(
        fg: s.primary,
        side: BorderSide(color: s.outline),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: button(fg: s.primary)),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(target),
        tapTargetSize: MaterialTapTargetSize.padded,
        overlayColor: focusOverlay(s.onSurfaceVariant),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: s.primaryContainer,
      foregroundColor: s.onPrimaryContainer,
      elevation: 3,
      focusElevation: 4,
      hoverElevation: 4,
      highlightElevation: 3,
      focusColor: s.onPrimaryContainer.withValues(alpha: 0.12),
      hoverColor: s.onPrimaryContainer.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusLarge),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      materialTapTargetSize: MaterialTapTargetSize.padded,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: WidgetStateBorderSide.resolveWith(
        (st) => st.contains(WidgetState.selected)
            ? BorderSide.none
            : BorderSide(
                width: 2,
                color: st.contains(WidgetState.disabled)
                    ? s.onSurface.withValues(alpha: 0.38)
                    : s.onSurfaceVariant,
              ),
      ),
      fillColor: WidgetStateProperty.resolveWith((st) {
        if (st.contains(WidgetState.selected)) {
          return st.contains(WidgetState.disabled)
              ? s.onSurface.withValues(alpha: 0.38)
              : s.primary;
        }
        return null;
      }),
      checkColor: WidgetStatePropertyAll(s.onPrimary),
      overlayColor: focusOverlay(s.primary),
    ),
    switchTheme: SwitchThemeData(
      materialTapTargetSize: MaterialTapTargetSize.padded,
      thumbColor: WidgetStateProperty.resolveWith((st) {
        if (st.contains(WidgetState.disabled)) {
          return s.onSurface.withValues(alpha: 0.38);
        }
        return st.contains(WidgetState.selected) ? s.onPrimary : s.outline;
      }),
      trackColor: WidgetStateProperty.resolveWith((st) {
        if (st.contains(WidgetState.disabled)) {
          return s.onSurface.withValues(alpha: 0.12);
        }
        return st.contains(WidgetState.selected)
            ? s.primary
            : s.surfaceContainerHighest;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (st) =>
            st.contains(WidgetState.selected) ? Colors.transparent : s.outline,
      ),
      overlayColor: focusOverlay(s.primary),
    ),
  );
}
