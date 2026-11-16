import 'package:flutter/material.dart';

/// Design tokens for STEMLY colors following Apple HIG Liquid Glass material
/// and the 15-20% Orange Accent Rule.
///
/// Neutrals are 80-85% of every screen.
/// Orange is the accent, averaging 15-20% of visible area (5-10% on dense reading screens).
/// Never use orange as a full-screen background.
///
/// Contrast rules:
/// - Black text on orange fill (#FF6B00) has 7:1 contrast ratio.
/// - White text on orange is strictly forbidden (fails 4.5:1).
/// - Orange text on white uses #C24100 (5:1).
/// - Orange text on black uses #FF8A3D (7.5:1).
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------------
  // LIGHT PALETTE (80-85% Neutrals)
  // ---------------------------------------------------------------------------
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF5F5F7);
  static const Color surfaceVariantLight = Color(0xFFEDEDF0); // surface2
  static const Color textPrimaryLight = Color(0xFF000000);
  static const Color textSecondaryLight = Color(0xFF6E6E73);
  static const Color dividerLight = Color(0xFFD2D2D7);
  static const Color scrimLight = Color(0x66000000);

  // ---------------------------------------------------------------------------
  // DARK PALETTE (80-85% Neutrals)
  // ---------------------------------------------------------------------------
  static const Color backgroundDark = Color(0xFF000000);
  static const Color surfaceDark = Color(0xFF1C1C1E);
  static const Color surfaceVariantDark = Color(0xFF2C2C2E); // surface2
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFAEAEB2);
  static const Color dividerDark = Color(0xFF38383A);
  static const Color scrimDark = Color(0x99000000);

  // ---------------------------------------------------------------------------
  // ORANGE SYSTEM (15-20% Accent Rule)
  // ---------------------------------------------------------------------------
  /// Core primary orange fill in Light mode.
  static const Color orangeFillLight = Color(0xFFFF6B00);

  /// Core primary orange fill in Dark mode.
  static const Color orangeFillDark = Color(0xFFFF8A3D);

  /// High-contrast orange for text or thin strokes on white (5:1 WCAG AA).
  static const Color orangeTextLight = Color(0xFFC24100);

  /// High-contrast orange for text or thin strokes on black (7.5:1 WCAG AA).
  static const Color orangeTextDark = Color(0xFFFF8A3D);

  /// Always black text/icons on orange fill (7:1 WCAG AAA).
  static const Color onOrange = Color(0xFF000000);

  /// Subtle top-gradient color for gloss orange button.
  static const Color orangeGlossTopLight = Color(0xFFFF7A1A);
  static const Color orangeGlossTopDark = Color(0xFFFF994D);

  // ---------------------------------------------------------------------------
  // SEMANTIC ACCENTS (Small system badges only)
  // ---------------------------------------------------------------------------
  static const Color successLight = Color(0xFF248A3D);
  static const Color successDark = Color(0xFF30D158);

  static const Color errorLight = Color(0xFFD70015);
  static const Color errorDark = Color(0xFFFF453A);

  static const Color warningLight = Color(0xFFB25000);
  static const Color warningDark = Color(0xFFFF9F0A);

  // ---------------------------------------------------------------------------
  // CONTEXT-AWARE RESOLVERS
  // ---------------------------------------------------------------------------
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Primary interactive fill (Orange).
  static Color primary(BuildContext context) =>
      isDark(context) ? orangeFillDark : orangeFillLight;

  /// Text/icon on primary fill (Always Black for 7:1 contrast).
  static Color onPrimary(BuildContext context) => onOrange;

  /// Text color when orange is used as text/stroke on surface/background.
  static Color accentText(BuildContext context) =>
      isDark(context) ? orangeTextDark : orangeTextLight;

  static Color background(BuildContext context) =>
      isDark(context) ? backgroundDark : backgroundLight;

  static Color surface(BuildContext context) =>
      isDark(context) ? surfaceDark : surfaceLight;

  /// Secondary surface level (surface2).
  static Color surfaceVariant(BuildContext context) =>
      isDark(context) ? surfaceVariantDark : surfaceVariantLight;

  static Color textPrimary(BuildContext context) =>
      isDark(context) ? textPrimaryDark : textPrimaryLight;

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? textSecondaryDark : textSecondaryLight;

  static Color success(BuildContext context) =>
      isDark(context) ? successDark : successLight;

  static Color warning(BuildContext context) =>
      isDark(context) ? warningDark : warningLight;

  static Color error(BuildContext context) =>
      isDark(context) ? errorDark : errorLight;

  static Color divider(BuildContext context) =>
      isDark(context) ? dividerDark : dividerLight;

  static Color scrim(BuildContext context) =>
      isDark(context) ? scrimDark : scrimLight;
}
