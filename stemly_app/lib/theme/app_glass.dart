import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Specification and recipe for Apple Liquid Glass materials.
///
/// Liquid Glass is reserved for controls and navigation floating above content:
/// - Floating tab bar
/// - Top nav bar when content scrolls beneath
/// - Visualiser toolbar & telemetry HUD
/// - AI assistant composer
/// - Modal sheets and dialogs
///
/// Content surfaces (cards, accordions, notes, equations) remain flat and solid.
enum GlassVariant {
  /// Default recipe for controls and navigation floating above content.
  regular,

  /// Lightweight recipe used only over rich media/simulations.
  clear,
}

class AppGlass {
  AppGlass._();

  // Blur Sigmas
  static const double sigmaRegular = 28.0;
  static const double sigmaClear = 12.0;

  // Tint Opacities
  static const double tintLightRegular = 0.65; // 60-68%
  static const double tintDarkRegular = 0.55; // 50-58%
  static const double tintClear = 0.08;

  // Specular Highlight
  static const double specularTopAlpha = 0.22;

  // Edge Stroke Gradients
  static const double strokeTopLeftLight = 0.55;
  static const double strokeBottomRightLight = 0.06;
  static const double strokeTopLeftDark = 0.30;
  static const double strokeBottomRightDark = 0.04;

  // Soft Glass Shadow
  static const BoxShadow glassShadow = BoxShadow(
    color: Color(0x1A000000), // Black 10%
    blurRadius: 24.0,
    offset: Offset(0, 8),
  );

  // Saturation Boost ColorFilter Matrix (~1.6x saturation)
  static const ColorFilter saturationFilter = ColorFilter.matrix(<double>[
    1.4,
    -0.2,
    -0.2,
    0.0,
    0.0,
    -0.2,
    1.4,
    -0.2,
    0.0,
    0.0,
    -0.2,
    -0.2,
    1.4,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    1.0,
    0.0,
  ]);

  /// Checks if reduced transparency or high contrast is active
  static bool shouldUseOpaqueFallback(BuildContext context) {
    final media = MediaQuery.of(context);
    return media.highContrast || media.accessibleNavigation;
  }

  /// Tint color based on variant and brightness
  static Color getTintColor(BuildContext context, GlassVariant variant) {
    final isDark = AppColors.isDark(context);
    if (variant == GlassVariant.clear) {
      return (isDark ? Colors.black : Colors.white).withValues(
        alpha: tintClear,
      );
    }
    return isDark
        ? AppColors.surfaceDark.withValues(alpha: tintDarkRegular)
        : Colors.white.withValues(alpha: tintLightRegular);
  }

  /// 1 dp stroke border gradient for glass edges
  static LinearGradient getStrokeGradient(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              Colors.white.withValues(alpha: strokeTopLeftDark),
              Colors.white.withValues(alpha: strokeBottomRightDark),
            ]
          : [
              Colors.white.withValues(alpha: strokeTopLeftLight),
              Colors.white.withValues(alpha: strokeBottomRightLight),
            ],
    );
  }
}
