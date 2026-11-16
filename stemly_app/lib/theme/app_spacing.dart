import 'package:flutter/material.dart';

/// Spacing and layout tokens following Apple HIG grid (4, 8, 12, 16, 24, 32).
class AppSpacing {
  AppSpacing._();

  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;

  // Semantic size aliases
  static const double xs = space4;
  static const double sm = space8;
  static const double md = space16;
  static const double lg = space24;
  static const double xl = space32;

  /// Standard screen side margin (16 dp)
  static const double screenMargin = 16.0;

  /// Standard minimum interactive touch target (44x44 dp)
  static const double minTouchTarget = 44.0;

  /// Standard spacing between adjacent bordered controls (12 dp)
  static const double controlSpacing = 12.0;

  /// Standard inset row height for grouped lists (56 dp)
  static const double groupedRowMinHeight = 56.0;

  /// Standard primary and secondary button height (52 dp)
  static const double buttonHeight = 52.0;

  // EdgeInsets presets
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: screenMargin);
  static const EdgeInsets screenPaddingWithVertical =
      EdgeInsets.symmetric(horizontal: screenMargin, vertical: space16);
  static const EdgeInsets cardPadding = EdgeInsets.all(space16);
  static const EdgeInsets compactCardPadding = EdgeInsets.all(space12);
}
