import 'package:flutter/material.dart';

/// Spacing and layout tokens following Apple HIG 8-pt grid.
/// Tokens: 4, 8, 12, 16, 20, 24, 32, 40.
class AppSpacing {
  AppSpacing._();

  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;

  // Semantic size aliases
  static const double xs = space4;
  static const double sm = space8;
  static const double md = space16;
  static const double lg = space24;
  static const double xl = space32;
  static const double xxl = space40;

  /// Standard screen side margin (20 dp)
  static const double screenMargin = space20;

  /// Standard gap between major sections (32 dp)
  static const double sectionGap = space32;

  /// Standard internal card padding (20 dp)
  static const double cardPaddingVal = space20;

  /// Standard gap between stacked cards (16 dp)
  static const double cardGap = space16;

  /// Standard gap between rows inside a card (12 dp)
  static const double cardRowGap = space12;

  /// Standard minimum interactive touch target (44x44 dp)
  static const double minTouchTarget = 44.0;

  /// Standard spacing between adjacent bordered controls (12 dp)
  static const double controlSpacing = space12;

  /// Standard inset row height for grouped lists (56 dp)
  static const double groupedRowMinHeight = 56.0;

  /// Standard primary button height (52 dp)
  static const double buttonHeight = 52.0;

  /// Floating tab bar height (64 dp)
  static const double floatingTabBarHeight = 64.0;

  /// Floating tab bar horizontal inset (16 dp)
  static const double floatingTabBarInset = space16;

  /// Floating tab bar bottom clearance above safe area (12 dp)
  static const double floatingTabBarBottomClearance = space12;

  /// Scroll content bottom padding to prevent content from hiding behind floating tab bar (88 dp)
  static const double scrollBottomPadding = floatingTabBarHeight + space24;

  /// Max content width for regular / tablet layouts (600 dp)
  static const double maxContentWidth = 600.0;

  // EdgeInsets presets
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: screenMargin);
  static const EdgeInsets cardPadding = EdgeInsets.all(cardPaddingVal);
  static const EdgeInsets compactCardPadding = EdgeInsets.all(space12);
}
