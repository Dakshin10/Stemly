// lib/visualiser/free_fall_component.dart
import 'dart:math';
import 'package:flutter/material.dart';

class FreeFallWidget extends StatefulWidget {
  final double h;
  final double g;

  const FreeFallWidget({
    super.key,
    required this.h,
    required this.g,
  });

  @override
  State<FreeFallWidget> createState() => _FreeFallWidgetState();
}

class _FreeFallWidgetState extends State<FreeFallWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late double _totalFallTime;

  double get _safeH => max(0.5, widget.h);
  double get _safeG => max(0.1, widget.g);

  @override
  void initState() {
    super.initState();
    _initAnimation();
  }

  @override
  void didUpdateWidget(FreeFallWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.h != widget.h || oldWidget.g != widget.g) {
      _controller.stop();
      _controller.dispose();
      _initAnimation();
    }
  }

  void _initAnimation() {
    // t_fall = sqrt(2 * h / g)
    _totalFallTime = sqrt(2.0 * _safeH / _safeG);
    final durationMs = ((_totalFallTime + 1.2) * 1000).toInt().clamp(600, 25000);

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    )..repeat();
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
            painter: FreeFallPainter(
              h: _safeH,
              g: _safeG,
              progress: _controller.value,
              totalFallTime: _totalFallTime,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class FreeFallPainter extends CustomPainter {
  final double h;
  final double g;
  final double progress;
  final double totalFallTime;

  // Cached Paint objects for smooth 60 FPS rendering
  static final Paint _groundPaint = Paint()..color = const Color(0xFF689F38);
  static final Paint _rulerPaint = Paint()
    ..color = const Color(0x61000000)
    ..strokeWidth = 1.5;
  static final Paint _rulerMarkPaint = Paint()
    ..color = const Color(0x61000000)
    ..strokeWidth = 1.0;
  static final Paint _ballPaint = Paint()..color = const Color(0xFFE65100);
  static final Paint _ballShadowPaint = Paint()
    ..color = const Color(0x40000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
  static final Paint _ballHighlightPaint = Paint()..color = const Color(0xB3FFFFFF);
  static final Paint _vectorPaint = Paint()
    ..color = const Color(0xFF1565C0)
    ..strokeWidth = 2.5;
  static final Paint _arrowHeadPaint = Paint()..color = const Color(0xFF1565C0);
  static final Paint _panelBgPaint = Paint()
    ..color = const Color(0xE6FFFFFF)
    ..style = PaintingStyle.fill;
  static final Paint _panelBorderPaint = Paint()
    ..color = const Color(0x1F000000)
    ..style = PaintingStyle.stroke;

  static final TextPainter _cachedTextPainter = TextPainter(
    textDirection: TextDirection.ltr,
  );

  FreeFallPainter({
    required this.h,
    required this.g,
    required this.progress,
    required this.totalFallTime,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Total cycle duration includes fall time + pause on ground
    final totalDuration = totalFallTime + 1.2;
    final currentTime = progress * totalDuration;
    final t = min(currentTime, totalFallTime);

    // Physics equations of motion
    // y(t) = h - 0.5 * g * t^2
    // v(t) = g * t (downward)
    final currentHeight = max(0.0, h - 0.5 * g * t * t);
    final currentVelocity = g * t;

    final marginY = size.height * 0.14;
    final scale = (size.height - 2.0 * marginY) / max(0.1, h);
    final groundY = size.height - marginY;
    final centerX = size.width * 0.42;

    // Background gradient
    final bgRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final bgShader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFE1F5FE), Color(0xFFFAFAFA)],
    ).createShader(bgRect);
    canvas.drawRect(bgRect, Paint()..shader = bgShader);

    // Ground
    canvas.drawRect(
      Rect.fromLTWH(0, groundY, size.width, size.height - groundY),
      _groundPaint,
    );

    // Vertical measurement ruler
    _drawRuler(canvas, centerX - 55.0, groundY, scale, h);

    // Ball position
    final ballY = groundY - currentHeight * scale;
    _drawBall(canvas, centerX, ballY, groundY);

    // Velocity vector (downward)
    if (t < totalFallTime && currentVelocity > 0.1) {
      _drawVelocityVector(canvas, centerX, ballY, currentVelocity, scale);
    }

    // Telemetry Info Panel
    _drawInfoPanel(canvas, t, currentHeight, currentVelocity);
  }

  void _drawRuler(
    Canvas canvas,
    double x,
    double groundY,
    double scale,
    double maxHeight,
  ) {
    final topY = groundY - maxHeight * scale;
    canvas.drawLine(Offset(x, groundY), Offset(x, topY), _rulerPaint);

    final step = max(1.0, (maxHeight / 5.0).roundToDouble());
    for (double mark = 0; mark <= maxHeight; mark += step) {
      final y = groundY - mark * scale;
      canvas.drawLine(Offset(x - 6, y), Offset(x, y), _rulerMarkPaint);
      _drawText(
        canvas,
        '${mark.toInt()}m',
        x - 30,
        y - 6,
        size: 9,
        color: Colors.grey.shade700,
      );
    }
  }

  void _drawBall(Canvas canvas, double x, double y, double groundY) {
    const radius = 13.0;

    // Contact shadow
    final shadowScale = ((groundY - y) / (groundY)).clamp(0.2, 1.0);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, groundY), width: 22.0 * shadowScale, height: 6.0),
      _ballShadowPaint,
    );

    // Ball body
    canvas.drawCircle(Offset(x, y), radius, _ballPaint);

    // Highlight
    canvas.drawCircle(Offset(x - 3, y - 3), 4, _ballHighlightPaint);
  }

  void _drawVelocityVector(
    Canvas canvas,
    double x,
    double y,
    double v,
    double scale,
  ) {
    final arrowLen = (v * 1.5).clamp(8.0, 50.0);
    final endY = y + arrowLen;

    canvas.drawLine(Offset(x + 22, y), Offset(x + 22, endY), _vectorPaint);

    // Arrowhead pointing down
    final path = Path()
      ..moveTo(x + 22, endY)
      ..lineTo(x + 18, endY - 6)
      ..lineTo(x + 26, endY - 6)
      ..close();
    canvas.drawPath(path, _arrowHeadPaint);

    _drawText(
      canvas,
      'v = ${v.toStringAsFixed(1)} m/s',
      x + 30,
      y + arrowLen / 2 - 6,
      size: 9,
      bold: true,
      color: const Color(0xFF0D47A1),
    );
  }

  void _drawInfoPanel(
    Canvas canvas,
    double t,
    double height,
    double velocity,
  ) {
    final rect = Rect.fromLTWH(12, 12, 195, 95);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(rrect, _panelBgPaint);
    canvas.drawRRect(rrect, _panelBorderPaint);

    _drawText(canvas, 'Free Fall Under Gravity', 20, 20, size: 12, bold: true, color: const Color(0xFFE65100));
    _drawText(canvas, 'Height: ${height.toStringAsFixed(1)} m / ${h.toStringAsFixed(1)} m', 20, 40, size: 11);
    _drawText(canvas, 'Velocity: ${velocity.toStringAsFixed(1)} m/s', 20, 58, size: 11);
    _drawText(canvas, 'Fall Time: ${t.toStringAsFixed(2)} s / ${totalFallTime.toStringAsFixed(2)} s', 20, 76, size: 11);
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
  bool shouldRepaint(FreeFallPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.h != h ||
        oldDelegate.g != g;
  }
}
