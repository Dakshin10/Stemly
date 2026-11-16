import 'dart:ui';
import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// Reusable Apple Liquid Glass Surface widget.
///
/// Implements the multi-layer Liquid Glass recipe:
/// 1. ClipPath (Superellipse or Capsule)
/// 2. BackdropFilter (Sigma 24-30 blur + saturation boost ColorFilter matrix)
/// 3. Tint fill (White 65% in Light, #1C1C1E 55% in Dark)
/// 4. Specular highlight (top 40% vertical gradient, White 22% to 0%)
/// 5. 1 dp edge stroke with gradient (Top-Left 55% to Bottom-Right 6%)
/// 6. Soft glass shadow (Black 10%, blur 24, offset 0, 8)
///
/// Gracefully falls back to opaque surface with 1 dp solid border when
/// Reduce Transparency, High Contrast, or accessibility navigation is enabled.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final GlassVariant variant;
  final BorderRadius? borderRadius;
  final ShapeBorder? shape;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final Color? tint;

  const GlassSurface({
    super.key,
    required this.child,
    this.variant = GlassVariant.regular,
    this.borderRadius,
    this.shape,
    this.padding,
    this.width,
    this.height,
    this.tint,
  });

  /// Factory for a Capsule-shaped Glass Surface (Floating Tab Bar / Pill button)
  factory GlassSurface.capsule({
    required Widget child,
    GlassVariant variant = GlassVariant.regular,
    EdgeInsetsGeometry? padding,
    double? width,
    double? height,
    Color? tint,
  }) {
    return GlassSurface(
      variant: variant,
      borderRadius: BorderRadius.circular(100),
      padding: padding,
      width: width,
      height: height,
      tint: tint,
      child: child,
    );
  }

  /// Factory for a Superellipse Toolbar Glass Surface (20 dp radius)
  factory GlassSurface.toolbar({
    required Widget child,
    GlassVariant variant = GlassVariant.regular,
    EdgeInsetsGeometry? padding,
    double? width,
    double? height,
  }) {
    return GlassSurface(
      variant: variant,
      borderRadius: BorderRadius.circular(AppRadii.toolbar),
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      width: width,
      height: height,
      child: child,
    );
  }

  /// Factory for a Sheet / Composer Glass Surface (28 dp radius)
  factory GlassSurface.sheet({
    required Widget child,
    GlassVariant variant = GlassVariant.regular,
    EdgeInsetsGeometry? padding,
    double? width,
    double? height,
  }) {
    return GlassSurface(
      variant: variant,
      borderRadius: BorderRadius.circular(AppRadii.sheet),
      padding: padding ?? const EdgeInsets.all(AppSpacing.cardPaddingVal),
      width: width,
      height: height,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(AppRadii.card);

    // Accessibility Fallback: Replace glass with opaque surface
    if (AppGlass.shouldUseOpaqueFallback(context)) {
      return RepaintBoundary(
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: effectiveRadius,
            border: Border.all(color: AppColors.divider(context), width: 1.0),
          ),
          child: child,
        ),
      );
    }

    final double sigma = variant == GlassVariant.clear
        ? AppGlass.sigmaClear
        : AppGlass.sigmaRegular;

    final Color effectiveTint = tint ?? AppGlass.getTintColor(context, variant);
    final strokeGradient = AppGlass.getStrokeGradient(context);

    return RepaintBoundary(
      child: Container(
        width: width,
        height: height,
        decoration: const BoxDecoration(
          boxShadow: [AppGlass.glassShadow],
        ),
        child: CustomPaint(
          foregroundPainter: _GlassBorderPainter(
            borderRadius: effectiveRadius,
            gradient: strokeGradient,
            strokeWidth: 1.0,
          ),
          child: ClipRRect(
            borderRadius: effectiveRadius,
            child: BackdropFilter(
              filter: ImageFilter.compose(
                outer: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                inner: AppGlass.saturationFilter,
              ),
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  // Layer 1: Tint fill
                  Container(color: effectiveTint),

                  // Layer 2: Media dimming for 'clear' variant
                  if (variant == GlassVariant.clear)
                    Container(color: Colors.black.withValues(alpha: 0.35)),

                  // Layer 3: Specular highlight (top 40% vertical gradient)
                  Positioned.fill(
                    child: FractionallySizedBox(
                      alignment: Alignment.topCenter,
                      heightFactor: 0.40,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: AppGlass.specularTopAlpha),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Layer 4: Content
                  Padding(
                    padding: padding ?? EdgeInsets.zero,
                    child: child,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for the 1 dp gradient glass edge stroke
class _GlassBorderPainter extends CustomPainter {
  final BorderRadius borderRadius;
  final LinearGradient gradient;
  final double strokeWidth;

  _GlassBorderPainter({
    required this.borderRadius,
    required this.gradient,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect).deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = gradient.createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_GlassBorderPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.gradient != gradient ||
      oldDelegate.strokeWidth != strokeWidth;
}
