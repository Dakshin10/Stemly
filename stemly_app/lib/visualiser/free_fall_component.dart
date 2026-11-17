// lib/visualiser/free_fall_component.dart
import 'dart:math';
import 'package:flutter/material.dart';

import '../presentation/components/glass_surface.dart';
import '../theme/theme.dart';

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
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late double _totalFallTime;

  bool _showVelocityVector = true;
  bool _showGravityVector = true;
  bool _showTrail = true;
  bool _showTelemetryHud = true;
  bool _isPaused = false;

  double get _safeH => max(0.5, widget.h);
  double get _safeG => max(0.1, widget.g);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _updateAnimation(reset: true);
  }

  @override
  void didUpdateWidget(FreeFallWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.h != widget.h || oldWidget.g != widget.g) {
      _updateAnimation(reset: false);
    }
  }

  void _updateAnimation({bool reset = false}) {
    // t_fall = sqrt(2 * h / g)
    _totalFallTime = sqrt(2.0 * _safeH / _safeG);
    final durationMs = ((_totalFallTime + 1.2) * 1000).toInt().clamp(600, 25000);

    _controller.duration = Duration(milliseconds: durationMs);
    if (reset && !_isPaused) {
      _controller.repeat();
    } else if (!_isPaused && !_controller.isAnimating) {
      _controller.repeat();
    }
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _controller.stop();
      } else {
        _controller.repeat();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        children: [
          // Physics Canvas
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: FreeFallPainter(
                    h: _safeH,
                    g: _safeG,
                    progress: _controller.value,
                    totalFallTime: _totalFallTime,
                    showVelocityVector: _showVelocityVector,
                    showGravityVector: _showGravityVector,
                    showTrail: _showTrail,
                    showTelemetryHud: _showTelemetryHud,
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),

          // Interactive Overlay Controls (Liquid Glass Capsule)
          Positioned(
            top: 10,
            left: 10,
            child: GlassSurface.capsule(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: _togglePause,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(width: 1, height: 16, color: Colors.white24),
                  const SizedBox(width: 4),
                  _controlChip(
                    label: "v⃗",
                    isActive: _showVelocityVector,
                    onTap: () => setState(() => _showVelocityVector = !_showVelocityVector),
                  ),
                  _controlChip(
                    label: "g⃗",
                    isActive: _showGravityVector,
                    onTap: () => setState(() => _showGravityVector = !_showGravityVector),
                  ),
                  _controlChip(
                    label: "Trail",
                    isActive: _showTrail,
                    onTap: () => setState(() => _showTrail = !_showTrail),
                  ),
                  _controlChip(
                    label: "HUD",
                    isActive: _showTelemetryHud,
                    onTap: () => setState(() => _showTelemetryHud = !_showTelemetryHud),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isActive ? AppColors.orangeFillLight : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? AppColors.orangeFillLight : Colors.white24,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? AppColors.onOrange : Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class FreeFallPainter extends CustomPainter {
  final double h;
  final double g;
  final double progress;
  final double totalFallTime;
  final bool showVelocityVector;
  final bool showGravityVector;
  final bool showTrail;
  final bool showTelemetryHud;

  // Cached Paint objects (Apple HIG White/Black/Orange palette - ZERO neon/green)
  static final Paint _groundPaint = Paint()
    ..color = const Color(0xFFD2D2D7)
    ..strokeWidth = 2.0;
  static final Paint _groundUnderPaint = Paint()..color = const Color(0xFFF5F5F7);
  static final Paint _rulerPaint = Paint()
    ..color = const Color(0x61000000)
    ..strokeWidth = 1.5;
  static final Paint _rulerMarkPaint = Paint()
    ..color = const Color(0x61000000)
    ..strokeWidth = 1.0;
  static final Paint _ballPaint = Paint()..color = const Color(0xFFFF6B00);
  static final Paint _ballShadowPaint = Paint()
    ..color = const Color(0x33000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
  static final Paint _ballHighlightPaint = Paint()..color = const Color(0xB3FFFFFF);
  static final Paint _trailDotPaint = Paint()
    ..color = const Color(0xFFFF8A3D)
    ..style = PaintingStyle.fill;

  static final Paint _velocityVectorPaint = Paint()
    ..color = const Color(0xFFFF6B00)
    ..strokeWidth = 2.5
    ..style = PaintingStyle.stroke;
  static final Paint _velocityArrowHeadPaint = Paint()..color = const Color(0xFFFF6B00);

  static final Paint _gravityVectorPaint = Paint()
    ..color = const Color(0xFF636366)
    ..strokeWidth = 2.2
    ..style = PaintingStyle.stroke;
  static final Paint _gravityArrowHeadPaint = Paint()..color = const Color(0xFF636366);

  static final Paint _hudBgPaint = Paint()
    ..color = const Color(0xEE1C1C1E)
    ..style = PaintingStyle.fill;
  static final Paint _hudBorderPaint = Paint()
    ..color = const Color(0x28FFFFFF)
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;

  static final TextPainter _cachedTextPainter = TextPainter(
    textDirection: TextDirection.ltr,
  );

  FreeFallPainter({
    required this.h,
    required this.g,
    required this.progress,
    required this.totalFallTime,
    this.showVelocityVector = true,
    this.showGravityVector = true,
    this.showTrail = true,
    this.showTelemetryHud = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final totalDuration = totalFallTime + 1.2;
    final currentTime = progress * totalDuration;
    final t = min(currentTime, totalFallTime);

    final currentHeight = max(0.0, h - 0.5 * g * t * t);
    final currentVelocity = g * t;

    final marginY = size.height * 0.14;
    final scale = (size.height - 2.0 * marginY) / max(0.1, h);
    final groundY = size.height - marginY;
    final centerX = size.width * 0.38;

    // Background gradient (clean neutral)
    final bgRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final bgShader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFFFFFF), Color(0xFFF9F9FA)],
    ).createShader(bgRect);
    canvas.drawRect(bgRect, Paint()..shader = bgShader);

    // Ground (Clean neutral line and subtle underfill, NO green grass)
    canvas.drawLine(Offset(0, groundY), Offset(size.width, groundY), _groundPaint);
    canvas.drawRect(Rect.fromLTWH(0, groundY + 1, size.width, size.height - groundY - 1), _groundUnderPaint);

    // Ruler
    _drawRuler(canvas, groundY, scale, marginY);

    // Drop line
    final dropLinePaint = Paint()
      ..color = const Color(0x20000000)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(centerX, marginY), Offset(centerX, groundY), dropLinePaint);

    // Ghost trail dots
    if (showTrail) {
      const dotCount = 12;
      for (int i = 0; i <= dotCount; i++) {
        final dotT = (i / dotCount) * t;
        if (dotT > t) break;
        final dotHeight = max(0.0, h - 0.5 * g * dotT * dotT);
        final dotY = groundY - dotHeight * scale;
        canvas.drawCircle(Offset(centerX, dotY), 2.5, _trailDotPaint);
      }
    }

    // Ball position
    final ballY = groundY - currentHeight * scale;

    // Shadow on ground
    final shadowScale = (1.0 - (currentHeight / max(0.1, h))).clamp(0.2, 1.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, groundY),
        width: 24 * shadowScale,
        height: 6 * shadowScale,
      ),
      _ballShadowPaint,
    );

    // Ball
    canvas.drawCircle(Offset(centerX, ballY), 12, _ballPaint);
    canvas.drawCircle(Offset(centerX - 3, ballY - 3), 3.5, _ballHighlightPaint);

    // Vectors
    if (t < totalFallTime) {
      // Downward velocity vector (v in emerald green)
      if (showVelocityVector && currentVelocity > 0.05) {
        final vectorLen = (currentVelocity * 3.5).clamp(12.0, 70.0);
        final endV = Offset(centerX + 16, ballY + vectorLen);
        final startV = Offset(centerX + 16, ballY);

        canvas.drawLine(startV, endV, _velocityVectorPaint);
        _drawArrowHead(canvas, startV, endV, _velocityArrowHeadPaint, 8);
        _drawText(
          canvas,
          'v=${currentVelocity.toStringAsFixed(1)}m/s',
          endV.dx + 4,
          endV.dy - 6,
          size: 9.5,
          bold: true,
          color: const Color(0xFF059669),
        );
      }

      // Gravity vector (downward in red)
      if (showGravityVector) {
        const gLen = 26.0;
        final startG = Offset(centerX - 16, ballY);
        final endG = Offset(centerX - 16, ballY + gLen);

        canvas.drawLine(startG, endG, _gravityVectorPaint);
        _drawArrowHead(canvas, startG, endG, _gravityArrowHeadPaint, 7);
        _drawText(
          canvas,
          'g=${g.toStringAsFixed(1)}',
          startG.dx - 40,
          endG.dy - 6,
          size: 9.5,
          bold: true,
          color: const Color(0xFFDC2626),
        );
      }
    }

    // Telemetry HUD
    if (showTelemetryHud) {
      _drawTelemetryHud(canvas, size, t, currentHeight, currentVelocity);
    }
  }

  void _drawRuler(Canvas canvas, double groundY, double scale, double marginY) {
    final rulerX = 40.0;
    canvas.drawLine(Offset(rulerX, marginY), Offset(rulerX, groundY), _rulerPaint);

    final stepH = max(1.0, (h / 5.0).roundToDouble());
    for (double yVal = 0.0; yVal <= h * 1.05; yVal += stepH) {
      final yPx = groundY - yVal * scale;
      if (yPx < marginY - 10) break;

      canvas.drawLine(Offset(rulerX - 5, yPx), Offset(rulerX + 5, yPx), _rulerMarkPaint);
      _drawText(canvas, '${yVal.toStringAsFixed(0)}m', rulerX - 32, yPx - 6, size: 9, color: Colors.black54);
    }
  }

  void _drawArrowHead(Canvas canvas, Offset start, Offset end, Paint paint, double arrowSize) {
    final angle = atan2(end.dy - start.dy, end.dx - start.dx);
    final path = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(end.dx - arrowSize * cos(angle - pi / 6), end.dy - arrowSize * sin(angle - pi / 6))
      ..lineTo(end.dx - arrowSize * cos(angle + pi / 6), end.dy - arrowSize * sin(angle + pi / 6))
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawTelemetryHud(Canvas canvas, Size size, double t, double currentH, double currentV) {
    const hudW = 120.0;
    const hudH = 75.0;
    final hudX = size.width - hudW - 12.0;
    const hudY = 10.0;

    final hudRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(hudX, hudY, hudW, hudH),
      const Radius.circular(10),
    );

    canvas.drawRRect(hudRRect, _hudBgPaint);
    canvas.drawRRect(hudRRect, _hudBorderPaint);

    _drawText(canvas, 'TELEMETRY HUD', hudX + 16, hudY + 6, size: 8.5, bold: true, color: const Color(0xFFFF8A3D));
    _drawText(canvas, 't  : ${t.toStringAsFixed(2)} s', hudX + 8, hudY + 20, size: 9, color: Colors.white70);
    _drawText(canvas, 'h  : ${currentH.toStringAsFixed(1)} m', hudX + 8, hudY + 33, size: 9, color: Colors.white70);
    _drawText(canvas, 'v  : ${currentV.toStringAsFixed(1)} m/s', hudX + 8, hudY + 46, size: 9, bold: true, color: const Color(0xFFFF8A3D));
    _drawText(canvas, 'g  : ${g.toStringAsFixed(2)} m/s²', hudX + 8, hudY + 59, size: 9, color: Colors.white70);
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
        oldDelegate.g != g ||
        oldDelegate.showVelocityVector != showVelocityVector ||
        oldDelegate.showGravityVector != showGravityVector ||
        oldDelegate.showTrail != showTrail ||
        oldDelegate.showTelemetryHud != showTelemetryHud;
  }
}
