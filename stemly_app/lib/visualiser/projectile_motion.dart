// lib/visualiser/projectile_motion.dart
import 'dart:math';
import 'package:flutter/material.dart';

import '../presentation/components/glass_surface.dart';
import '../theme/theme.dart';

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
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late double _totalFlightTime;

  // Interactive overlay vector toggles
  bool _showVelocityVector = true;
  bool _showComponents = true;
  bool _showGravityVector = true;
  bool _showTrajectoryTrail = true;
  bool _showTelemetryHud = true;
  bool _isPaused = false;

  double get _safeG => max(0.1, widget.g);
  double get _safeU => max(0.0, widget.U);
  double get _safeTheta => widget.theta.clamp(0.0, 90.0);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _updateSimulation(resetController: true);
  }

  @override
  void didUpdateWidget(ProjectileMotionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.U != widget.U ||
        oldWidget.theta != widget.theta ||
        oldWidget.g != widget.g) {
      _updateSimulation(resetController: false);
    }
  }

  void _updateSimulation({bool resetController = false}) {
    final thetaRad = _safeTheta * pi / 180.0;
    // Total flight time: 2 * U * sin(theta) / g
    final rawFlightTime = (2.0 * _safeU * sin(thetaRad)) / _safeG;
    _totalFlightTime = rawFlightTime.isFinite && rawFlightTime > 0.05
        ? rawFlightTime
        : 1.0;

    // Calculate Physical Stats
    final range = (_safeU * _safeU * sin(2.0 * thetaRad)) / _safeG;
    final maxHeight =
        (_safeU * _safeU * sin(thetaRad) * sin(thetaRad)) / (2.0 * _safeG);

    if (widget.onSimulationUpdate != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onSimulationUpdate!({
            "Range": "${range.toStringAsFixed(1)} m",
            "Max Height": "${maxHeight.toStringAsFixed(1)} m",
            "Flight Time": "${_totalFlightTime.toStringAsFixed(1)} s",
          });
        }
      });
    }

    final durationMs = max(500, (_totalFlightTime * 1000 + 800).toInt());
    _controller.duration = Duration(milliseconds: durationMs);

    if (resetController) {
      if (!_isPaused) {
        _controller.repeat();
      }
    } else {
      if (!_isPaused && !_controller.isAnimating) {
        _controller.repeat();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations && !_isPaused) {
      _isPaused = true;
      _controller.stop();
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
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        children: [
          // 1. Physics Canvas
          Positioned.fill(
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
                    showVelocityVector: _showVelocityVector,
                    showComponents: _showComponents,
                    showGravityVector: _showGravityVector,
                    showTrajectoryTrail: _showTrajectoryTrail,
                    showTelemetryHud: _showTelemetryHud,
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),

          // 2. Interactive Overlay Vector & HUD Controls (Liquid Glass Toolbar)
          Positioned(
            top: 10,
            left: 10,
            child: GlassSurface.capsule(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Play/Pause button
                  InkWell(
                    onTap: _togglePause,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        _isPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(width: 1, height: 16, color: Colors.white24),
                  const SizedBox(width: 4),
                  // Toggle Velocity Vector
                  _controlChip(
                    label: "v⃗",
                    isActive: _showVelocityVector,
                    onTap: () => setState(
                      () => _showVelocityVector = !_showVelocityVector,
                    ),
                  ),
                  // Toggle Decomposed Components
                  _controlChip(
                    label: "vx/vy",
                    isActive: _showComponents,
                    onTap: () =>
                        setState(() => _showComponents = !_showComponents),
                  ),
                  // Toggle Gravity Vector
                  _controlChip(
                    label: "g⃗",
                    isActive: _showGravityVector,
                    onTap: () => setState(
                      () => _showGravityVector = !_showGravityVector,
                    ),
                  ),
                  // Toggle Ghost Trail
                  _controlChip(
                    label: "Trail",
                    isActive: _showTrajectoryTrail,
                    onTap: () => setState(
                      () => _showTrajectoryTrail = !_showTrajectoryTrail,
                    ),
                  ),
                  // Toggle Telemetry HUD
                  _controlChip(
                    label: "HUD",
                    isActive: _showTelemetryHud,
                    onTap: () =>
                        setState(() => _showTelemetryHud = !_showTelemetryHud),
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
          color: isActive
              ? AppColors.orangeFillLight
              : Colors.white.withValues(alpha: 0.12),
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

class ProjectileMotionPainter extends CustomPainter {
  final double U;
  final double theta;
  final double g;
  final double progress;
  final double totalFlightTime;
  final bool showVelocityVector;
  final bool showComponents;
  final bool showGravityVector;
  final bool showTrajectoryTrail;
  final bool showTelemetryHud;

  // Cached Paint objects (Apple HIG White/Black/Orange palette - ZERO neon/green ground)
  static final Paint _groundPaint = Paint()
    ..color = const Color(0xFFD2D2D7)
    ..strokeWidth = 2.0;
  static final Paint _groundUnderPaint = Paint()
    ..color = const Color(0xFFF5F5F7);
  static final Paint _gridPaint = Paint()
    ..color = const Color(0x1F000000)
    ..strokeWidth = 1.0;
  static final Paint _axisPaint = Paint()
    ..color = const Color(0xDE1C1C1E)
    ..strokeWidth = 2.0;
  static final Paint _trajectoryPaint = Paint()
    ..color = const Color(0x60FF6B00)
    ..strokeWidth = 2.5
    ..style = PaintingStyle.stroke;
  static final Paint _trailDotPaint = Paint()
    ..color = const Color(0xFFFF8A3D)
    ..style = PaintingStyle.fill;
  static final Paint _ballPaint = Paint()..color = const Color(0xFFFF6B00);
  static final Paint _shadowPaint = Paint()
    ..color = const Color(0x33000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
  static final Paint _highlightPaint = Paint()..color = const Color(0xB3FFFFFF);

  // Vector Paints (Solid orange v, dark neutral components vx/vy, slate gravity g)
  static final Paint _velocityVectorPaint = Paint()
    ..color = const Color(0xFFFF6B00)
    ..strokeWidth = 2.5
    ..style = PaintingStyle.stroke;
  static final Paint _velocityArrowHeadPaint = Paint()
    ..color = const Color(0xFFFF6B00);

  static final Paint _vxPaint = Paint()
    ..color = const Color(0xFF1C1C1E)
    ..strokeWidth = 1.8
    ..style = PaintingStyle.stroke;
  static final Paint _vxArrowPaint = Paint()..color = const Color(0xFF1C1C1E);

  static final Paint _vyPaint = Paint()
    ..color = const Color(0xFF1C1C1E)
    ..strokeWidth = 1.8
    ..style = PaintingStyle.stroke;
  static final Paint _vyArrowPaint = Paint()..color = const Color(0xFF1C1C1E);

  static final Paint _componentDashedPaint = Paint()
    ..color = const Color(0x401C1C1E)
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;

  static final Paint _gravityVectorPaint = Paint()
    ..color = const Color(0xFF636366)
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;
  static final Paint _gravityArrowHeadPaint = Paint()
    ..color = const Color(0xFF636366);

  // HUD Paints (Apple Liquid Glass dark HUD)
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

  ProjectileMotionPainter({
    required this.U,
    required this.theta,
    required this.g,
    required this.progress,
    required this.totalFlightTime,
    this.showVelocityVector = true,
    this.showComponents = true,
    this.showGravityVector = true,
    this.showTrajectoryTrail = true,
    this.showTelemetryHud = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final thetaRad = theta * pi / 180.0;
    final range = (U * U * sin(2.0 * thetaRad)) / g;
    final maxHeight = (U * U * sin(thetaRad) * sin(thetaRad)) / (2.0 * g);

    final displayRange = max(10.0, range);
    final displayHeight = max(5.0, maxHeight);

    final marginX = size.width * 0.10;
    final marginY = size.height * 0.16;

    final scaleX = (size.width - 2 * marginX) / displayRange;
    final scaleY = (size.height - 2 * marginY) / (displayHeight * 1.30);
    final scale = min(scaleX, scaleY);

    final originX = marginX;
    final originY = size.height - marginY;

    // Canvas background (Clean Apple surface)
    final bgRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final bgShader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFFFFFF), Color(0xFFF9F9FA)],
    ).createShader(bgRect);
    canvas.drawRect(bgRect, Paint()..shader = bgShader);

    // Ground (Clean neutral line and subtle underfill, NO green grass)
    canvas.drawLine(
      Offset(0, originY),
      Offset(size.width, originY),
      _groundPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, originY + 1, size.width, size.height - originY - 1),
      _groundUnderPaint,
    );

    // Grid & Axes
    _drawGrid(canvas, originX, originY, scale, displayRange, displayHeight);
    _drawAxes(canvas, originX, originY, scale, displayRange, displayHeight);

    // Trajectory path
    _drawTrajectory(canvas, originX, originY, scale, thetaRad);

    final activeFlightTime = max(0.001, totalFlightTime);
    final activeDuration = activeFlightTime + 0.8;
    final currentTime = progress * activeDuration;
    final t = min(currentTime, activeFlightTime);

    final pos = _calculatePosition(t, thetaRad);

    // Ghost Trajectory Trail
    if (showTrajectoryTrail) {
      _drawGhostTrail(canvas, originX, originY, scale, thetaRad, t);
    }

    // Ball
    _drawBall(canvas, originX, originY, scale, pos);

    // Dynamic Physics Vectors
    if (t < activeFlightTime) {
      _drawVectors(canvas, originX, originY, scale, pos, t, thetaRad);
    }

    // Telemetry HUD
    if (showTelemetryHud) {
      _drawTelemetryHud(canvas, size, t, pos, thetaRad);
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
        Offset(px, originY - displayHeight * 1.30 * scale),
        _gridPaint,
      );
    }

    for (double y = 0; y <= displayHeight * 1.30; y += stepY) {
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
    canvas.drawLine(
      Offset(originX, originY),
      Offset(originX + displayRange * scale, originY),
      _axisPaint,
    );
    canvas.drawLine(
      Offset(originX, originY),
      Offset(originX, originY - displayHeight * 1.30 * scale),
      _axisPaint,
    );

    _drawText(
      canvas,
      'Distance (m)',
      originX + displayRange * scale / 2 - 35,
      originY + 12,
      size: 10,
      bold: true,
    );
    _drawText(
      canvas,
      'Height (m)',
      originX - 10,
      originY - displayHeight * 1.30 * scale - 16,
      size: 10,
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
    const int segments = 60;

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

  void _drawGhostTrail(
    Canvas canvas,
    double originX,
    double originY,
    double scale,
    double thetaRad,
    double currentT,
  ) {
    const int dotCount = 18;
    for (int i = 0; i <= dotCount; i++) {
      final dotT = (i / dotCount) * currentT;
      if (dotT > currentT) break;
      final pos = _calculatePosition(dotT, thetaRad);
      final px = originX + pos.dx * scale;
      final py = originY - pos.dy * scale;

      canvas.drawCircle(Offset(px, py), 2.5, _trailDotPaint);
    }
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

    canvas.drawCircle(Offset(px, originY), 9, _shadowPaint);
    canvas.drawCircle(Offset(px, py), 10, _ballPaint);
    canvas.drawCircle(Offset(px - 3, py - 3), 3.5, _highlightPaint);
  }

  void _drawVectors(
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

    final vectorScale = max(0.6, 0.13 * scale);
    final endVxX = px + vx * vectorScale;
    final endVyY = py - vy * vectorScale;
    final endX = px + vx * vectorScale;
    final endY = py - vy * vectorScale;

    // 1. Decomposed Components (vx/vy in dark neutral)
    if (showComponents) {
      // Horizontal component (vx)
      canvas.drawLine(Offset(px, py), Offset(endVxX, py), _vxPaint);
      _drawArrowHead(
        canvas,
        Offset(px, py),
        Offset(endVxX, py),
        _vxArrowPaint,
        7,
      );
      _drawText(
        canvas,
        'vx=${vx.toStringAsFixed(1)}',
        endVxX + 3,
        py - 12,
        size: 9,
        bold: true,
        color: const Color(0xFF1C1C1E),
      );

      // Vertical component (vy)
      canvas.drawLine(Offset(px, py), Offset(px, endVyY), _vyPaint);
      _drawArrowHead(
        canvas,
        Offset(px, py),
        Offset(px, endVyY),
        _vyArrowPaint,
        7,
      );
      _drawText(
        canvas,
        'vy=${vy.toStringAsFixed(1)}',
        px - 46,
        endVyY - 6,
        size: 9,
        bold: true,
        color: const Color(0xFF1C1C1E),
      );

      // Dashed guide lines
      canvas.drawLine(
        Offset(endVxX, py),
        Offset(endX, endY),
        _componentDashedPaint,
      );
      canvas.drawLine(
        Offset(px, endVyY),
        Offset(endX, endY),
        _componentDashedPaint,
      );
    }

    // 2. Velocity Resultant Vector (v in orange)
    if (showVelocityVector) {
      canvas.drawLine(Offset(px, py), Offset(endX, endY), _velocityVectorPaint);
      _drawArrowHead(
        canvas,
        Offset(px, py),
        Offset(endX, endY),
        _velocityArrowHeadPaint,
        9,
      );

      final speed = sqrt(vx * vx + vy * vy);
      _drawText(
        canvas,
        'v=${speed.toStringAsFixed(1)}m/s',
        endX + 5,
        endY - 6,
        size: 10,
        bold: true,
        color: const Color(0xFFFF6B00),
      );
    }

    // 3. Gravity Vector (downward in slate)
    if (showGravityVector) {
      const gVectorLen = 28.0;
      final gEndY = py + gVectorLen;
      canvas.drawLine(Offset(px, py), Offset(px, gEndY), _gravityVectorPaint);
      _drawArrowHead(
        canvas,
        Offset(px, py),
        Offset(px, gEndY),
        _gravityArrowHeadPaint,
        7,
      );
      _drawText(
        canvas,
        'g=${g.toStringAsFixed(1)}',
        px + 4,
        gEndY - 4,
        size: 9,
        bold: true,
        color: const Color(0xFF636366),
      );
    }
  }

  void _drawArrowHead(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    double arrowSize,
  ) {
    final angle = atan2(end.dy - start.dy, end.dx - start.dx);
    final path = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - arrowSize * cos(angle - pi / 6),
        end.dy - arrowSize * sin(angle - pi / 6),
      )
      ..lineTo(
        end.dx - arrowSize * cos(angle + pi / 6),
        end.dy - arrowSize * sin(angle + pi / 6),
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawTelemetryHud(
    Canvas canvas,
    Size size,
    double t,
    Offset pos,
    double thetaRad,
  ) {
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

    final vx = U * cos(thetaRad);
    final vy = U * sin(thetaRad) - g * t;
    final speed = sqrt(vx * vx + vy * vy);

    _drawText(
      canvas,
      'TELEMETRY HUD',
      hudX + 16,
      hudY + 6,
      size: 8.5,
      bold: true,
      color: const Color(0xFFFF8A3D),
    );
    _drawText(
      canvas,
      't  : ${t.toStringAsFixed(2)} s',
      hudX + 8,
      hudY + 20,
      size: 9,
      color: Colors.white70,
    );
    _drawText(
      canvas,
      'x  : ${pos.dx.toStringAsFixed(1)} m',
      hudX + 8,
      hudY + 33,
      size: 9,
      color: Colors.white70,
    );
    _drawText(
      canvas,
      'y  : ${pos.dy.toStringAsFixed(1)} m',
      hudX + 8,
      hudY + 46,
      size: 9,
      color: Colors.white70,
    );
    _drawText(
      canvas,
      '|v|: ${speed.toStringAsFixed(1)} m/s',
      hudX + 8,
      hudY + 59,
      size: 9,
      bold: true,
      color: const Color(0xFFFF8A3D),
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
        oldDelegate.g != g ||
        oldDelegate.showVelocityVector != showVelocityVector ||
        oldDelegate.showComponents != showComponents ||
        oldDelegate.showGravityVector != showGravityVector ||
        oldDelegate.showTrajectoryTrail != showTrajectoryTrail ||
        oldDelegate.showTelemetryHud != showTelemetryHud;
  }
}
