import 'package:flutter/material.dart';

class GenericDiagramWidget extends StatelessWidget {
  final List<Map<String, dynamic>> primitives;
  final Color baseColor;

  const GenericDiagramWidget({
    super.key,
    required this.primitives,
    this.baseColor = const Color(0xFF1976D2),
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        height: 300,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: CustomPaint(
          painter: DiagramPainter(primitives, baseColor),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class DiagramPainter extends CustomPainter {
  final List<Map<String, dynamic>> primitives;
  final Color baseColor;

  // Cached Paint objects to avoid allocations in paint()
  static final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;
  static final Paint _fillPaint = Paint()..style = PaintingStyle.fill;
  static final TextPainter _cachedTextPainter = TextPainter(
    textDirection: TextDirection.ltr,
  );

  DiagramPainter(this.primitives, this.baseColor);

  @override
  void paint(Canvas canvas, Size size) {
    _strokePaint.color = baseColor;
    _fillPaint.color = baseColor.withValues(alpha: 0.2);

    final double scaleX = size.width / 100.0;
    final double scaleY = size.height / 100.0;

    for (final p in primitives) {
      final String type = p["type"]?.toString() ?? "unknown";

      if (type == "rect") {
        final double x = (p["x"] as num? ?? 0).toDouble() * scaleX;
        final double y = (p["y"] as num? ?? 0).toDouble() * scaleY;
        final double w = (p["w"] as num? ?? 10).toDouble() * scaleX;
        final double h = (p["h"] as num? ?? 10).toDouble() * scaleY;

        final rect = Rect.fromLTWH(x, y, w, h);
        canvas.drawRect(rect, _fillPaint);
        canvas.drawRect(rect, _strokePaint);
      } else if (type == "circle") {
        final double x = (p["x"] as num? ?? 0).toDouble() * scaleX;
        final double y = (p["y"] as num? ?? 0).toDouble() * scaleY;
        final double r = (p["r"] as num? ?? 5).toDouble() * scaleX;

        canvas.drawCircle(Offset(x, y), r, _fillPaint);
        canvas.drawCircle(Offset(x, y), r, _strokePaint);
      } else if (type == "line") {
        final double x1 = (p["x1"] as num? ?? 0).toDouble() * scaleX;
        final double y1 = (p["y1"] as num? ?? 0).toDouble() * scaleY;
        final double x2 = (p["x2"] as num? ?? 10).toDouble() * scaleX;
        final double y2 = (p["y2"] as num? ?? 10).toDouble() * scaleY;

        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), _strokePaint);
      } else if (type == "text") {
        final double x = (p["x"] as num? ?? 0).toDouble() * scaleX;
        final double y = (p["y"] as num? ?? 0).toDouble() * scaleY;
        final String text = p["text"]?.toString() ?? "";

        _cachedTextPainter.text = TextSpan(
          text: text,
          style: TextStyle(color: baseColor, fontSize: 13, fontWeight: FontWeight.bold),
        );
        _cachedTextPainter.layout();
        _cachedTextPainter.paint(canvas, Offset(x, y));
      }
    }
  }

  @override
  bool shouldRepaint(covariant DiagramPainter oldDelegate) {
    return oldDelegate.baseColor != baseColor || oldDelegate.primitives != primitives;
  }
}
