import 'package:flutter/material.dart';

/// Solid tonal surface with an outline: the app's one card/panel container.
///
/// Replaces the former blurred "glass" panels. [color] defaults to
/// `surfaceContainerLow`; pass a pre-blended opaque colour for tinted cards.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.padding = EdgeInsets.zero,
    this.margin,
    this.width,
    this.height,
    this.color,
  });

  final Widget child;
  final BorderRadiusGeometry borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainerLow,
        borderRadius: borderRadius,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }
}
