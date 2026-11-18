import 'package:flutter/material.dart';

/// CustomPainter for the sweeping scan line inside the glass tile glyph.
/// Sweeps top-to-bottom with a soft vertical gradient trail behind it.
class ScanLinePainter extends CustomPainter {
  final double progress;
  final Color color;

  const ScanLinePainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final clamped = progress.clamp(0.0, 1.0);
    final currentY = size.height * clamped;

    // Fade out softly as it reaches the bottom bracket
    final fade = clamped > 0.82
        ? ((1.0 - clamped) / 0.18).clamp(0.0, 1.0)
        : 1.0;

    const trailHeight = 16.0;
    final topY = (currentY - trailHeight).clamp(0.0, size.height);

    // 1. Soft vertical trail behind the sweep
    final trailRect = Rect.fromLTRB(4.0, topY, size.width - 4.0, currentY);
    final trailPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.22 * fade),
        ],
      ).createShader(trailRect);

    canvas.drawRect(trailRect, trailPaint);

    // 2. Crisp 1.5 pt horizontal scan line
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.85 * fade)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(4.0, currentY),
      Offset(size.width - 4.0, currentY),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant ScanLinePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

/// CustomPainter for the subtle parabolic arc (projectile trajectory)
/// launching from the glass tile's right edge, terminating in a small orange dot.
class ProjectileArcPainter extends CustomPainter {
  final double progress;
  final Color color;

  const ProjectileArcPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    final clamped = progress.clamp(0.0, 1.0);

    // Physical parabolic trajectory modeled via Quadratic Bézier
    final p0 = Offset(0.0, size.height * 0.55);
    final pControl = Offset(size.width * 0.44, 0.0);
    final pEnd = Offset(size.width, size.height * 0.72);

    final path = Path();
    path.moveTo(p0.dx, p0.dy);
    path.quadraticBezierTo(pControl.dx, pControl.dy, pEnd.dx, pEnd.dy);

    final metrics = path.computeMetrics().firstOrNull;
    if (metrics == null) return;

    final totalLength = metrics.length;
    final currentLength = totalLength * clamped;
    final extractedPath = metrics.extractPath(0.0, currentLength);

    // 1. Subtle 1.5 pt stroke, orange at 60% opacity
    final arcPaint = Paint()
      ..color = color.withValues(alpha: 0.60)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(extractedPath, arcPaint);

    // 2. Small orange dot at the projectile tip
    final tangent = metrics.getTangentForOffset(currentLength);
    if (tangent != null) {
      // Soft outer glow halo
      final haloPaint = Paint()
        ..color = color.withValues(alpha: 0.22)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(tangent.position, 4.5, haloPaint);

      // Core orange dot (2.5 pt radius)
      final dotPaint = Paint()
        ..color = color.withValues(alpha: 0.95)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(tangent.position, 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ProjectileArcPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
