import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'motion.dart';
import 'tokens.dart';

/// The room everything floats in: near-black, a dot grid, and two slow
/// fields of light for the glass to catch. It moves a couple of pixels a
/// second and is redrawn a dozen times a second, so it costs next to nothing.
class Backdrop extends StatefulWidget {
  const Backdrop({super.key});

  @override
  State<Backdrop> createState() => _BackdropState();
}

class _BackdropState extends State<Backdrop> {
  final ValueNotifier<double> _t = ValueNotifier(0);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (!Motion.reduced) {
      _timer = Timer.periodic(const Duration(milliseconds: 80), (_) => _t.value += 0.08);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _BackdropPainter(_t, context.accent),
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  final ValueNotifier<double> t;
  final Color accent;
  _BackdropPainter(this.t, this.accent) : super(repaint: t);

  Float32List? _grid;
  Size? _gridFor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = Tk.bg);
    final s = t.value;
    final big = math.max(size.width, size.height);

    void field(Offset at, double radius, Color color) {
      canvas.drawCircle(
        at,
        radius,
        Paint()
          ..shader = ui.Gradient.radial(at, radius, [color, color.withValues(alpha: 0)]),
      );
    }

    field(
      Offset(size.width * (0.18 + 0.05 * math.sin(s * 0.021)),
          size.height * (0.16 + 0.05 * math.cos(s * 0.017))),
      big * 0.62,
      accent.withValues(alpha: 0.17),
    );
    field(
      Offset(size.width * (0.86 + 0.05 * math.cos(s * 0.015)),
          size.height * (0.78 + 0.06 * math.sin(s * 0.019))),
      big * 0.58,
      const Color(0xFF6A5BFF).withValues(alpha: 0.12),
    );
    field(
      Offset(size.width * (0.62 + 0.04 * math.sin(s * 0.012 + 2)), size.height * 0.34),
      big * 0.34,
      const Color(0xFFFF5A47).withValues(alpha: 0.05),
    );

    if (_gridFor != size) {
      const pitch = 26.0;
      final cols = (size.width / pitch).ceil() + 1;
      final rows = (size.height / pitch).ceil() + 1;
      final pts = Float32List(cols * rows * 2);
      var i = 0;
      for (var y = 0; y < rows; y++) {
        for (var x = 0; x < cols; x++) {
          pts[i++] = x * pitch + 8;
          pts[i++] = y * pitch + 8;
        }
      }
      _grid = pts;
      _gridFor = size;
    }
    canvas.drawRawPoints(
      ui.PointMode.points,
      _grid!,
      Paint()
        ..color = const Color(0x17FFFFFF)
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.accent != accent;
}
