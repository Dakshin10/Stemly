// lib/visualiser/shm_component.dart
import 'dart:math';
import 'package:flutter/material.dart';

class SHMWidget extends StatefulWidget {
  final double A;
  final double m;
  final double k;

  const SHMWidget({
    super.key,
    required this.A,
    required this.m,
    required this.k,
  });

  @override
  State<SHMWidget> createState() => _SHMWidgetState();
}

class _SHMWidgetState extends State<SHMWidget> with TickerProviderStateMixin {
  late AnimationController _controller;
  late double _omega;
  late double _period;

  double get _safeA => max(0.05, widget.A);
  double get _safeM => max(0.05, widget.m);
  double get _safeK => max(0.1, widget.k);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _updateSimulation(reset: true);
  }

  @override
  void didUpdateWidget(SHMWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.A != widget.A ||
        oldWidget.m != widget.m ||
        oldWidget.k != widget.k) {
      _updateSimulation(reset: false);
    }
  }

  void _updateSimulation({bool reset = false}) {
    // omega = sqrt(k / m)
    _omega = sqrt(_safeK / _safeM);
    // period T = 2 * pi / omega
    _period = (2.0 * pi) / _omega;

    final durationMs = max(300, min(10000, (_period * 1000).toInt()));
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
            painter: SHMPainter(
              A: _safeA,
              m: _safeM,
              k: _safeK,
              progress: _controller.value,
              omega: _omega,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class SHMPainter extends CustomPainter {
  final double A;
  final double m;
  final double k;
  final double progress;
  final double omega;

  // Cached Paint objects for 60 FPS performance
  static final Paint _ceilingPaint = Paint()..color = const Color(0xFF424242);
  static final Paint _dashPaint = Paint()
    ..color = const Color(0x664CAF50)
    ..strokeWidth = 1.0;
  static final Paint _springPaint = Paint()
    ..color = const Color(0xFF212121)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;
  static final Paint _massBorderPaint = Paint()
    ..color = const Color(0x33000000)
    ..style = PaintingStyle.stroke;
  static final Paint _massShadowPaint = Paint()
    ..color = const Color(0x1A000000);
  static final Paint _velVectorPaint = Paint()
    ..color = const Color(0xFFE53935)
    ..strokeWidth = 2.5
    ..style = PaintingStyle.stroke;
  static final Paint _velArrowHeadPaint = Paint()
    ..color = const Color(0xFFE53935);
  static final Paint _graphBgPaint = Paint()..color = const Color(0xF2FFFFFF);
  static final Paint _graphBorderPaint = Paint()
    ..color = const Color(0x1F000000)
    ..style = PaintingStyle.stroke;
  static final Paint _graphAxisPaint = Paint()
    ..color = const Color(0x33000000)
    ..strokeWidth = 1.0;
  static final Paint _graphWavePaint = Paint()
    ..color = const Color(0xFF1E88E5)
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;
  static final Paint _graphMarkerPaint = Paint()
    ..color = const Color(0xFFE53935);
  static final Paint _panelBgPaint = Paint()
    ..color = const Color(0xE6FFFFFF)
    ..style = PaintingStyle.fill;
  static final Paint _panelBorderPaint = Paint()
    ..color = const Color(0x1F000000)
    ..style = PaintingStyle.stroke;

  static final TextPainter _cachedTextPainter = TextPainter(
    textDirection: TextDirection.ltr,
  );

  SHMPainter({
    required this.A,
    required this.m,
    required this.k,
    required this.progress,
    required this.omega,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Fixed-timestep analytical integration
    final t = progress * (2.0 * pi / omega);
    final displacement = A * cos(omega * t);
    final velocity = -A * omega * sin(omega * t);

    final centerX = size.width * 0.28;
    final centerY = size.height * 0.52;

    // Viewport scaling for amplitude
    final scale = (size.height * 0.35) / max(0.1, A * 1.4);

    // Background
    final bgRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final bgShader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFF3E5F5), Color(0xFFFAFAFA)],
    ).createShader(bgRect);
    canvas.drawRect(bgRect, Paint()..shader = bgShader);

    // Ceiling mount
    final ceilingY = centerY - (A * scale) - 40.0;
    canvas.drawRect(
      Rect.fromLTWH(centerX - 40, ceilingY - 8, 80, 8),
      _ceilingPaint,
    );

    // Equilibrium dashed line
    for (double dx = centerX - 60; dx < centerX + 60; dx += 10) {
      canvas.drawLine(
        Offset(dx, centerY),
        Offset(min(dx + 5, centerX + 60), centerY),
        _dashPaint,
      );
    }
    _drawText(
      canvas,
      'Equilibrium',
      centerX - 80,
      centerY - 14,
      size: 9,
      color: const Color(0xFF2E7D32),
    );

    // Spring
    final massY = centerY + displacement * scale;
    _drawSpring(canvas, centerX, ceilingY, massY - 20.0, 18.0);

    // Mass
    _drawMass(canvas, centerX, massY);

    // Velocity Vector
    _drawVelocityVector(canvas, centerX + 36, massY, velocity);

    // Position vs Time Graph (right column)
    _drawGraph(canvas, size, t, displacement);

    // Telemetry Info Panel
    _drawInfoPanel(canvas, displacement, velocity);
  }

  void _drawSpring(
    Canvas canvas,
    double x,
    double startY,
    double endY,
    double width,
  ) {
    const coils = 12;
    final height = max(10.0, endY - startY);
    final coilHeight = height / coils;

    final path = Path()..moveTo(x, startY);
    for (int i = 0; i < coils; i++) {
      final y = startY + i * coilHeight;
      path.lineTo(
        i.isEven ? x + width / 2.0 : x - width / 2.0,
        y + coilHeight / 2.0,
      );
      path.lineTo(x, y + coilHeight);
    }

    canvas.drawPath(path, _springPaint);
  }

  void _drawMass(Canvas canvas, double x, double y) {
    const size = 36.0;
    final rect = Rect.fromCenter(
      center: Offset(x, y),
      width: size,
      height: size,
    );

    // Shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x + 4, y + 4),
        width: size,
        height: size / 2.2,
      ),
      _massShadowPaint,
    );

    // Mass block with gradient
    final blockShader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF64B5F6), Color(0xFF1976D2)],
    ).createShader(rect);

    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    canvas.drawRRect(rrect, Paint()..shader = blockShader);
    canvas.drawRRect(rrect, _massBorderPaint);

    _drawText(
      canvas,
      '${m.toStringAsFixed(1)}kg',
      x - 13,
      y - 6,
      color: Colors.white,
      bold: true,
      size: 10,
    );
  }

  void _drawVelocityVector(Canvas canvas, double x, double y, double velocity) {
    final length = (velocity * 8.0).clamp(-45.0, 45.0);
    if (length.abs() < 2.0) return;

    final endY = y + length;
    canvas.drawLine(Offset(x, y), Offset(x, endY), _velVectorPaint);

    // Arrowhead
    final dir = length.isNegative ? -1.0 : 1.0;
    final arrowPath = Path()
      ..moveTo(x, endY)
      ..lineTo(x - 3.5, endY - 6.0 * dir)
      ..lineTo(x + 3.5, endY - 6.0 * dir)
      ..close();
    canvas.drawPath(arrowPath, _velArrowHeadPaint);

    _drawText(
      canvas,
      'v',
      x + 5,
      y + length / 2 - 6,
      color: const Color(0xFFD32F2F),
      size: 10,
      bold: true,
    );
  }

  void _drawGraph(Canvas canvas, Size size, double t, double displacement) {
    final graphRect = Rect.fromLTWH(
      size.width * 0.55,
      size.height * 0.18,
      size.width * 0.40,
      size.height * 0.60,
    );

    canvas.drawRect(graphRect, _graphBgPaint);
    canvas.drawRect(graphRect, _graphBorderPaint);

    // Zero-axis
    final midY = graphRect.center.dy;
    canvas.drawLine(
      Offset(graphRect.left, midY),
      Offset(graphRect.right, midY),
      _graphAxisPaint,
    );

    // Plot sinusoidal wave across a 2-period window
    final path = Path();
    final timeWindow = 2.0 * (2.0 * pi / omega);
    const points = 50;

    for (int i = 0; i <= points; i++) {
      final timeOffset = (i / points) * timeWindow;
      final plotT = t - timeWindow + timeOffset;
      final val = A * cos(omega * plotT);

      final px = graphRect.left + (i / points) * graphRect.width;
      final py = midY + (val / max(0.01, A)) * (graphRect.height * 0.38);

      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }

    canvas.drawPath(path, _graphWavePaint);

    // Current point marker at right edge
    final cy = midY + (displacement / max(0.01, A)) * (graphRect.height * 0.38);
    canvas.drawCircle(Offset(graphRect.right, cy), 4.5, _graphMarkerPaint);

    _drawText(
      canvas,
      'Displacement vs Time',
      graphRect.left,
      graphRect.top - 18,
      bold: true,
      size: 11,
      color: const Color(0xFF4A148C),
    );
  }

  void _drawInfoPanel(Canvas canvas, double displacement, double velocity) {
    final rect = Rect.fromLTWH(12, 12, 185, 90);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(rrect, _panelBgPaint);
    canvas.drawRRect(rrect, _panelBorderPaint);

    // Energy: E = 0.5 * k * A^2
    final totalEnergy = 0.5 * k * A * A;

    _drawText(
      canvas,
      'Harmonic Oscillator',
      20,
      20,
      size: 12,
      bold: true,
      color: const Color(0xFF7B1FA2),
    );
    _drawText(
      canvas,
      'x: ${displacement.toStringAsFixed(2)} m',
      20,
      38,
      size: 11,
    );
    _drawText(
      canvas,
      'v: ${velocity.toStringAsFixed(2)} m/s',
      20,
      54,
      size: 11,
    );
    _drawText(
      canvas,
      'Energy: ${totalEnergy.toStringAsFixed(2)} J',
      20,
      70,
      size: 11,
      color: Colors.grey.shade700,
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
  bool shouldRepaint(SHMPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.A != A ||
        oldDelegate.m != m ||
        oldDelegate.k != k ||
        oldDelegate.omega != omega;
  }
}
