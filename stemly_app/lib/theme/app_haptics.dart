import 'package:flutter/services.dart';

/// Haptic feedback helpers following Apple HIG.
/// Haptics are never the sole feedback for any interaction.
class AppHaptics {
  AppHaptics._();

  /// Subtle click for tabs, segmented controls, option tiles, and slider detents.
  static Future<void> selection() async {
    await HapticFeedback.selectionClick();
  }

  /// Light impact for primary button press.
  static Future<void> buttonPress() async {
    await HapticFeedback.lightImpact();
  }

  /// Medium impact on quiz completion or milestone (>80% score).
  static Future<void> success() async {
    await HapticFeedback.mediumImpact();
  }

  /// Warning or error alert feedback.
  static Future<void> warning() async {
    await HapticFeedback.heavyImpact();
  }
}
