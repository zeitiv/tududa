import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'motion.dart';
import 'tokens.dart';

/// A pane of dark frosted glass: what is behind it shows through, blurred;
/// a hairline edge, lighter along the top, where the room's light lands.
class Glass extends StatelessWidget {
  final Widget child;
  final double radius;
  final double blur;
  final Color fill;
  final EdgeInsetsGeometry padding;
  final bool grouped;
  final bool shadow;
  final ValueListenable<Offset?>? light;

  /// Fades the pane itself. Glass must not sit inside an Opacity: a backdrop
  /// filter there has nothing behind it to blur.
  final double opacity;

  const Glass({
    this.opacity = 1,
    super.key,
    required this.child,
    this.radius = 24,
    this.blur = 26,
    this.fill = const Color(0x9E111318),
    this.padding = EdgeInsets.zero,
    this.grouped = false,
    this.shadow = false,
    this.light,
  });

  @override
  Widget build(BuildContext context) {
    final inner = CustomPaint(
      painter: _GlassPainter(fill, radius, context.accent, light, opacity),
      child: Padding(padding: padding, child: child),
    );
    final sigma = blur * opacity.clamp(0.0, 1.0);
    final filter = ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
    Widget pane = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: grouped
          ? BackdropFilter.grouped(filter: filter, child: inner)
          : BackdropFilter(filter: filter, child: inner),
    );
    if (shadow) {
      pane = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.45 * opacity.clamp(0.0, 1.0)), blurRadius: 48, offset: Offset(0, 22)),
          ],
        ),
        child: pane,
      );
    }
    return pane;
  }
}

class _GlassPainter extends CustomPainter {
  final Color fill;
  final double radius;
  final Color accent;
  final ValueListenable<Offset?>? light;
  final double opacity;

  _GlassPainter(this.fill, this.radius, this.accent, this.light, this.opacity)
      : super(repaint: light);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final o = opacity.clamp(0.0, 1.0);
    if (o <= 0) return;
    canvas.drawRRect(rr, Paint()..color = fill.withValues(alpha: fill.a * o));
    // The light from above.
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.07 * o), const Color(0x00FFFFFF)],
          stops: [0, 0.45],
        ).createShader(rect),
    );
    final edge = rr.deflate(0.5);
    canvas.drawRRect(
      edge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.24 * o), Colors.white.withValues(alpha: 0.07 * o)],
        ).createShader(rect),
    );
    final at = light?.value;
    if (at != null) {
      final glow = RadialGradient(
        colors: [accent.withValues(alpha: 0.9), accent.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: at, radius: 170));
      canvas.drawRRect(
        edge,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..shader = glow,
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..shader = RadialGradient(
            colors: [accent.withValues(alpha: 0.07), accent.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: at, radius: 220)),
      );
    }
  }

  @override
  bool shouldRepaint(_GlassPainter old) =>
      old.fill != fill ||
      old.radius != radius ||
      old.accent != accent ||
      old.light != light ||
      old.opacity != opacity;
}

/// A glass card you can open. Under a pointer it leans toward it and its
/// edge catches the accent; pressed, it sinks. It reports where it stands
/// so what it opens can grow out of it.
class GlassCard extends StatefulWidget {
  final Widget child;
  final void Function(Rect origin)? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final String? label;
  final double opacity;

  const GlassCard({
    this.opacity = 1,
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(18),
    this.radius = 26,
    this.label,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> with SingleTickerProviderStateMixin {
  // Lean about x, lean about y, scale.
  final Springs _s = Springs([0, 0, 1], spec: Spec.bouncy);
  final ValueNotifier<Offset?> _light = ValueNotifier(null);
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _down = false;
  bool _focus = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
  }

  void _go() {
    if (Motion.reduced) {
      _s.jump(_s.target);
      setState(() {});
      return;
    }
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration now) {
    final dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    if (!_s.step(dt)) _ticker.stop();
    setState(() {});
  }

  void _hover(Offset local, Size size) {
    _light.value = local;
    _s.target[0] = -((local.dy / size.height) - 0.5) * 0.09;
    _s.target[1] = ((local.dx / size.width) - 0.5) * 0.09;
    if (!_down) _s.target[2] = 1.012;
    _go();
  }

  void _leave() {
    _light.value = null;
    _s.target[0] = 0;
    _s.target[1] = 0;
    _s.target[2] = _down ? 0.965 : 1;
    _go();
  }

  void _press(bool down) {
    _down = down;
    _s.target[2] = down ? 0.965 : 1;
    _go();
  }

  void _fire() {
    if (widget.onTap == null) return;
    tick();
    widget.onTap!(rectOf(context));
  }

  @override
  void dispose() {
    _ticker.dispose();
    _light.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..rotateX(_s.x[0])
      ..rotateY(_s.x[1])
      ..scaleByDouble(_s.x[2], _s.x[2], 1, 1);
    return Semantics(
      button: widget.onTap != null,
      label: widget.label,
      child: FocusableActionDetector(
        enabled: widget.onTap != null,
        mouseCursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
        onShowFocusHighlight: (f) => setState(() => _focus = f),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _fire()),
        },
        child: MouseRegion(
          onHover: (e) => _hover(e.localPosition, context.size ?? const Size(1, 1)),
          onExit: (_) => _leave(),
          child: Listener(
            onPointerDown: (_) => _press(true),
            onPointerUp: (_) => _press(false),
            onPointerCancel: (_) => _press(false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap == null ? null : _fire,
              child: Transform(
                alignment: Alignment.center,
                transform: m,
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.radius),
                    border: _focus ? Border.all(color: context.accent, width: 1.5) : null,
                  ),
                  child: Glass(
                    radius: widget.radius,
                    grouped: true,
                    light: _light,
                    opacity: widget.opacity,
                    padding: widget.padding,
                    fill: const Color(0x8A101216),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
