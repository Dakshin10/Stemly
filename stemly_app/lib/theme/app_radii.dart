import 'package:flutter/material.dart';

/// Corner radius tokens and Apple Superellipse shapes.
/// - Capsule (100 dp) for tab bar and floating action buttons
/// - 28 dp for sheets and glass composer
/// - 20 dp for toolbars
/// - 16 dp for content cards and buttons
class AppRadii {
  AppRadii._();

  static const double chip = 100.0;
  static const double capsule = 100.0;
  static const double sheet = 28.0;
  static const double composer = 28.0;
  static const double toolbar = 20.0;
  static const double modal = 28.0;
  static const double card = 16.0;
  static const double button = 16.0;
  static const double input = 12.0;

  // BorderRadius presets
  static const BorderRadius capsuleRadius = BorderRadius.all(Radius.circular(capsule));
  static const BorderRadius chipRadius = BorderRadius.all(Radius.circular(chip));
  static const BorderRadius sheetRadius = BorderRadius.vertical(top: Radius.circular(sheet));
  static const BorderRadius toolbarRadius = BorderRadius.all(Radius.circular(toolbar));
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(card));
  static const BorderRadius buttonRadius = BorderRadius.all(Radius.circular(button));
  static const BorderRadius inputRadius = BorderRadius.all(Radius.circular(input));
  static const BorderRadius modalRadius = BorderRadius.vertical(top: Radius.circular(modal));

  /// Generates a smooth Apple continuous superellipse border.
  static ShapeBorder superellipse(double radius) {
    return ContinuousRectangleBorder(
      borderRadius: BorderRadius.circular(radius * 2.2),
    );
  }
}
