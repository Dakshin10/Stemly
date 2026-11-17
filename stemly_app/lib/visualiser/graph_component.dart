import 'package:flutter/material.dart';

class GraphWidget extends StatelessWidget {
  final double a;
  final double b;
  final double c;

  const GraphWidget({
    super.key,
    required this.a,
    required this.b,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        color: const Color(0xFFFAFAFA),
        child: CustomPaint(
          painter: GraphPainter(
            a: a.isFinite ? a : 1.0,
            b: b.isFinite ? b : 0.0,
            c: c.isFinite ? c : 0.0,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class GraphPainter extends CustomPainter {
  final double a;
  final double b;
  final double c;

  // Cached Paint objects to avoid allocations in paint()
  static final Paint _axisPaint = Paint()
    ..color = const Color(0xDE000000)
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke;
  static final Paint _gridPaint = Paint()
    ..color = const Color(0x26000000)
    ..strokeWidth = 0.8
    ..style = PaintingStyle.stroke;
  static final Paint _curvePaint = Paint()
    ..color = const Color(0xFF1976D2)
    ..strokeWidth = 2.5
    ..style = PaintingStyle.stroke;
  static final Paint _vertexPaint = Paint()..color = const Color(0xFFE53935);

  static final TextPainter _cachedTextPainter = TextPainter(
    textDirection: TextDirection.ltr,
  );

  GraphPainter({required this.a, required this.b, required this.c});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2.0, h / 2.0);

    // 1. Draw Axes
    canvas.drawLine(
      Offset(0, center.dy),
      Offset(w, center.dy),
      _axisPaint,
    ); // X-axis
    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, h),
      _axisPaint,
    ); // Y-axis

    // Grid lines (every 24 pixels)
    const double gridSpacing = 24.0;
    for (double x = center.dx; x < w; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), _gridPaint);
    }
    for (double x = center.dx; x > 0; x -= gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), _gridPaint);
    }
    for (double y = center.dy; y < h; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(w, y), _gridPaint);
    }
    for (double y = center.dy; y > 0; y -= gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(w, y), _gridPaint);
    }

    // 2. Plot Function: y = ax^2 + bx + c
    final path = Path();
    bool first = true;
    const double scale = 24.0; // 24 pixels per math unit

    for (double px = 0; px <= w; px += 2.0) {
      final x = (px - center.dx) / scale;
      final y = (a * x * x) + (b * x) + c;
      final py = center.dy - (y * scale);

      // Clamp py within reasonable bounds to prevent path rendering overflow
      final clampedPy = py.clamp(-100.0, h + 100.0);

      if (first) {
        path.moveTo(px, clampedPy);
        first = false;
      } else {
        path.lineTo(px, clampedPy);
      }
    }

    canvas.drawPath(path, _curvePaint);

    // Vertex marker: x_v = -b / (2a) if a != 0
    if (a.abs() > 1e-4) {
      final xv = -b / (2.0 * a);
      final yv = (a * xv * xv) + (b * xv) + c;
      final pvx = center.dx + xv * scale;
      final pvy = center.dy - yv * scale;
      if (pvx >= 0 && pvx <= w && pvy >= 0 && pvy <= h) {
        canvas.drawCircle(Offset(pvx, pvy), 4.5, _vertexPaint);
      }
    }

    // 3. Draw Equation Text Header
    final signB = b >= 0 ? "+" : "-";
    final signC = c >= 0 ? "+" : "-";
    final eq =
        "y = ${a.toStringAsFixed(1)}x² $signB ${b.abs().toStringAsFixed(1)}x $signC ${c.abs().toStringAsFixed(1)}";
    _drawText(
      canvas,
      eq,
      16,
      16,
      size: 14,
      bold: true,
      color: const Color(0xFF1565C0),
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    double x,
    double y, {
    double size = 11,
    bool bold = false,
    Color color = Colors.black87,
  }) {
    _cachedTextPainter.text = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      ),
    );
    _cachedTextPainter.layout();
    _cachedTextPainter.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) {
    return oldDelegate.a != a || oldDelegate.b != b || oldDelegate.c != c;
  }
}
