import 'package:flutter/material.dart';

/// Design tokens for STEMLY colors following Apple HIG and WCAG AA/AAA contrast guidelines.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------------
  // LIGHT PALETTE
  // ---------------------------------------------------------------------------
  static const Color primaryLight = Color(0xFF36618E);
  static const Color onPrimaryLight = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFF6F8FC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFE8EEF6);
  static const Color textPrimaryLight = Color(0xFF14202E);
  static const Color textSecondaryLight = Color(0xFF4A5A6C);
  static const Color successLight = Color(0xFF1B7F3B);
  static const Color warningLight = Color(0xFF8A5A00);
  static const Color errorLight = Color(0xFFB3261E);
  static const Color dividerLight = Color(0xFFD1DCE8);
  static const Color scrimLight = Color(0x66000000);

  // ---------------------------------------------------------------------------
  // DARK PALETTE
  // ---------------------------------------------------------------------------
  static const Color primaryDark = Color(0xFF9CC2F0);
  static const Color onPrimaryDark = Color(0xFF0B1C2E);
  static const Color backgroundDark = Color(0xFF0E141B);
  static const Color surfaceDark = Color(0xFF172029);
  static const Color surfaceVariantDark = Color(0xFF223041);
  static const Color textPrimaryDark = Color(0xFFEAF0F7);
  static const Color textSecondaryDark = Color(0xFFA9B7C7);
  static const Color successDark = Color(0xFF6FD08C);
  static const Color warningDark = Color(0xFFF2C055);
  static const Color errorDark = Color(0xFFFF8A80);
  static const Color dividerDark = Color(0xFF2A3848);
  static const Color scrimDark = Color(0x99000000);

  // ---------------------------------------------------------------------------
  // CONTEXT ACCESSORS (Theme Aware)
  // ---------------------------------------------------------------------------
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color primary(BuildContext context) =>
      isDark(context) ? primaryDark : primaryLight;

  static Color onPrimary(BuildContext context) =>
      isDark(context) ? onPrimaryDark : onPrimaryLight;

  static Color background(BuildContext context) =>
      isDark(context) ? backgroundDark : backgroundLight;

  static Color surface(BuildContext context) =>
      isDark(context) ? surfaceDark : surfaceLight;

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
}
