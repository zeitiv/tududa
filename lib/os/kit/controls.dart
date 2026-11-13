import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'glass.dart';
import 'motion.dart';
import 'tokens.dart';

/// A small tracked label in capitals, like the legend on an instrument.
class Label extends StatelessWidget {
  final String text;
  final Color? color;
  final double size;
  const Label(this.text, {super.key, this.color, this.size = 10.5});

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: mono(size, color: color ?? Tk.ink3),
      );
}

class OsButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool primary;
  final bool danger;
  final bool busy;

  const OsButton(
    this.label, {
    super.key,
    this.icon,
    required this.onTap,
    this.primary = false,
    this.danger = false,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = primary
        ? Tk.bg
        : danger
            ? Tk.signal
            : Tk.ink;
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: Pressable(
        onTap: busy ? null : onTap,
        label: label,
        radius: BorderRadius.circular(14),
        builder: (context, hover, down) => AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: primary
                ? context.accent
                : Colors.white.withValues(alpha: hover ? 0.1 : 0.06),
            borderRadius: BorderRadius.circular(14),
            border: primary ? null : Border.all(color: Tk.rule),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              else if (icon != null)
                Icon(icon, size: 17, color: fg),
              if (busy || icon != null) const SizedBox(width: 9),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: sans(14.5, w: 600, color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OsIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  final double size;
  final Color? color;
  final bool filled;

  const OsIconButton(
    this.icon, {
    super.key,
    required this.onTap,
    required this.tooltip,
    this.size = 44,
    this.color,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        label: tooltip,
        scale: 0.88,
        lift: 1.06,
        radius: BorderRadius.circular(size / 2),
        builder: (context, hover, down) => AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: hover ? 0.12 : (filled ? 0.06 : 0)),
          ),
          child: Icon(icon, size: size * 0.44, color: color ?? Tk.ink2),
        ),
      ),
    );
  }
}

class OsField extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final String? label;
  final IconData? icon;
  final ValueChanged<String>? onSubmit;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final int minLines;
  final bool autofocus;
  final bool obscure;
  final FocusNode? focusNode;
  final TextInputType? keyboard;
  final Widget? trailing;
  final bool big;
  final Iterable<String>? autofill;

  const OsField({
    super.key,
    required this.controller,
    this.hint,
    this.label,
    this.icon,
    this.onSubmit,
    this.onChanged,
    this.maxLines = 1,
    this.minLines = 1,
    this.autofocus = false,
    this.obscure = false,
    this.focusNode,
    this.keyboard,
    this.trailing,
    this.big = false,
    this.autofill,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c),
        );
    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      obscureText: obscure,
      maxLines: obscure ? 1 : maxLines,
      minLines: minLines,
      keyboardType: keyboard,
      autofillHints: autofill,
      textInputAction: maxLines > 1 ? TextInputAction.newline : TextInputAction.done,
      onSubmitted: onSubmit,
      onChanged: onChanged,
      style: sans(big ? 18 : 15.5, w: big ? 500 : 400, height: 1.35),
      cursorWidth: 1.5,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: sans(big ? 18 : 15.5, color: Tk.ink3),
        isDense: true,
        filled: true,
        fillColor: Tk.fill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        prefixIcon: icon == null ? null : Icon(icon, size: 18, color: Tk.ink3),
        prefixIconConstraints: const BoxConstraints(minWidth: 42),
        suffixIcon: trailing,
        suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        enabledBorder: border(Tk.rule),
        focusedBorder: border(context.accent.withValues(alpha: 0.8)),
      ),
    );
    if (label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(padding: const EdgeInsets.only(left: 2, bottom: 7), child: Label(label!)),
        field,
      ],
    );
  }
}

/// A segmented switch whose pill slides between the choices on a spring.
class OsSeg<T> extends StatelessWidget {
  final Map<T, String> items;
  final T value;
  final ValueChanged<T> onChanged;
  const OsSeg({super.key, required this.items, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final keys = items.keys.toList();
    final index = keys.indexOf(value).clamp(0, keys.length - 1);
    return Container(
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Tk.fill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Tk.rule),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth / keys.length;
          return Stack(
            children: [
              SpringBuilder(
                value: index.toDouble(),
                spec: Spec.bouncy,
                builder: (context, v, _) => Positioned(
                  left: v * w,
                  top: 0,
                  bottom: 0,
                  width: w,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final k in keys)
                    Expanded(
                      child: Pressable(
                        onTap: () => onChanged(k),
                        label: items[k],
                        scale: 0.94,
                        radius: BorderRadius.circular(11),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 160),
                            style: sans(13.5, w: k == value ? 600 : 450,
                                color: k == value ? Tk.ink : Tk.ink3),
                            child: Text(items[k]!, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class OsChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool on;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const OsChip(this.label, {super.key, this.icon, this.on = false, this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final fg = on ? Tk.bg : Tk.ink2;
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: Pressable(
        onTap: onTap,
        onLongPress: onLongPress,
        label: label,
        scale: 0.93,
        radius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: on ? context.accent : Tk.fill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: on ? Colors.transparent : Tk.rule),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 15, color: fg), const SizedBox(width: 7)],
              Text(label, style: sans(13.5, w: on ? 600 : 500, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The check: a ring that fills and draws its tick with a little overshoot.
class Check extends StatelessWidget {
  final bool value;
  final VoidCallback? onTap;
  final double size;
  final Color? color;
  final String? label;
  const Check({super.key, required this.value, this.onTap, this.size = 24, this.color, this.label});

  @override
  Widget build(BuildContext context) {
    final paintBox = SpringBuilder(
      value: value ? 1 : 0,
      spec: Spec.bouncy,
      builder: (context, v, _) => CustomPaint(
        size: Size.square(size),
        painter: _CheckPainter(v, color ?? context.accent),
      ),
    );
    if (onTap == null) return paintBox;
    return Semantics(
      checked: value,
      child: Pressable(
        onTap: onTap,
        label: label,
        scale: 0.8,
        radius: BorderRadius.circular(22),
        child: SizedBox(width: 44, height: 44, child: Center(child: paintBox)),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double v;
  final Color color;
  _CheckPainter(this.v, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 1;
    final t = v.clamp(0.0, 1.0);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Color.lerp(const Color(0x66FFFFFF), color, t)!,
    );
    if (v <= 0.01) return;
    canvas.drawCircle(c, r * v.clamp(0.0, 1.15), Paint()..color = color.withValues(alpha: t));
    final s = size.width;
    final path = Path()
      ..moveTo(s * 0.29, s * 0.52)
      ..lineTo(s * 0.44, s * 0.66)
      ..lineTo(s * 0.72, s * 0.36);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * t),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.095
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Tk.bg,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.v != v || old.color != color;
}

/// Progress as a ring on a dotted track.
class Ring extends StatelessWidget {
  final double progress;
  final double size;
  final double stroke;
  final Widget? child;
  const Ring(this.progress, {super.key, this.size = 44, this.stroke = 3, this.child});

  @override
  Widget build(BuildContext context) {
    return SpringBuilder(
      value: progress.clamp(0.0, 1.0),
      from: 0,
      spec: Spec.gentle,
      child: child,
      builder: (context, v, child) => CustomPaint(
        painter: _RingPainter(v, stroke, context.accent),
        child: SizedBox.square(dimension: size, child: Center(child: child)),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double v;
  final double stroke;
  final Color color;
  _RingPainter(this.v, this.stroke, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - stroke;
    final n = (2 * math.pi * r / (stroke * 2.6)).round().clamp(12, 90);
    final dot = Paint()..color = const Color(0x2EFFFFFF);
    for (var i = 0; i < n; i++) {
      final a = -math.pi / 2 + i / n * 2 * math.pi;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * r, stroke * 0.42, dot);
    }
    if (v <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * v.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.v != v || old.color != color;
}

/// A status lamp. Live, it breathes.
class Lamp extends StatefulWidget {
  final Color color;
  final bool pulse;
  final double size;
  const Lamp(this.color, {super.key, this.pulse = false, this.size = 7});

  @override
  State<Lamp> createState() => _LampState();
}

class _LampState extends State<Lamp> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  void _sync() {
    if (widget.pulse && !Motion.reduced) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(Lamp old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return SizedBox.square(
          dimension: widget.size * 2.4,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.pulse && t > 0)
                Container(
                  width: widget.size * (1 + 1.4 * t),
                  height: widget.size * (1 + 1.4 * t),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: 0.35 * (1 - t)),
                  ),
                ),
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// What a list shows when it has nothing: a quiet readout and one line.
class Empty extends StatelessWidget {
  final String title;
  final String? hint;
  final Widget? action;
  const Empty(this.title, {super.key, this.hint, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, textAlign: TextAlign.center, style: sans(17, w: 600, wdth: 108)),
            if (hint != null) ...[
              const SizedBox(height: 8),
              Text(hint!, textAlign: TextAlign.center, style: sans(14, color: Tk.ink3, height: 1.4)),
            ],
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

/// Rows standing in for content that is on its way.
class Loading extends StatefulWidget {
  final int rows;
  const Loading({super.key, this.rows = 5});

  @override
  State<Loading> createState() => _LoadingState();
}

class _LoadingState extends State<Loading> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    if (!Motion.reduced) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 0.8).animate(_c),
      child: Column(
        children: [
          for (var i = 0; i < widget.rows; i++)
            Container(
              height: 52,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: Tk.fill, borderRadius: BorderRadius.circular(14)),
            ),
        ],
      ),
    );
  }
}

/// A sheet: from the bottom edge on a phone, a floating pane on a wide
/// screen. It arrives on a spring-shaped curve.
Future<T?> showOsSheet<T>(BuildContext context, WidgetBuilder builder, {double width = 540}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0x8C000000),
    transitionDuration: Duration(milliseconds: Motion.reduced ? 1 : 420),
    pageBuilder: (context, _, _) {
      final wide = context.isWide;
      final mq = MediaQuery.of(context);
      return Align(
        alignment: wide ? Alignment.center : Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.only(
            left: wide ? 24 : 8,
            right: wide ? 24 : 8,
            top: mq.padding.top + 24,
            bottom: mq.viewInsets.bottom + (wide ? 24 : 8 + mq.padding.bottom),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width),
            child: Material(
              type: MaterialType.transparency,
              child: Glass(
                radius: 28,
                blur: 34,
                shadow: true,
                fill: const Color(0xD912141A),
                child: Builder(builder: builder),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, anim, _, child) {
      final wide = context.isWide;
      final t = CurvedAnimation(
        parent: anim,
        curve: const _SpringCurve(),
        reverseCurve: Curves.easeInCubic,
      );
      return AnimatedBuilder(
        animation: t,
        child: child,
        builder: (context, child) {
          final v = t.value;
          // No fade on the pane: glass inside an Opacity cannot blur.
          return wide
              ? Transform.translate(
                  offset: Offset(0, (1 - v) * 60),
                  child: Transform.scale(scale: 0.9 + 0.1 * v, child: child),
                )
              : FractionalTranslation(translation: Offset(0, (1 - v) * 1.05), child: child);
        },
      );
    },
  );
}

/// A critically-soft spring as a curve: a quick rise, a 3% overshoot, settle.
class _SpringCurve extends Curve {
  const _SpringCurve();
  @override
  double transformInternal(double t) {
    const zeta = 0.72;
    const omega = 13.0;
    final wd = omega * math.sqrt(1 - zeta * zeta);
    final e = math.exp(-zeta * omega * t);
    return 1 - e * (math.cos(wd * t) + (zeta * omega / wd) * math.sin(wd * t));
  }
}

/// The frame every sheet shares: a title, its content, its buttons.
class SheetBody extends StatelessWidget {
  final String title;
  final String? label;
  final List<Widget> children;
  final List<Widget> actions;
  const SheetBody({
    super.key,
    required this.title,
    this.label,
    required this.children,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (label != null) ...[Label(label!), const SizedBox(height: 5)],
                    Text(title, style: sans(21, w: 650, wdth: 110)),
                  ],
                ),
              ),
              OsIconButton(
                Icons.close_rounded,
                onTap: () => Navigator.of(context).maybePop(),
                tooltip: MaterialLocalizations.of(context).closeButtonLabel,
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 22),
            Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 10, children: actions),
          ],
        ],
      ),
    );
  }
}

/// A switch: the knob crosses on a spring and the track takes the accent.
class OsSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  const OsSwitch({super.key, required this.value, required this.onChanged, required this.label});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: Pressable(
        onTap: () => onChanged(!value),
        label: label,
        scale: 0.92,
        radius: BorderRadius.circular(16),
        child: SizedBox(
          width: 52,
          height: 44,
          child: Center(
            child: SpringBuilder(
              value: value ? 1 : 0,
              spec: Spec.bouncy,
              builder: (context, v, _) => Container(
                width: 50,
                height: 30,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Color.lerp(const Color(0x24FFFFFF), context.accent, v.clamp(0.0, 1.0)),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Align(
                  alignment: Alignment(-1 + 2 * v.clamp(-0.08, 1.08), 0),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color.lerp(Tk.ink, Tk.bg, v.clamp(0.0, 1.0)),
                    ),
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

/// A heading inside a pane, with a hairline running out from it.
class Section extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const Section(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Row(
        children: [
          Label(text),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 1, color: Tk.rule)),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}
