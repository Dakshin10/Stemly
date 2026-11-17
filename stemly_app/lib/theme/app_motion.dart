import 'package:flutter/material.dart';

/// Motion and physical spring tokens following Apple HIG.
class AppMotion {
  AppMotion._();

  /// Default Apple physical spring: mass 1, stiffness 300, damping 28.
  /// ~0.4s response, no visible bounce on navigation.
  static const SpringDescription defaultSpring = SpringDescription(
    mass: 1.0,
    stiffness: 300.0,
    damping: 28.0,
  );

  /// Playful Apple physical spring: damping 18 for tab lens indicator & score ring.
  static const SpringDescription playfulSpring = SpringDescription(
    mass: 1.0,
    stiffness: 300.0,
    damping: 18.0,
  );

  /// Standard duration for UI transitions, sheets, routes (400 ms)
  static const Duration transition = Duration(milliseconds: 400);

  /// Standard duration for button press / release (120 ms)
  static const Duration pressDuration = Duration(milliseconds: 120);

  /// Standard duration for internal interactive state changes, toggles (120 ms)
  static const Duration stateChange = Duration(milliseconds: 120);

  /// Fallback duration under reduced motion (120 ms fade)
  static const Duration reducedMotion = Duration(milliseconds: 120);

  /// Standard curve for natural responsive animations
  static const Curve curve = Curves.easeOutCubic;

  /// Check whether animations are disabled in system accessibility settings
  static bool isReducedMotion(BuildContext context) {
    return MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  /// Returns effective duration honoring reduce-motion preferences
  static Duration getEffectiveDuration(
    BuildContext context,
    Duration normalDuration,
  ) {
    return isReducedMotion(context) ? reducedMotion : normalDuration;
  }
}
