import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// A spring: stiffness and damping for a mass of one.
class Spec {
  final double k;
  final double c;
  const Spec(this.k, this.c);

  /// Quick and settled, for presses and toggles.
  static const snappy = Spec(560, 40);

  /// The default: things that move across the screen.
  static const fluid = Spec(260, 27);

  /// A little overshoot, for things that arrive.
  static const bouncy = Spec(340, 21);

  /// Slow and heavy, for depth.
  static const gentle = Spec(120, 22);
}

/// Motion is switched off in one place: by the system's setting or the app's.
class Motion {
  Motion._();
  static bool reduced = false;
}

/// A handful of values on springs, stepped by hand so a target can change
/// mid-flight and a finger can take a value over without a jump.
class Springs {
  final List<double> x;
  final List<double> v;
  final List<double> target;
  Spec spec;

  Springs(List<double> start, {this.spec = Spec.fluid})
      : x = List.of(start),
        v = List.filled(start.length, 0),
        target = List.of(start);

  void jump(List<double> to) {
    for (var i = 0; i < x.length; i++) {
      x[i] = to[i];
      target[i] = to[i];
      v[i] = 0;
    }
  }

  /// Advances by [dt] seconds. Returns true while anything still moves.
  bool step(double dt) {
    if (Motion.reduced) {
      for (var i = 0; i < x.length; i++) {
        x[i] = target[i];
        v[i] = 0;
      }
      return false;
    }
    var left = dt.clamp(0.0, 0.064);
    var moving = false;
    while (left > 0) {
      final h = left > 1 / 240 ? 1 / 240 : left;
      left -= h;
      for (var i = 0; i < x.length; i++) {
        final a = -spec.k * (x[i] - target[i]) - spec.c * v[i];
        v[i] += a * h;
        x[i] += v[i] * h;
      }
    }
    for (var i = 0; i < x.length; i++) {
      final scale = target[i].abs() > 4 ? 0.2 : 0.001;
      if ((x[i] - target[i]).abs() > scale || v[i].abs() > scale * 12) {
        moving = true;
      } else {
        x[i] = target[i];
        v[i] = 0;
      }
    }
    return moving;
  }

  bool get atRest {
    for (var i = 0; i < x.length; i++) {
      if (x[i] != target[i] || v[i] != 0) return false;
    }
    return true;
  }
}

/// Follows [value] on a spring and rebuilds with where it is.
class SpringBuilder extends StatefulWidget {
  final double value;
  final double? from;
  final Spec spec;
  final Widget? child;
  final Widget Function(BuildContext context, double value, Widget? child) builder;

  const SpringBuilder({
    super.key,
    required this.value,
    required this.builder,
    this.from,
    this.spec = Spec.fluid,
    this.child,
  });

  @override
  State<SpringBuilder> createState() => _SpringBuilderState();
}

class _SpringBuilderState extends State<SpringBuilder> with SingleTickerProviderStateMixin {
  late final Springs _s = Springs([widget.from ?? widget.value], spec: widget.spec);
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    _s.target[0] = widget.value;
    if (!_s.atRest) _start();
  }

  @override
  void didUpdateWidget(SpringBuilder old) {
    super.didUpdateWidget(old);
    _s.spec = widget.spec;
    if (widget.value != _s.target[0]) {
      _s.target[0] = widget.value;
      _start();
    }
  }

  void _start() {
    if (Motion.reduced) {
      _s.jump([_s.target[0]]);
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
    final moving = _s.step(dt);
    if (!moving) _ticker.stop();
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _s.x[0], widget.child);
}

void tick() {
  if (!kIsWeb) HapticFeedback.selectionClick();
}

void thud() {
  if (!kIsWeb) HapticFeedback.mediumImpact();
}

/// Anything you can press: it gives under the finger and springs back,
/// lifts a touch under a pointer, and works from the keyboard.
class Pressable extends StatefulWidget {
  final Widget? child;
  final Widget Function(BuildContext context, bool hovered, bool pressed)? builder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  /// How much it grows under a pointer; rows and wide things stay put.
  final double lift;
  final String? label;
  final BorderRadius radius;

  const Pressable({
    this.lift = 1,
    super.key,
    this.child,
    this.builder,
    required this.onTap,
    this.onLongPress,
    this.scale = 0.95,
    this.label,
    this.radius = const BorderRadius.all(Radius.circular(14)),
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  bool _hover = false;
  bool _focus = false;

  void _fire() {
    if (widget.onTap == null) return;
    tick();
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final target = !enabled
        ? 1.0
        : _down
            ? widget.scale
            : _hover
                ? widget.lift
                : 1.0;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onShowHoverHighlight: (h) => setState(() => _hover = h),
        onShowFocusHighlight: (f) => setState(() => _focus = f),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _fire()),
        },
        child: Listener(
          onPointerDown: (_) => setState(() => _down = true),
          onPointerUp: (_) => setState(() => _down = false),
          onPointerCancel: (_) => setState(() => _down = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? _fire : null,
            onLongPress: widget.onLongPress,
            child: SpringBuilder(
              value: target,
              spec: _down ? Spec.snappy : Spec.bouncy,
              builder: (context, v, child) => Transform.scale(scale: v, child: child),
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: widget.radius,
                  border: _focus
                      ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5)
                      : null,
                ),
                child: widget.builder != null
                    ? widget.builder!(context, _hover, _down)
                    : widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lets its child arrive: it rises, sharpens and settles, a beat after the
/// one before it.
class Enter extends StatefulWidget {
  final Widget child;
  final int i;
  final double dy;

  /// With a builder the child is not faded here: it gets the progress and
  /// fades itself (glass has to, see [Glass.opacity]).
  final Widget Function(BuildContext context, double v)? builder;
  const Enter({super.key, this.child = const SizedBox(), this.i = 0, this.dy = 18, this.builder});

  @override
  State<Enter> createState() => _EnterState();
}

class _EnterState extends State<Enter> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    if (Motion.reduced) {
      _shown = true;
    } else {
      Future.delayed(Duration(milliseconds: 30 + 45 * widget.i.clamp(0, 12)), () {
        if (mounted) setState(() => _shown = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SpringBuilder(
      value: _shown ? 1 : 0,
      spec: Spec.fluid,
      child: widget.child,
      builder: (context, v, child) {
        if (widget.builder != null) {
          return Transform.translate(
            offset: Offset(0, (1 - v) * widget.dy),
            child: widget.builder!(context, v.clamp(0.0, 1.0)),
          );
        }
        if (v >= 1) return child!;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - v) * widget.dy),
            child: Transform.scale(scale: 0.97 + 0.03 * v, child: child),
          ),
        );
      },
    );
  }
}

Rect rectOf(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return Rect.zero;
  return box.localToGlobal(Offset.zero) & box.size;
}
