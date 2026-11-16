// lib/visualiser/kinematics_component.dart
import 'dart:math';
import 'package:flutter/material.dart';

class KinematicsWidget extends StatefulWidget {
  final double u;
  final double a;
  final double tMax;

  const KinematicsWidget({
    super.key,
    required this.u,
    required this.a,
    required this.tMax,
  });

  @override
  State<KinematicsWidget> createState() => _KinematicsWidgetState();
}

class _KinematicsWidgetState extends State<KinematicsWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  double get _safeTMax => max(0.5, widget.tMax);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _updateAnimation(reset: true);
  }

  @override
  void didUpdateWidget(KinematicsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.u != widget.u ||
        oldWidget.a != widget.a ||
        oldWidget.tMax != widget.tMax) {
      _updateAnimation(reset: false);
    }
  }

  void _updateAnimation({bool reset = false}) {
    final durationMs = (_safeTMax * 1000).toInt().clamp(500, 30000);
    _controller.duration = Duration(milliseconds: durationMs);

    if (reset) {
      _controller.repeat();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: KinematicsPainter(
              u: widget.u,
              a: widget.a,
              tMax: _safeTMax,
              progress: _controller.value,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class KinematicsPainter extends CustomPainter {
  final double u;
  final double a;
  final double tMax;
  final double progress;

  // Cached Paint objects to avoid allocations in paint()
  static final Paint _bgPaint = Paint()..color = const Color(0xFFECEFF1);
  static final Paint _roadPaint = Paint()..color = const Color(0xFF37474F);
  static final Paint _dashPaint = Paint()
    ..color = Colors.white70
    ..strokeWidth = 2.0;
  static final Paint _curbPaint = Paint()
    ..color = const Color(0xFFFFB300)
    ..strokeWidth = 3.0;
  static final Paint _wheelPaint = Paint()..color = const Color(0xFF212121);
  static final Paint _carBodyPaint = Paint()..color = const Color(0xFFE53935);
  static final Paint _carWindowPaint = Paint()..color = const Color(0xFFBBDEFB);
  static final Paint _vectorPaint = Paint()
    ..color = const Color(0xFF1E88E5)
    ..strokeWidth = 2.5
    ..style = PaintingStyle.stroke;
  static final Paint _panelBgPaint = Paint()
    ..color = const Color(0xE6FFFFFF)
    ..style = PaintingStyle.fill;
  static final Paint _panelBorderPaint = Paint()
    ..color = const Color(0x1F000000)
    ..style = PaintingStyle.stroke;

  static final TextPainter _cachedTextPainter = TextPainter(
    textDirection: TextDirection.ltr,
  );

  KinematicsPainter({
    required this.u,
    required this.a,
    required this.tMax,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * tMax;

    // Physics equations of motion
    // x(t) = u*t + 0.5*a*t^2
    // v(t) = u + a*t
    final x = u * t + 0.5 * a * t * t;
    final v = u + a * t;

    // Determine spatial extrema to scale the road properly
    // Check t = 0, t = tMax, and turning point t = -u/a if within [0, tMax]
    double minX = 0.0;
    double maxX = 0.0;

    final xEnd = u * tMax + 0.5 * a * tMax * tMax;
    minX = min(minX, xEnd);
    maxX = max(maxX, xEnd);

    if (a.abs() > 1e-4) {
      final tTurn = -u / a;
      if (tTurn > 0 && tTurn < tMax) {
        final xTurn = u * tTurn + 0.5 * a * tTurn * tTurn;
        minX = min(minX, xTurn);
        maxX = max(maxX, xTurn);
      }
    }

    final totalSpan = max(20.0, maxX - minX);
    const margin = 45.0;
    final scale = (size.width - 2 * margin - 70.0) / totalSpan;

    final centerY = size.height * 0.50;
    final originX = margin - minX * scale;

    // Background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), _bgPaint);

    // Roadway
    const roadHeight = 65.0;
    final roadTop = centerY + 18.0;
    canvas.drawRect(
      Rect.fromLTWH(0, roadTop, size.width, roadHeight),
      _roadPaint,
    );

    // Curbs
    canvas.drawLine(Offset(0, roadTop), Offset(size.width, roadTop), _curbPaint);
    canvas.drawLine(Offset(0, roadTop + roadHeight), Offset(size.width, roadTop + roadHeight), _curbPaint);

    // Road dashed lane markings
    for (double i = 0; i < size.width; i += 36.0) {
      canvas.drawLine(
        Offset(i, roadTop + roadHeight / 2.0),
        Offset(i + 18.0, roadTop + roadHeight / 2.0),
        _dashPaint,
      );
    }

    // Origin marker (x = 0)
    canvas.drawLine(
      Offset(originX, roadTop - 6.0),
      Offset(originX, roadTop + roadHeight + 6.0),
      Paint()..color = const Color(0x66FFFFFF)..strokeWidth = 1.5,
    );
    _drawText(canvas, 'x=0', originX - 10, roadTop + roadHeight + 8, size: 9, color: Colors.grey.shade600);

    // Car Position
    final carX = originX + x * scale;
    final carY = roadTop + roadHeight - 14.0;

    _drawCar(canvas, carX, carY, v);

    // Telemetry Info Panel
    _drawInfoPanel(canvas, t, x, v);
  }

  void _drawCar(Canvas canvas, double x, double y, double v) {
    const carWidth = 56.0;
    const carHeight = 24.0;

    // Wheels
    canvas.drawCircle(Offset(x + 14, y), 6.5, _wheelPaint);
    canvas.drawCircle(Offset(x + 42, y), 6.5, _wheelPaint);

    // Main Chassis
    final chassisRect = Rect.fromLTWH(x, y - carHeight, carWidth, carHeight - 4);
    final rrect = RRect.fromRectAndRadius(chassisRect, const Radius.circular(6));
    canvas.drawRRect(rrect, _carBodyPaint);

    // Cabin / Roof
    final cabinRect = Rect.fromLTWH(x + 12, y - carHeight - 12, 28, 12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(cabinRect, const Radius.circular(4)),
      _carBodyPaint,
    );

    // Windows
    canvas.drawRect(
      Rect.fromLTWH(x + 15, y - carHeight - 9, 10, 8),
      _carWindowPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(x + 28, y - carHeight - 9, 10, 8),
      _carWindowPaint,
    );

    // Velocity Vector Arrow
    if (v.abs() > 0.05) {
      final arrowLen = (v * 3.0).clamp(-45.0, 45.0);
      final arrowY = y - carHeight - 20.0;
      final arrowX = x + carWidth / 2.0;

      canvas.drawLine(Offset(arrowX, arrowY), Offset(arrowX + arrowLen, arrowY), _vectorPaint);

      // Arrowhead
      final dir = arrowLen.isNegative ? -1.0 : 1.0;
      final arrowPath = Path()
        ..moveTo(arrowX + arrowLen, arrowY)
        ..lineTo(arrowX + arrowLen - 5 * dir, arrowY - 4)
        ..lineTo(arrowX + arrowLen - 5 * dir, arrowY + 4)
        ..close();
      canvas.drawPath(arrowPath, Paint()..color = const Color(0xFF1E88E5));

      _drawText(
        canvas,
        'v = ${v.toStringAsFixed(1)}',
        arrowX + arrowLen / 2 - 14,
        arrowY - 14,
        size: 9,
        bold: true,
        color: const Color(0xFF1565C0),
      );
    }
  }

  void _drawInfoPanel(Canvas canvas, double t, double x, double v) {
    final rect = Rect.fromLTWH(12, 12, 195, 95);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(rrect, _panelBgPaint);
    canvas.drawRRect(rrect, _panelBorderPaint);

    _drawText(canvas, '1D Kinematics', 20, 20, size: 13, bold: true, color: const Color(0xFF283593));
    _drawText(canvas, 'Time: ${t.toStringAsFixed(1)} s / ${tMax.toStringAsFixed(1)} s', 20, 40, size: 11);
    _drawText(canvas, 'Position (x): ${x.toStringAsFixed(1)} m', 20, 58, size: 11);
    _drawText(canvas, 'Velocity (v): ${v.toStringAsFixed(1)} m/s', 20, 76, size: 11);
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
  bool shouldRepaint(KinematicsPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.u != u ||
        oldDelegate.a != a ||
        oldDelegate.tMax != tMax;
  }
}
