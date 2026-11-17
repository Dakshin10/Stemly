// lib/visualiser/declarative_physics_component.dart
import 'dart:math';
import 'package:flutter/material.dart';

import '../presentation/components/glass_surface.dart';
import '../theme/theme.dart';

enum MechanicsSceneType { inclinedPlane, pulley, collision, forceBlock }

/// Declarative 2D Physics Simulator for diverse mechanics problems:
/// - Inclined plane with friction and force vectors (N, mg, f_k, a)
/// - Atwood Machine (Pulley with 2 masses and string tension T)
/// - Collisions & Momentum conservation with coefficient of restitution (e)
/// - General 2D block with applied tension force at angle theta
class DeclarativePhysicsWidget extends StatefulWidget {
  final String scenario; // "inclined_plane", "pulley", "collision", "mechanics_2d"
  final Map<String, double> parameters;
  final Function(Map<String, String>)? onSimulationUpdate;

  const DeclarativePhysicsWidget({
    super.key,
    required this.scenario,
    required this.parameters,
    this.onSimulationUpdate,
  });

  @override
  State<DeclarativePhysicsWidget> createState() => _DeclarativePhysicsWidgetState();
}

class _DeclarativePhysicsWidgetState extends State<DeclarativePhysicsWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  bool _showVectors = true;
  bool _showHud = true;
  bool _showTrail = true;
  bool _isPaused = false;

  MechanicsSceneType get sceneType {
    final s = widget.scenario.toLowerCase();
    if (s.contains("incline") || s.contains("ramp")) return MechanicsSceneType.inclinedPlane;
    if (s.contains("pulley") || s.contains("atwood")) return MechanicsSceneType.pulley;
    if (s.contains("collision") || s.contains("momentum")) return MechanicsSceneType.collision;
    return MechanicsSceneType.forceBlock;
  }

  double _getParam(String key, double fallback) {
    return widget.parameters[key] ?? fallback;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
    if (!_isPaused) {
      _controller.repeat();
    }
    _updateStats();
  }

  @override
  void didUpdateWidget(DeclarativePhysicsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateStats();
  }

  void _updateStats() {
    if (widget.onSimulationUpdate == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final g = _getParam("g", 9.81);
      switch (sceneType) {
        case MechanicsSceneType.inclinedPlane:
          final thetaRad = _getParam("theta", 30.0) * pi / 180.0;
          final mu = _getParam("mu", 0.15);
          final a = max(0.0, g * (sin(thetaRad) - mu * cos(thetaRad)));
          widget.onSimulationUpdate!({
            "Acceleration": "${a.toStringAsFixed(2)} m/s²",
            "Normal Force": "${(cos(thetaRad) * _getParam("m", 5.0) * g).toStringAsFixed(1)} N",
            "Friction": "${(mu * cos(thetaRad) * _getParam("m", 5.0) * g).toStringAsFixed(1)} N",
          });
          break;

        case MechanicsSceneType.pulley:
          final m1 = _getParam("m1", 6.0);
          final m2 = _getParam("m2", 4.0);
          final a = ((m1 - m2).abs() / (m1 + m2)) * g;
          final T = (2 * m1 * m2 / (m1 + m2)) * g;
          widget.onSimulationUpdate!({
            "Acceleration": "${a.toStringAsFixed(2)} m/s²",
            "String Tension": "${T.toStringAsFixed(1)} N",
            "Mass Difference": "${(m1 - m2).abs().toStringAsFixed(1)} kg",
          });
          break;

        case MechanicsSceneType.collision:
          final m1 = _getParam("m1", 3.0);
          final m2 = _getParam("m2", 2.0);
          final u1 = _getParam("u1", 10.0);
          final u2 = _getParam("u2", -5.0);
          final pTotal = m1 * u1 + m2 * u2;
          widget.onSimulationUpdate!({
            "Total Momentum": "${pTotal.toStringAsFixed(1)} kg·m/s",
            "Restitution (e)": _getParam("e", 1.0).toStringAsFixed(2),
          });
          break;

        case MechanicsSceneType.forceBlock:
          final F = _getParam("F", 25.0);
          final thetaRad = _getParam("theta", 20.0) * pi / 180.0;
          final m = _getParam("m", 5.0);
          final mu = _getParam("mu", 0.2);
          final normal = max(0.0, m * g - F * sin(thetaRad));
          final fK = mu * normal;
          final a = max(0.0, (F * cos(thetaRad) - fK) / m);
          widget.onSimulationUpdate!({
            "Acceleration": "${a.toStringAsFixed(2)} m/s²",
            "Normal Force": "${normal.toStringAsFixed(1)} N",
            "Friction": "${fK.toStringAsFixed(1)} N",
          });
          break;
      }
    });
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
                  painter: _DeclarativePhysicsPainter(
                    sceneType: sceneType,
                    params: widget.parameters,
                    progress: _controller.value,
                    showVectors: _showVectors,
                    showHud: _showHud,
                    showTrail: _showTrail,
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
                    label: "Vectors",
                    isActive: _showVectors,
                    onTap: () => setState(() => _showVectors = !_showVectors),
                  ),
                  _controlChip(
                    label: "Trail",
                    isActive: _showTrail,
                    onTap: () => setState(() => _showTrail = !_showTrail),
                  ),
                  _controlChip(
                    label: "HUD",
                    isActive: _showHud,
                    onTap: () => setState(() => _showHud = !_showHud),
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

class _DeclarativePhysicsPainter extends CustomPainter {
  final MechanicsSceneType sceneType;
  final Map<String, double> params;
  final double progress;
  final bool showVectors;
  final bool showHud;
  final bool showTrail;

  static final Paint _rampPaint = Paint()..color = const Color(0xFFCBD5E1);
  static final Paint _rampEdgePaint = Paint()
    ..color = const Color(0xFF475569)
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;

  static final Paint _blockPaint = Paint()..color = const Color(0xFFEA580C);
  static final Paint _blockHighlight = Paint()..color = const Color(0xB3FFFFFF);
  static final Paint _pulleyPaint = Paint()..color = const Color(0xFF64748B);
  static final Paint _cordPaint = Paint()
    ..color = const Color(0xFF1E293B)
    ..strokeWidth = 2.0;

  static final Paint _hudBgPaint = Paint()
    ..color = const Color(0xCC0F172A)
    ..style = PaintingStyle.fill;
  static final Paint _hudBorderPaint = Paint()
    ..color = const Color(0x4038BDF8)
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;

  static final TextPainter _cachedTextPainter = TextPainter(
    textDirection: TextDirection.ltr,
  );

  _DeclarativePhysicsPainter({
    required this.sceneType,
    required this.params,
    required this.progress,
    required this.showVectors,
    required this.showHud,
    required this.showTrail,
  });

  double _p(String key, double fallback) => params[key] ?? fallback;

  @override
  void paint(Canvas canvas, Size size) {
    // Clean Apple surface background
    final bgRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final bgShader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFFFFFF), Color(0xFFF9F9FA)],
    ).createShader(bgRect);
    canvas.drawRect(bgRect, Paint()..shader = bgShader);

    switch (sceneType) {
      case MechanicsSceneType.inclinedPlane:
        _paintInclinedPlane(canvas, size);
        break;
      case MechanicsSceneType.pulley:
        _paintPulley(canvas, size);
        break;
      case MechanicsSceneType.collision:
        _paintCollision(canvas, size);
        break;
      case MechanicsSceneType.forceBlock:
        _paintForceBlock(canvas, size);
        break;
    }
  }

  // -------------------------------------------------------------
  // 1. INCLINED PLANE SCENE
  // -------------------------------------------------------------
  void _paintInclinedPlane(Canvas canvas, Size size) {
    final thetaDeg = _p("theta", 30.0).clamp(10.0, 70.0);
    final thetaRad = thetaDeg * pi / 180.0;
    final m = _p("m", 5.0);
    final mu = _p("mu", 0.15);
    final g = _p("g", 9.81);

    final a = max(0.0, g * (sin(thetaRad) - mu * cos(thetaRad)));

    final groundY = size.height * 0.85;
    final rampBaseWidth = size.width * 0.75;
    final rampHeight = rampBaseWidth * tan(thetaRad);

    final cornerX = size.width * 0.12;
    final peakX = cornerX;
    final peakY = (groundY - rampHeight).clamp(size.height * 0.20, groundY - 40);
    final footX = cornerX + rampBaseWidth;
    final footY = groundY;

    // Draw Ramp Triangle
    final rampPath = Path()
      ..moveTo(cornerX, footY)
      ..lineTo(peakX, peakY)
      ..lineTo(footX, footY)
      ..close();
    canvas.drawPath(rampPath, _rampPaint);
    canvas.drawPath(rampPath, _rampEdgePaint);

    // Ground line
    canvas.drawLine(
      Offset(0, footY),
      Offset(size.width, footY),
      Paint()..color = const Color(0xFF16A34A)..strokeWidth = 3.0,
    );

    // Block position along ramp
    final rampLen = sqrt(pow(footX - peakX, 2) + pow(footY - peakY, 2));
    final unitX = (footX - peakX) / rampLen;
    final unitY = (footY - peakY) / rampLen;

    // Normal unit vector (pointing outward from ramp)
    final normX = -unitY;
    final normY = unitX;

    final travelFraction = progress.clamp(0.0, 1.0);
    final currentDist = 30.0 + travelFraction * (rampLen - 70.0);

    final blockCenterX = peakX + unitX * currentDist - normX * 14.0;
    final blockCenterY = peakY + unitY * currentDist - normY * 14.0;

    // Draw Block (rotated to match slope)
    canvas.save();
    canvas.translate(blockCenterX, blockCenterY);
    canvas.rotate(thetaRad);

    const bW = 28.0;
    const bH = 20.0;
    final blockRect = Rect.fromCenter(center: Offset.zero, width: bW, height: bH);
    canvas.drawRRect(RRect.fromRectAndRadius(blockRect, const Radius.circular(4)), _blockPaint);
    canvas.drawCircle(const Offset(-4, -4), 3, _blockHighlight);
    canvas.restore();

    // Force Vectors
    if (showVectors) {
      final center = Offset(blockCenterX, blockCenterY);

      // 1. Gravity (mg downward in red)
      final mgLen = 35.0;
      final mgEnd = center + Offset(0, mgLen);
      _drawVector(canvas, center, mgEnd, const Color(0xFFEF4444), "mg");

      // 2. Normal Force (N outward perpendicular in cyan)
      final nLen = 30.0;
      final nEnd = center + Offset(normX * nLen, normY * nLen);
      _drawVector(canvas, center, nEnd, const Color(0xFF06B6D4), "N");

      // 3. Friction (f_k opposing motion up the ramp in amber)
      if (mu > 0.01) {
        final fLen = 22.0;
        final fEnd = center - Offset(unitX * fLen, unitY * fLen);
        _drawVector(canvas, center, fEnd, const Color(0xFFF59E0B), "fk");
      }

      // 4. Net Acceleration (green arrow down the ramp)
      if (a > 0.05) {
        final aLen = 32.0;
        final aEnd = center + Offset(unitX * aLen, unitY * aLen);
        _drawVector(canvas, center, aEnd, const Color(0xFF10B981), "a=${a.toStringAsFixed(1)}");
      }
    }

    if (showHud) {
      final normal = m * g * cos(thetaRad);
      final friction = mu * normal;
      _drawHudBox(canvas, size, [
        "INCLINED PLANE HUD",
        "θ   : ${thetaDeg.toStringAsFixed(0)}°",
        "a   : ${a.toStringAsFixed(2)} m/s²",
        "N   : ${normal.toStringAsFixed(1)} N",
        "fk  : ${friction.toStringAsFixed(1)} N",
      ]);
    }
  }

  // -------------------------------------------------------------
  // 2. ATWOOD MACHINE (PULLEY) SCENE
  // -------------------------------------------------------------
  void _paintPulley(Canvas canvas, Size size) {
    final m1 = _p("m1", 6.0);
    final m2 = _p("m2", 4.0);
    final g = _p("g", 9.81);

    final a = ((m1 - m2).abs() / (m1 + m2)) * g;
    final T = (2 * m1 * m2 / (m1 + m2)) * g;

    final pulleyCenter = Offset(size.width * 0.5, size.height * 0.25);
    const pulleyR = 24.0;

    // Pulley support bracket
    canvas.drawLine(
      Offset(pulleyCenter.dx, 0),
      pulleyCenter,
      Paint()..color = Colors.black87..strokeWidth = 4.0,
    );

    // Pulley Wheel
    canvas.drawCircle(pulleyCenter, pulleyR, _pulleyPaint);
    canvas.drawCircle(pulleyCenter, 5, Paint()..color = Colors.white);

    // Motion offset based on which mass is heavier
    final maxTravel = 70.0;
    final travel = (progress * maxTravel) * (m1 >= m2 ? 1 : -1);

    final m1CenterY = size.height * 0.55 + travel;
    final m2CenterY = size.height * 0.55 - travel;

    final m1X = pulleyCenter.dx - pulleyR;
    final m2X = pulleyCenter.dx + pulleyR;

    // Cord
    canvas.drawLine(Offset(m1X, pulleyCenter.dy), Offset(m1X, m1CenterY), _cordPaint);
    canvas.drawLine(Offset(m2X, pulleyCenter.dy), Offset(m2X, m2CenterY), _cordPaint);

    // Masses (scaled visually by mass)
    final r1 = (14.0 + (m1 / 50.0) * 16.0).clamp(14.0, 30.0);
    final r2 = (14.0 + (m2 / 50.0) * 16.0).clamp(14.0, 30.0);

    // Block 1
    final b1Rect = Rect.fromCenter(center: Offset(m1X, m1CenterY), width: r1 * 2, height: r1 * 1.6);
    canvas.drawRRect(RRect.fromRectAndRadius(b1Rect, const Radius.circular(6)), _blockPaint);
    _drawText(canvas, "m1=${m1.toStringAsFixed(1)}", m1X - 16, m1CenterY - 6, size: 9, bold: true, color: Colors.white);

    // Block 2
    final b2Rect = Rect.fromCenter(center: Offset(m2X, m2CenterY), width: r2 * 2, height: r2 * 1.6);
    canvas.drawRRect(RRect.fromRectAndRadius(b2Rect, const Radius.circular(6)), Paint()..color = const Color(0xFF2C2C2E));
    _drawText(canvas, "m2=${m2.toStringAsFixed(1)}", m2X - 16, m2CenterY - 6, size: 9, bold: true, color: Colors.white);

    if (showVectors) {
      // String Tension T (upward)
      _drawVector(canvas, Offset(m1X, m1CenterY - r1 * 0.8), Offset(m1X, m1CenterY - r1 * 0.8 - 26), const Color(0xFF06B6D4), "T");
      _drawVector(canvas, Offset(m2X, m2CenterY - r2 * 0.8), Offset(m2X, m2CenterY - r2 * 0.8 - 26), const Color(0xFF06B6D4), "T");

      // Gravity mg (downward)
      _drawVector(canvas, Offset(m1X, m1CenterY + r1 * 0.8), Offset(m1X, m1CenterY + r1 * 0.8 + 28), const Color(0xFFEF4444), "m1g");
      _drawVector(canvas, Offset(m2X, m2CenterY + r2 * 0.8), Offset(m2X, m2CenterY + r2 * 0.8 + 28), const Color(0xFFEF4444), "m2g");
    }

    if (showHud) {
      _drawHudBox(canvas, size, [
        "ATWOOD PULLEY HUD",
        "m1  : ${m1.toStringAsFixed(1)} kg",
        "m2  : ${m2.toStringAsFixed(1)} kg",
        "a   : ${a.toStringAsFixed(2)} m/s²",
        "T   : ${T.toStringAsFixed(1)} N",
      ]);
    }
  }

  // -------------------------------------------------------------
  // 3. 1D/2D COLLISION SCENE
  // -------------------------------------------------------------
  void _paintCollision(Canvas canvas, Size size) {
    final m1 = _p("m1", 3.0);
    final m2 = _p("m2", 2.0);
    final u1 = _p("u1", 10.0);
    final u2 = _p("u2", -5.0);
    final e = _p("e", 1.0).clamp(0.0, 1.0);

    // Post collision velocities
    final v1 = ((m1 - e * m2) * u1 + (1 + e) * m2 * u2) / (m1 + m2);
    final v2 = ((1 + e) * m1 * u1 + (m2 - e * m1) * u2) / (m1 + m2);

    final trackY = size.height * 0.60;

    // Track
    canvas.drawLine(
      Offset(size.width * 0.05, trackY),
      Offset(size.width * 0.95, trackY),
      Paint()..color = const Color(0xFF64748B)..strokeWidth = 3.0,
    );

    const collisionProgress = 0.5;
    final r1 = (14.0 + (m1 / 20.0) * 12.0).clamp(14.0, 26.0);
    final r2 = (14.0 + (m2 / 20.0) * 12.0).clamp(14.0, 26.0);

    final impactX = size.width * 0.50;

    double x1, x2;
    if (progress < collisionProgress) {
      final tPhase = progress / collisionProgress;
      x1 = size.width * 0.15 + tPhase * (impactX - r1 - size.width * 0.15);
      x2 = size.width * 0.85 - tPhase * (size.width * 0.85 - impactX - r2);
    } else {
      final tPhase = (progress - collisionProgress) / (1.0 - collisionProgress);
      x1 = (impactX - r1) - tPhase * (impactX - r1 - size.width * 0.10);
      x2 = (impactX + r2) + tPhase * (size.width * 0.90 - impactX - r2);
    }

    final y1 = trackY - r1;
    final y2 = trackY - r2;

    // Ball 1
    canvas.drawCircle(Offset(x1, y1), r1, _blockPaint);
    _drawText(canvas, "m1", x1 - 6, y1 - 5, size: 9, bold: true, color: Colors.white);

    // Ball 2
    canvas.drawCircle(Offset(x2, y2), r2, Paint()..color = const Color(0xFF2C2C2E));
    _drawText(canvas, "m2", x2 - 6, y2 - 5, size: 9, bold: true, color: Colors.white);

    if (showVectors) {
      final curV1 = progress < collisionProgress ? u1 : v1;
      final curV2 = progress < collisionProgress ? u2 : v2;

      final arrowLen1 = (curV1 * 2.2).clamp(-50.0, 50.0);
      final arrowLen2 = (curV2 * 2.2).clamp(-50.0, 50.0);

      _drawVector(canvas, Offset(x1, y1), Offset(x1 + arrowLen1, y1), const Color(0xFF10B981), "v1=${curV1.toStringAsFixed(1)}");
      _drawVector(canvas, Offset(x2, y2), Offset(x2 + arrowLen2, y2), const Color(0xFF06B6D4), "v2=${curV2.toStringAsFixed(1)}");
    }

    if (showHud) {
      final pInit = m1 * u1 + m2 * u2;
      _drawHudBox(canvas, size, [
        "COLLISION & MOMENTUM",
        "e   : ${e.toStringAsFixed(2)}",
        "P   : ${pInit.toStringAsFixed(1)} kg·m/s",
        "v1' : ${v1.toStringAsFixed(1)} m/s",
        "v2' : ${v2.toStringAsFixed(1)} m/s",
      ]);
    }
  }

  // -------------------------------------------------------------
  // 4. GENERAL 2D FORCE BLOCK SCENE
  // -------------------------------------------------------------
  void _paintForceBlock(Canvas canvas, Size size) {
    final F = _p("F", 25.0);
    final thetaDeg = _p("theta", 20.0).clamp(0.0, 75.0);
    final thetaRad = thetaDeg * pi / 180.0;
    final m = _p("m", 5.0);
    final mu = _p("mu", 0.2);
    final g = _p("g", 9.81);

    final normal = max(0.0, m * g - F * sin(thetaRad));
    final fK = mu * normal;
    final a = max(0.0, (F * cos(thetaRad) - fK) / m);

    final groundY = size.height * 0.70;

    // Ground
    canvas.drawLine(
      Offset(0, groundY),
      Offset(size.width, groundY),
      Paint()..color = const Color(0xFF334155)..strokeWidth = 3.0,
    );

    const bW = 44.0;
    const bH = 30.0;

    final travel = progress * (size.width * 0.45);
    final blockX = size.width * 0.15 + travel;
    final blockY = groundY - bH / 2;

    final blockRect = Rect.fromCenter(center: Offset(blockX, blockY), width: bW, height: bH);
    canvas.drawRRect(RRect.fromRectAndRadius(blockRect, const Radius.circular(6)), _blockPaint);

    if (showVectors) {
      final center = Offset(blockX, blockY);

      // Applied Force F at angle theta
      final fLen = 42.0;
      final fEnd = center + Offset(fLen * cos(-thetaRad), fLen * sin(-thetaRad));
      _drawVector(canvas, center, fEnd, const Color(0xFF8B5CF6), "F=${F.toStringAsFixed(0)}N");

      // Gravity mg
      _drawVector(canvas, center, center + const Offset(0, 32), const Color(0xFFEF4444), "mg");

      // Normal N
      _drawVector(canvas, center, center - const Offset(0, 30), const Color(0xFF06B6D4), "N");

      // Friction fk
      if (fK > 0.1) {
        _drawVector(canvas, Offset(blockX - bW / 2, groundY), Offset(blockX - bW / 2 - 25, groundY), const Color(0xFFF59E0B), "fk");
      }
    }

    if (showHud) {
      _drawHudBox(canvas, size, [
        "2D FORCE DYNAMICS",
        "F   : ${F.toStringAsFixed(1)} N",
        "θ   : ${thetaDeg.toStringAsFixed(0)}°",
        "a   : ${a.toStringAsFixed(2)} m/s²",
        "N   : ${normal.toStringAsFixed(1)} N",
      ]);
    }
  }

  void _drawVector(Canvas canvas, Offset start, Offset end, Color color, String label) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(start, end, paint);

    final angle = atan2(end.dy - start.dy, end.dx - start.dx);
    const arrowSize = 7.0;
    final path = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(end.dx - arrowSize * cos(angle - pi / 6), end.dy - arrowSize * sin(angle - pi / 6))
      ..lineTo(end.dx - arrowSize * cos(angle + pi / 6), end.dy - arrowSize * sin(angle + pi / 6))
      ..close();
    canvas.drawPath(path, Paint()..color = color);

    _drawText(canvas, label, end.dx + 4, end.dy - 6, size: 9, bold: true, color: color);
  }

  void _drawHudBox(Canvas canvas, Size size, List<String> lines) {
    const hudW = 125.0;
    final hudH = 18.0 + lines.length * 12.0;
    final hudX = size.width - hudW - 12.0;
    const hudY = 10.0;

    final hudRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(hudX, hudY, hudW, hudH),
      const Radius.circular(10),
    );

    canvas.drawRRect(hudRRect, _hudBgPaint);
    canvas.drawRRect(hudRRect, _hudBorderPaint);

    for (int i = 0; i < lines.length; i++) {
      final isHeader = i == 0;
      _drawText(
        canvas,
        lines[i],
        hudX + (isHeader ? 12 : 8),
        hudY + 6 + i * 13,
        size: isHeader ? 8.5 : 9.0,
        bold: isHeader,
        color: isHeader ? const Color(0xFF38BDF8) : (i == 2 ? const Color(0xFF4ADE80) : Colors.white70),
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
  bool shouldRepaint(covariant _DeclarativePhysicsPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.showVectors != showVectors ||
        oldDelegate.showHud != showHud ||
        oldDelegate.sceneType != sceneType;
  }
}
