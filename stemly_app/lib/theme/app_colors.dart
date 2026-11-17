import 'package:flutter/material.dart';

/// Design tokens for STEMLY colors following Apple HIG Neutral Foundation
/// with rare, deliberate Accent Orange whitelist.
///
/// UI is predominantly white, mild-white, grey, and black.
/// Orange is used ONLY in the strict whitelist of 7 places:
/// 1. Single primary button per screen
/// 2. Projectile, trail, and trajectory arc in Visualiser
/// 3. Visualiser slider thumb and active track
/// 4. Quiz score ring progress arc and progress bar fill
/// 5. 6 dp dot or 3 dp bar indicator for selected tab
/// 6. Key result numbers (Range, Max height, Flight time) in accentText
/// 7. Focus rings for keyboard and accessibility focus
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------------
  // LIGHT PALETTE (80-85% Neutrals)
  // ---------------------------------------------------------------------------
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF5F5F7); // mild-white (cards, grouped rows)
  static const Color surface2Light = Color(0xFFE8E8ED); // surface2 (chips, inputs, tracks)
  static const Color surfaceVariantLight = surface2Light; // backward compatibility
  static const Color dividerLight = Color(0xFFD2D2D7);
  static const Color textPrimaryLight = Color(0xFF000000);
  static const Color textBodyLight = Color(0xFF111111);
  static const Color textSecondaryLight = Color(0xFF6E6E73);
  static const Color textTertiaryLight = Color(0xFF8E8E93);
  static const Color scrimLight = Color(0x66000000);

  // ---------------------------------------------------------------------------
  // DARK PALETTE (80-85% Neutrals)
  // ---------------------------------------------------------------------------
  static const Color backgroundDark = Color(0xFF000000);
  static const Color surfaceDark = Color(0xFF1C1C1E);
  static const Color surface2Dark = Color(0xFF2C2C2E); // surface2
  static const Color surfaceVariantDark = surface2Dark; // backward compatibility
  static const Color dividerDark = Color(0xFF38383A);
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textBodyDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFAEAEB2);
  static const Color textTertiaryDark = Color(0xFF8E8E93);
  static const Color scrimDark = Color(0x99000000);

  // ---------------------------------------------------------------------------
  // ACCENT ORANGE (Strict Whitelist Only)
  // ---------------------------------------------------------------------------
  /// Core primary orange fill in Light mode.
  static const Color accentFillLight = Color(0xFFFF6B00);
  static const Color orangeFillLight = accentFillLight;

  /// Core primary orange fill in Dark mode.
  static const Color accentFillDark = Color(0xFFFF8A3D);
  static const Color orangeFillDark = accentFillDark;

  /// High-contrast orange for text or numerals on white/mild-white (5:1 WCAG AA).
  static const Color accentTextLight = Color(0xFFC24100);
  static const Color orangeTextLight = accentTextLight;

  /// High-contrast orange for text or numerals on black (7.5:1 WCAG AA).
  static const Color accentTextDark = Color(0xFFFF8A3D);
  static const Color orangeTextDark = accentTextDark;

  /// Always black text/icons on orange fill (7:1 WCAG AAA). Never white on orange.
  static const Color onOrange = Color(0xFF000000);

  /// Subtle top-gradient color for gloss orange button (+6% lightness at top).
  static const Color orangeGlossTopLight = Color(0xFFFF7A1A);
  static const Color orangeGlossTopDark = Color(0xFFFF994D);

  // ---------------------------------------------------------------------------
  // STATUS (Small icon + label only, always with text)
  // ---------------------------------------------------------------------------
  static const Color successLight = Color(0xFF1B7F3B);
  static const Color successDark = Color(0xFF6FD08C);

  static const Color errorLight = Color(0xFFB3261E);
  static const Color errorDark = Color(0xFFFF8A80);

  static const Color warningLight = Color(0xFFB25000);
  static const Color warningDark = Color(0xFFFF9F0A);

  // ---------------------------------------------------------------------------
  // CONTEXT-AWARE RESOLVERS
  // ---------------------------------------------------------------------------
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Primary interactive fill (Whitelisted Orange).
  static Color accentFill(BuildContext context) =>
      isDark(context) ? accentFillDark : accentFillLight;

  /// Backward-compatible alias for primary fill.
  static Color primary(BuildContext context) => accentFill(context);

  /// Text/icon on orange fill (Always Black for 7:1 contrast).
  static Color onPrimary(BuildContext context) => onOrange;
  static Color onAccent(BuildContext context) => onOrange;

  /// High-contrast orange numerals/labels on neutral backgrounds.
  static Color accentText(BuildContext context) =>
      isDark(context) ? accentTextDark : accentTextLight;

  static Color background(BuildContext context) =>
      isDark(context) ? backgroundDark : backgroundLight;

  /// Mild-white / dark surface for cards and grouped rows.
  static Color surface(BuildContext context) =>
      isDark(context) ? surfaceDark : surfaceLight;

  /// Secondary surface level for chips, inputs, tracks (surface2).
  static Color surface2(BuildContext context) =>
      isDark(context) ? surface2Dark : surface2Light;

  /// Backward-compatible alias for surface2.
  static Color surfaceVariant(BuildContext context) => surface2(context);

  static Color textPrimary(BuildContext context) =>
      isDark(context) ? textPrimaryDark : textPrimaryLight;

  static Color textBody(BuildContext context) =>
      isDark(context) ? textBodyDark : textBodyLight;

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? textSecondaryDark : textSecondaryLight;

  static Color textTertiary(BuildContext context) =>
      isDark(context) ? textTertiaryDark : textTertiaryLight;

  static Color success(BuildContext context) =>
      isDark(context) ? successDark : successLight;

  static Color error(BuildContext context) =>
      isDark(context) ? errorDark : errorLight;

  static Color warning(BuildContext context) =>
      isDark(context) ? warningDark : warningLight;

  static Color divider(BuildContext context) =>
      isDark(context) ? dividerDark : dividerLight;

  static Color scrim(BuildContext context) =>
      isDark(context) ? scrimDark : scrimLight;
}
