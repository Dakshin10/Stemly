// lib/visualiser/optics_component.dart
import 'dart:math';
import 'package:flutter/material.dart';

class OpticsWidget extends StatelessWidget {
  final double f;
  final double u;
  final double ho;

  const OpticsWidget({
    super.key,
    required this.f,
    required this.u,
    required this.ho,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.expand(
        child: CustomPaint(
          painter: OpticsPainter(
            f: max(1.0, f),
            u: max(1.0, u),
            ho: max(0.5, ho),
          ),
        ),
      ),
    );
  }
}

class OpticsPainter extends CustomPainter {
  final double f;
  final double u;
  final double ho;

  // Cached Paint objects to avoid allocations during rebuilds
  static final Paint _bgPaint = Paint()..color = const Color(0xFFFAFAFA);
  static final Paint _axisPaint = Paint()
    ..color = const Color(0x8A000000)
    ..strokeWidth = 1.5;
  static final Paint _lensFillPaint = Paint()
    ..color = const Color(0x332196F3)
    ..style = PaintingStyle.fill;
  static final Paint _lensBorderPaint = Paint()
    ..color = const Color(0xFF2196F3)
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;
  static final Paint _pointPaint = Paint()..color = const Color(0xFF212121);
  static final Paint _rayPaint = Paint()
    ..color = const Color(0xFFFB8C00)
    ..strokeWidth = 1.5;
  static final Paint _virtualRayPaint = Paint()
    ..color = const Color(0x99FB8C00)
    ..strokeWidth = 1.2
    ..style = PaintingStyle.stroke;
  static final Paint _objArrowPaint = Paint()
    ..color = const Color(0xFF1976D2)
    ..strokeWidth = 3.0;
  static final Paint _imgArrowPaint = Paint()
    ..color = const Color(0xFFD32F2F)
    ..strokeWidth = 3.0;
  static final Paint _panelBgPaint = Paint()
    ..color = const Color(0xE6FFFFFF)
    ..style = PaintingStyle.fill;
  static final Paint _panelBorderPaint = Paint()
    ..color = const Color(0x1F000000)
    ..style = PaintingStyle.stroke;

  static final TextPainter _cachedTextPainter = TextPainter(
    textDirection: TextDirection.ltr,
  );

  OpticsPainter({required this.f, required this.u, required this.ho});

  @override
  void paint(Canvas canvas, Size size) {
    // Thin lens formula: 1/f = 1/v - 1/(-u) => 1/v = 1/f - 1/u
    // u: object distance (positive magnitude, placed at -u)
    // f: focal length (positive for convex lens)
    final denom = 1.0 / f - 1.0 / u;
    final isAtFocus = denom.abs() < 1e-4;

    final double v;
    final double m;
    final double hi;
    final bool isVirtual;

    if (isAtFocus) {
      v = double.infinity;
      m = double.infinity;
      hi = double.infinity;
      isVirtual = false;
    } else {
      v = 1.0 / denom;
      // Magnification m = v / (-u) in sign convention, or |m| = |v| / u
      // Image height hi = (v / u) * ho (inverted if v > 0)
      m = v / u;
      hi = m * ho;
      isVirtual = v < 0;
    }

    // Viewport Scaling: scale to fit object, focal points, and visible portion of image
    // Never let v = infinity collapse the viewport scale!
    final effectiveImageDistance = isAtFocus ? 2.5 * f : min(v.abs(), 3.5 * f);
    final totalSpan = max(u + 2.0 * f, effectiveImageDistance + 2.0 * f);
    final scale = (size.width * 0.42) / max(totalSpan, 30.0);

    final centerX = size.width / 2.0;
    final centerY = size.height / 2.0;

    // Background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), _bgPaint);

    // Principal Axis
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      _axisPaint,
    );

    // Convex Lens
    _drawLens(canvas, centerX, centerY, min(140.0, size.height * 0.65));

    // Focal Points F1 (-f) and F2 (+f)
    _drawPoint(canvas, centerX - f * scale, centerY, 'F₁');
    _drawPoint(canvas, centerX + f * scale, centerY, 'F₂');
    _drawPoint(canvas, centerX - 2.0 * f * scale, centerY, '2F₁');
    _drawPoint(canvas, centerX + 2.0 * f * scale, centerY, '2F₂');

    // Object Arrow at (-u)
    final objX = centerX - u * scale;
    final scaledHo = ho * scale * 1.8;
    _drawArrow(
      canvas,
      objX,
      centerY,
      -scaledHo,
      const Color(0xFF1976D2),
      'Object',
    );

    // Rays and Image
    if (isAtFocus) {
      // Parallel rays to infinity
      _drawParallelRays(canvas, objX, centerY - scaledHo, centerX, centerY);
    } else {
      final imgX = centerX + v * scale;
      final scaledHi = hi.abs() * scale * 1.8;

      if (!isVirtual) {
        // Real, inverted image (v > 0)
        _drawArrow(
          canvas,
          imgX,
          centerY,
          scaledHi,
          const Color(0xFFD32F2F),
          'Image',
        );
        _drawRealRays(
          canvas,
          objX,
          centerY - scaledHo,
          imgX,
          centerY + scaledHi,
          centerX,
          centerY,
          centerX + f * scale,
        );
      } else {
        // Virtual, upright image (v < 0, same side as object)
        _drawArrow(
          canvas,
          imgX,
          centerY,
          -scaledHi,
          const Color(0xFFE53935),
          'Virtual Image',
        );
        _drawVirtualRays(
          canvas,
          objX,
          centerY - scaledHo,
          imgX,
          centerY - scaledHi,
          centerX,
          centerY,
          centerX + f * scale,
        );
      }
    }

    // Info telemetry panel
    _drawInfoPanel(canvas, v, m, isAtFocus, isVirtual);
  }

  void _drawLens(Canvas canvas, double x, double y, double height) {
    final path = Path();
    path.moveTo(x, y - height / 2.0);
    path.quadraticBezierTo(x + 18, y, x, y + height / 2.0);
    path.quadraticBezierTo(x - 18, y, x, y - height / 2.0);

    canvas.drawPath(path, _lensFillPaint);
    canvas.drawPath(path, _lensBorderPaint);

    // Lens optical center line
    canvas.drawLine(
      Offset(x, y - height / 2.0),
      Offset(x, y + height / 2.0),
      _axisPaint,
    );
  }

  void _drawArrow(
    Canvas canvas,
    double x,
    double y,
    double deltaY,
    Color color,
    String label,
  ) {
    final tipY = y + deltaY;
    final paint = (color == const Color(0xFF1976D2))
        ? _objArrowPaint
        : _imgArrowPaint;

    canvas.drawLine(Offset(x, y), Offset(x, tipY), paint);

    // Arrowhead
    final dir = deltaY.isNegative ? -1.0 : 1.0;
    final path = Path()
      ..moveTo(x, tipY)
      ..lineTo(x - 5, tipY - 8 * dir)
      ..lineTo(x + 5, tipY - 8 * dir)
      ..close();

    canvas.drawPath(path, Paint()..color = color);

    _drawText(
      canvas,
      label,
      x - 16,
      dir < 0 ? tipY - 16 : tipY + 4,
      color: color,
      bold: true,
      size: 10,
    );
  }

  void _drawPoint(Canvas canvas, double x, double y, String label) {
    canvas.drawCircle(Offset(x, y), 3, _pointPaint);
    _drawText(canvas, label, x - 6, y + 6, size: 9, bold: true);
  }

  void _drawRealRays(
    Canvas canvas,
    double ox,
    double oy,
    double ix,
    double iy,
    double cx,
    double cy,
    double f2x,
  ) {
    // Ray 1: Parallel to axis from object tip to lens, then through F2 to image tip
    canvas.drawLine(Offset(ox, oy), Offset(cx, oy), _rayPaint);
    canvas.drawLine(Offset(cx, oy), Offset(ix, iy), _rayPaint);

    // Ray 2: Through optical center (cx, cy) directly to image tip
    canvas.drawLine(Offset(ox, oy), Offset(ix, iy), _rayPaint);
  }

  void _drawVirtualRays(
    Canvas canvas,
    double ox,
    double oy,
    double ix,
    double iy,
    double cx,
    double cy,
    double f2x,
  ) {
    // Ray 1: Parallel to axis to lens, then refracts through F2 into right half plane
    canvas.drawLine(Offset(ox, oy), Offset(cx, oy), _rayPaint);
    final ray1Slope = (cy - oy) / (f2x - cx);
    final extendX = cx + 250.0;
    final extendY = oy + ray1Slope * (extendX - cx);
    canvas.drawLine(Offset(cx, oy), Offset(extendX, extendY), _rayPaint);

    // Dashed backwards projection to virtual image tip
    _drawDashedLine(canvas, Offset(cx, oy), Offset(ix, iy));

    // Ray 2: Optical center ray through (cx, cy)
    final ray2Slope = (cy - oy) / (cx - ox);
    canvas.drawLine(
      Offset(ox, oy),
      Offset(extendX, cy + ray2Slope * (extendX - cx)),
      _rayPaint,
    );
    _drawDashedLine(canvas, Offset(cx, cy), Offset(ix, iy));
  }

  void _drawParallelRays(
    Canvas canvas,
    double ox,
    double oy,
    double cx,
    double cy,
  ) {
    // Ray 1: Parallel to axis to lens, refracts through F2
    canvas.drawLine(Offset(ox, oy), Offset(cx, oy), _rayPaint);
    canvas.drawLine(
      Offset(cx, oy),
      Offset(cx + 250.0, cy + (cy - oy)),
      _rayPaint,
    );

    // Ray 2: Directly through optical center
    canvas.drawLine(
      Offset(ox, oy),
      Offset(cx + 250.0, cy + (cy - oy)),
      _rayPaint,
    );

    _drawText(
      canvas,
      "Rays emerge parallel (Image at ∞)",
      cx + 40,
      cy - 40,
      size: 11,
      color: const Color(0xFFE65100),
      bold: true,
    );
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2) {
    final dist = (p2 - p1).distance;
    final count = max(1, (dist / 8.0).floor());
    final dx = (p2.dx - p1.dx) / count;
    final dy = (p2.dy - p1.dy) / count;

    for (int i = 0; i < count; i += 2) {
      canvas.drawLine(
        Offset(p1.dx + dx * i, p1.dy + dy * i),
        Offset(p1.dx + dx * (i + 1), p1.dy + dy * (i + 1)),
        _virtualRayPaint,
      );
    }
  }

  void _drawInfoPanel(
    Canvas canvas,
    double v,
    double m,
    bool isAtFocus,
    bool isVirtual,
  ) {
    final rect = Rect.fromLTWH(12, 12, 210, 105);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(rrect, _panelBgPaint);
    canvas.drawRRect(rrect, _panelBorderPaint);

    _drawText(
      canvas,
      'Convex Lens Optics',
      22,
      20,
      size: 13,
      bold: true,
      color: const Color(0xFF1565C0),
    );
    _drawText(
      canvas,
      'Focal Length: ${f.toStringAsFixed(1)} cm',
      22,
      40,
      size: 11,
    );
    _drawText(
      canvas,
      'Object Dist (u): ${u.toStringAsFixed(1)} cm',
      22,
      58,
      size: 11,
    );

    if (isAtFocus) {
      _drawText(
        canvas,
        'Image Dist: ∞ (At Infinity)',
        22,
        76,
        size: 11,
        bold: true,
        color: const Color(0xFFE65100),
      );
      _drawText(
        canvas,
        'Nature: Parallel Beams',
        22,
        94,
        size: 10,
        color: Colors.grey.shade700,
      );
    } else {
      final imgDistStr =
          '${v.abs().toStringAsFixed(1)} cm (${isVirtual ? "Virtual" : "Real"})';
      _drawText(canvas, 'Image Dist: $imgDistStr', 22, 76, size: 11);
      final nature = isVirtual ? "Virtual, Upright" : "Real, Inverted";
      _drawText(
        canvas,
        'Mag: ${m.abs().toStringAsFixed(2)}x ($nature)',
        22,
        94,
        size: 10,
        color: Colors.grey.shade700,
      );
    }
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
  bool shouldRepaint(OpticsPainter oldDelegate) {
    return oldDelegate.f != f || oldDelegate.u != u || oldDelegate.ho != ho;
  }
}
