// lib/visualiser/projectile_motion.dart
import 'dart:math';
import 'package:flutter/material.dart';

class ProjectileMotionWidget extends StatefulWidget {
  final double U;
  final double theta;
  final double g;
  final Function(Map<String, String>)? onSimulationUpdate;

  const ProjectileMotionWidget({
    super.key,
    required this.U,
    required this.theta,
    required this.g,
    this.onSimulationUpdate,
  });

  @override
  State<ProjectileMotionWidget> createState() => _ProjectileMotionWidgetState();
}

class _ProjectileMotionWidgetState extends State<ProjectileMotionWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late double _totalFlightTime;

  double get _safeG => max(0.1, widget.g);
  double get _safeU => max(0.0, widget.U);
  double get _safeTheta => widget.theta.clamp(0.0, 90.0);

  @override
  void initState() {
    super.initState();
    _initSimulation();
  }

  @override
  void didUpdateWidget(ProjectileMotionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.U != widget.U ||
        oldWidget.theta != widget.theta ||
        oldWidget.g != widget.g) {
      _controller.stop();
      _controller.dispose();
      _initSimulation();
    }
  }

  void _initSimulation() {
    final thetaRad = _safeTheta * pi / 180.0;
    // Total flight time: 2 * U * sin(theta) / g
    final rawFlightTime = (2.0 * _safeU * sin(thetaRad)) / _safeG;
    _totalFlightTime = rawFlightTime.isFinite && rawFlightTime > 0.05
        ? rawFlightTime
        : 1.0;

    // Calculate Physical Stats
    final range = (_safeU * _safeU * sin(2.0 * thetaRad)) / _safeG;
    final maxHeight = (_safeU * _safeU * sin(thetaRad) * sin(thetaRad)) / (2.0 * _safeG);

    if (widget.onSimulationUpdate != null) {
      widget.onSimulationUpdate!({
        "Range": "${range.toStringAsFixed(1)} m",
        "Max Height": "${maxHeight.toStringAsFixed(1)} m",
        "Flight Time": "${_totalFlightTime.toStringAsFixed(1)} s",
      });
    }

    final durationMs = max(500, (_totalFlightTime * 1000 + 800).toInt());
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
            painter: ProjectileMotionPainter(
              U: _safeU,
              theta: _safeTheta,
              g: _safeG,
              progress: _controller.value,
              totalFlightTime: _totalFlightTime,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class ProjectileMotionPainter extends CustomPainter {
  final double U;
  final double theta;
  final double g;
  final double progress;
  final double totalFlightTime;

  // Cached Paint objects to avoid allocations during 60 FPS animation
  static final Paint _groundPaint = Paint()..color = const Color(0xFF689F38);
  static final Paint _gridPaint = Paint()
    ..color = const Color(0x339E9E9E)
    ..strokeWidth = 1.0;
  static final Paint _axisPaint = Paint()
    ..color = const Color(0xDE000000)
    ..strokeWidth = 2.0;
  static final Paint _trajectoryPaint = Paint()
    ..color = const Color(0x80FF6B35)
    ..strokeWidth = 3.0
    ..style = PaintingStyle.stroke;
  static final Paint _ballPaint = Paint()..color = const Color(0xFFFF6B35);
  static final Paint _shadowPaint = Paint()
    ..color = const Color(0x40000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
  static final Paint _highlightPaint = Paint()..color = const Color(0xB3FFFFFF);
  static final Paint _vectorPaint = Paint()
    ..color = const Color(0xFF1976D2)
    ..strokeWidth = 2.5
    ..style = PaintingStyle.stroke;
  static final Paint _arrowHeadPaint = Paint()..color = const Color(0xFF1976D2);

  // Cached TextPainter for label rendering
  static final TextPainter _cachedTextPainter = TextPainter(
    textDirection: TextDirection.ltr,
  );

  ProjectileMotionPainter({
    required this.U,
    required this.theta,
    required this.g,
    required this.progress,
    required this.totalFlightTime,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final thetaRad = theta * pi / 180.0;
    final range = (U * U * sin(2.0 * thetaRad)) / g;
    final maxHeight = (U * U * sin(thetaRad) * sin(thetaRad)) / (2.0 * g);

    // Safeguard against angle 0 or 90 where range or height collapses to 0
    final displayRange = max(10.0, range);
    final displayHeight = max(5.0, maxHeight);

    final marginX = size.width * 0.12;
    final marginY = size.height * 0.16;

    final scaleX = (size.width - 2 * marginX) / displayRange;
    final scaleY = (size.height - 2 * marginY) / (displayHeight * 1.25);
    final scale = min(scaleX, scaleY);

    final originX = marginX;
    final originY = size.height - marginY;

    // Background sky gradient
    final bgRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final bgShader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFE8F5E9), Color(0xFFF1F8E9)],
    ).createShader(bgRect);
    canvas.drawRect(bgRect, Paint()..shader = bgShader);

    // Ground
    canvas.drawRect(
      Rect.fromLTWH(0, originY, size.width, size.height - originY),
      _groundPaint,
    );

    // Grid
    _drawGrid(canvas, originX, originY, scale, displayRange, displayHeight);

    // Axes
    _drawAxes(canvas, originX, originY, scale, displayRange, displayHeight);

    // Trajectory path (fixed-step integration)
    _drawTrajectory(canvas, originX, originY, scale, thetaRad);

    // Ball & Velocity Vector
    final activeFlightTime = max(0.001, totalFlightTime);
    final activeDuration = activeFlightTime + 0.8;
    final currentTime = progress * activeDuration;
    final t = min(currentTime, activeFlightTime);

    final pos = _calculatePosition(t, thetaRad);
    _drawBall(canvas, originX, originY, scale, pos);

    if (t < activeFlightTime) {
      _drawVelocityVector(canvas, originX, originY, scale, pos, t, thetaRad);
    }
  }

  Offset _calculatePosition(double t, double thetaRad) {
    final x = U * cos(thetaRad) * t;
    final y = max(0.0, U * sin(thetaRad) * t - 0.5 * g * t * t);
    return Offset(x, y);
  }

  void _drawGrid(
    Canvas canvas,
    double originX,
    double originY,
    double scale,
    double displayRange,
    double displayHeight,
  ) {
    final stepX = max(1.0, (displayRange / 6.0).roundToDouble());
    final stepY = max(1.0, (displayHeight / 4.0).roundToDouble());

    for (double x = 0; x <= displayRange * 1.05; x += stepX) {
      final px = originX + x * scale;
      canvas.drawLine(
        Offset(px, originY),
        Offset(px, originY - displayHeight * 1.25 * scale),
        _gridPaint,
      );
    }

    for (double y = 0; y <= displayHeight * 1.25; y += stepY) {
      final py = originY - y * scale;
      canvas.drawLine(
        Offset(originX, py),
        Offset(originX + displayRange * scale, py),
        _gridPaint,
      );
    }
  }

  void _drawAxes(
    Canvas canvas,
    double originX,
    double originY,
    double scale,
    double displayRange,
    double displayHeight,
  ) {
    // X-axis
    canvas.drawLine(
      Offset(originX, originY),
      Offset(originX + displayRange * scale, originY),
      _axisPaint,
    );

    // Y-axis
    canvas.drawLine(
      Offset(originX, originY),
      Offset(originX, originY - displayHeight * 1.25 * scale),
      _axisPaint,
    );

    _drawText(
      canvas,
      'Distance (m)',
      originX + displayRange * scale / 2 - 35,
      originY + 12,
      size: 11,
      bold: true,
    );
    _drawText(
      canvas,
      'Height (m)',
      originX - 10,
      originY - displayHeight * 1.25 * scale - 18,
      size: 11,
      bold: true,
    );
  }

  void _drawTrajectory(
    Canvas canvas,
    double originX,
    double originY,
    double scale,
    double thetaRad,
  ) {
    if (totalFlightTime <= 0) return;

    final path = Path();
    const int segments = 60; // Fixed-step integration

    for (int i = 0; i <= segments; i++) {
      final t = (i / segments) * totalFlightTime;
      final pos = _calculatePosition(t, thetaRad);
      final px = originX + pos.dx * scale;
      final py = originY - pos.dy * scale;

      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }

    canvas.drawPath(path, _trajectoryPaint);
  }

  void _drawBall(
    Canvas canvas,
    double originX,
    double originY,
    double scale,
    Offset pos,
  ) {
    final px = originX + pos.dx * scale;
    final py = originY - pos.dy * scale;

    // Shadow on ground
    canvas.drawCircle(Offset(px, originY), 10, _shadowPaint);

    // Ball body
    canvas.drawCircle(Offset(px, py), 12, _ballPaint);

    // Specular highlight
    canvas.drawCircle(Offset(px - 3, py - 3), 4, _highlightPaint);
  }

  void _drawVelocityVector(
    Canvas canvas,
    double originX,
    double originY,
    double scale,
    Offset pos,
    double t,
    double thetaRad,
  ) {
    final vx = U * cos(thetaRad);
    final vy = U * sin(thetaRad) - g * t;

    final px = originX + pos.dx * scale;
    final py = originY - pos.dy * scale;

    final vectorScale = max(0.5, 0.12 * scale);
    final endX = px + vx * vectorScale;
    final endY = py - vy * vectorScale;

    // Vector line
    canvas.drawLine(Offset(px, py), Offset(endX, endY), _vectorPaint);

    // Arrowhead
    final angle = atan2(endY - py, endX - px);
    final arrowPath = Path()
      ..moveTo(endX, endY)
      ..lineTo(
        endX - 8 * cos(angle - pi / 6),
        endY - 8 * sin(angle - pi / 6),
      )
      ..lineTo(
        endX - 8 * cos(angle + pi / 6),
        endY - 8 * sin(angle + pi / 6),
      )
      ..close();

    canvas.drawPath(arrowPath, _arrowHeadPaint);

    final speed = sqrt(vx * vx + vy * vy);
    _drawText(
      canvas,
      'v = ${speed.toStringAsFixed(1)} m/s',
      endX + 6,
      endY - 6,
      size: 10,
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
  bool shouldRepaint(ProjectileMotionPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.U != U ||
        oldDelegate.theta != theta ||
        oldDelegate.g != g;
  }
}
