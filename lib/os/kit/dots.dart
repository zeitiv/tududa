import 'package:flutter/material.dart';
import 'motion.dart';
import 'tokens.dart';

/// A 5 × 7 dot-matrix face of our own, for readouts: the clock, counts.
const _glyphs = <String, String>{
  '0': '01110|10001|10011|10101|11001|10001|01110',
  '1': '00100|01100|00100|00100|00100|00100|01110',
  '2': '01110|10001|00001|00010|00100|01000|11111',
  '3': '11110|00001|00001|01110|00001|00001|11110',
  '4': '00010|00110|01010|10010|11111|00010|00010',
  '5': '11111|10000|11110|00001|00001|10001|01110',
  '6': '00110|01000|10000|11110|10001|10001|01110',
  '7': '11111|00001|00010|00100|01000|01000|01000',
  '8': '01110|10001|10001|01110|10001|10001|01110',
  '9': '01110|10001|10001|01111|00001|00010|01100',
  'A': '01110|10001|10001|11111|10001|10001|10001',
  'B': '11110|10001|10001|11110|10001|10001|11110',
  'C': '01110|10001|10000|10000|10000|10001|01110',
  'D': '11100|10010|10001|10001|10001|10010|11100',
  'E': '11111|10000|10000|11110|10000|10000|11111',
  'F': '11111|10000|10000|11110|10000|10000|10000',
  'G': '01110|10001|10000|10111|10001|10001|01111',
  'H': '10001|10001|10001|11111|10001|10001|10001',
  'I': '01110|00100|00100|00100|00100|00100|01110',
  'J': '00111|00010|00010|00010|00010|10010|01100',
  'K': '10001|10010|10100|11000|10100|10010|10001',
  'L': '10000|10000|10000|10000|10000|10000|11111',
  'M': '10001|11011|10101|10101|10001|10001|10001',
  'N': '10001|11001|10101|10011|10001|10001|10001',
  'O': '01110|10001|10001|10001|10001|10001|01110',
  'P': '11110|10001|10001|11110|10000|10000|10000',
  'Q': '01110|10001|10001|10001|10101|10010|01101',
  'R': '11110|10001|10001|11110|10100|10010|10001',
  'S': '01111|10000|10000|01110|00001|00001|11110',
  'T': '11111|00100|00100|00100|00100|00100|00100',
  'U': '10001|10001|10001|10001|10001|10001|01110',
  'V': '10001|10001|10001|10001|10001|01010|00100',
  'W': '10001|10001|10001|10101|10101|11011|10001',
  'X': '10001|10001|01010|00100|01010|10001|10001',
  'Y': '10001|10001|01010|00100|00100|00100|00100',
  'Z': '11111|00001|00010|00100|01000|10000|11111',
  ':': '00000|00100|00100|00000|00100|00100|00000',
  '.': '00000|00000|00000|00000|00000|00100|00100',
  '-': '00000|00000|00000|01110|00000|00000|00000',
  '/': '00001|00001|00010|00100|01000|10000|10000',
  '%': '11001|11010|00010|00100|01000|01011|10011',
  '+': '00000|00100|00100|11111|00100|00100|00000',
  ' ': '00000|00000|00000|00000|00000|00000|00000',
};

bool hasGlyph(String ch) => _glyphs.containsKey(ch);

/// Which of a string's dots are lit, column by column: 6 columns a glyph
/// (5 and a gap), 7 rows.
List<bool> dotsOf(String text) {
  final up = text.toUpperCase();
  final cols = up.length * 6 - (up.isEmpty ? 0 : 1);
  final out = List<bool>.filled(cols * 7, false);
  for (var g = 0; g < up.length; g++) {
    final rows = (_glyphs[up[g]] ?? _glyphs[' ']!).split('|');
    for (var r = 0; r < 7; r++) {
      for (var c = 0; c < 5; c++) {
        if (rows[r][c] == '1') out[(g * 6 + c) * 7 + r] = true;
      }
    }
  }
  return out;
}

/// Text on a dot matrix. When it changes, the dots that differ fade over
/// in a short sweep from the left.
class DotText extends StatefulWidget {
  final String text;
  final double dot;
  final double gap;
  final Color color;
  final bool ghost;

  const DotText(
    this.text, {
    super.key,
    this.dot = 3,
    this.gap = 1.4,
    this.color = Tk.ink,
    this.ghost = true,
  });

  @override
  State<DotText> createState() => _DotTextState();
}

class _DotTextState extends State<DotText> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: 1,
  );
  late String _from = widget.text;

  @override
  void didUpdateWidget(DotText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _from = old.text;
      if (Motion.reduced) {
        _c.value = 1;
      } else {
        _c.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.text.length;
    final cols = n * 6 - (n == 0 ? 0 : 1);
    final pitch = widget.dot + widget.gap;
    return Semantics(
      label: widget.text,
      child: CustomPaint(
        size: Size(cols * pitch - widget.gap, 7 * pitch - widget.gap),
        painter: _DotPainter(
          dotsOf(_from.padRight(n).substring(0, n)),
          dotsOf(widget.text),
          _c,
          widget.dot,
          pitch,
          widget.color,
          widget.ghost,
        ),
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  final List<bool> from;
  final List<bool> to;
  final Animation<double> t;
  final double dot;
  final double pitch;
  final Color color;
  final bool ghost;

  _DotPainter(this.from, this.to, this.t, this.dot, this.pitch, this.color, this.ghost)
      : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    final cols = to.length ~/ 7;
    final paint = Paint();
    final r = dot / 2;
    for (var c = 0; c < cols; c++) {
      // Each column changes a little after the one before it.
      final local = ((t.value * 1.6) - (cols <= 1 ? 0 : c / cols * 0.6)).clamp(0.0, 1.0);
      for (var row = 0; row < 7; row++) {
        final i = c * 7 + row;
        final a = from[i] ? 1.0 : 0.0;
        final b = to[i] ? 1.0 : 0.0;
        final lit = a + (b - a) * local;
        final alpha = ghost ? 0.09 + 0.91 * lit : lit;
        if (alpha <= 0.001) continue;
        paint.color = color.withValues(alpha: color.a * alpha);
        canvas.drawCircle(Offset(c * pitch + r, row * pitch + r), r, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotPainter old) =>
      old.to != to || old.from != from || old.color != color || old.dot != dot;
}

/// A row of dots as a gauge: so many lit of so many.
class DotBar extends StatelessWidget {
  final double value;
  final int count;
  final double dot;
  final Color? color;
  const DotBar(this.value, {super.key, this.count = 12, this.dot = 4, this.color});

  @override
  Widget build(BuildContext context) {
    final on = color ?? context.accent;
    return SpringBuilder(
      value: value.clamp(0.0, 1.0),
      from: 0,
      spec: Spec.gentle,
      builder: (context, v, _) => CustomPaint(
        size: Size(count * dot * 2 - dot, dot),
        painter: _BarPainter(v, count, dot, on),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  final double v;
  final int count;
  final double dot;
  final Color on;
  _BarPainter(this.v, this.count, this.dot, this.on);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    for (var i = 0; i < count; i++) {
      final lit = (v * count - i).clamp(0.0, 1.0);
      p.color = Color.lerp(const Color(0x24FFFFFF), on, lit)!;
      canvas.drawCircle(Offset(i * dot * 2 + dot / 2, dot / 2), dot / 2, p);
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.v != v || old.on != on || old.count != count;
}
