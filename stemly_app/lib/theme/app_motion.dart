import 'package:flutter/material.dart';

/// Motion tokens following Apple HIG.
/// Respects user accessibility preferences (`disableAnimations`).
class AppMotion {
  AppMotion._();

  /// Standard duration for UI transitions, sheets, routes (200 ms)
  static const Duration transition = Duration(milliseconds: 200);

  /// Standard duration for internal interactive state changes, toggles (120 ms)
  static const Duration stateChange = Duration(milliseconds: 120);

  /// Fallback duration under reduced motion (100 ms fade)
  static const Duration reducedMotion = Duration(milliseconds: 100);

  /// Standard curve for natural responsive animations
  static const Curve curve = Curves.easeOut;

  /// Check whether animations are disabled in system accessibility settings
  static bool isReducedMotion(BuildContext context) {
    return MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  /// Returns effective duration honoring reduce-motion preferences
  static Duration getEffectiveDuration(BuildContext context, Duration normalDuration) {
    return isReducedMotion(context) ? reducedMotion : normalDuration;
  }
}
