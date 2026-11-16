import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type scale following Apple HIG (system font, iOS proportions).
/// Uses weights: Regular (400), Medium (500), Semibold (600), Bold (700).
/// Monospace is reserved exclusively for numeric readouts.
class AppTypography {
  AppTypography._();

  // ---------------------------------------------------------------------------
  // BASE STYLES (Light & Dark dynamic builders)
  // ---------------------------------------------------------------------------

  /// 34 pt Bold (Screen hero headers)
  static TextStyle largeTitle(BuildContext context) {
    return TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary(context),
      letterSpacing: -0.4,
      height: 1.2,
    );
  }

  /// 22 pt Semibold (Section & Card titles)
  static TextStyle title2(BuildContext context) {
    return TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary(context),
      letterSpacing: -0.2,
      height: 1.25,
    );
  }

  /// 17 pt Semibold (Group headers, emphasized rows, buttons)
  static TextStyle headline(BuildContext context) {
    return TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary(context),
      letterSpacing: -0.1,
      height: 1.3,
    );
  }

  /// 17 pt Regular (Default content, explanations, answers)
  static TextStyle body(BuildContext context) {
    return TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary(context),
      letterSpacing: -0.1,
      height: 1.45,
    );
  }

  /// 16 pt Regular (Secondary content, prompt text)
  static TextStyle callout(BuildContext context) {
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary(context),
      letterSpacing: -0.05,
      height: 1.35,
    );
  }

  /// 15 pt Regular (Row subtitles, secondary list text)
  static TextStyle subhead(BuildContext context) {
    return TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary(context),
      height: 1.35,
    );
  }

  /// 13 pt Regular (Meta information, timestamps, legal text)
  static TextStyle footnote(BuildContext context) {
    return TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary(context),
      height: 1.3,
    );
  }

  /// 12 pt Regular (Badges, slider limits, chips)
  static TextStyle caption(BuildContext context) {
    return TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary(context),
      height: 1.25,
    );
  }

  /// Monospace variant for numeric parameters & telemetry readouts
  static TextStyle numeric(BuildContext context, {double fontSize = 14, FontWeight fontWeight = FontWeight.w600}) {
    return TextStyle(
      fontFamily: 'monospace',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: AppColors.textPrimary(context),
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}
