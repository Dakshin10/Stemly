import 'package:flutter/material.dart';

/// Corner radius tokens: chips 999, cards 16, inputs and buttons 12.
class AppRadii {
  AppRadii._();

  static const double chip = 999.0;
  static const double card = 16.0;
  static const double button = 12.0;
  static const double input = 12.0;
  static const double modal = 20.0;

  // BorderRadius presets
  static const BorderRadius chipRadius = BorderRadius.all(Radius.circular(chip));
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(card));
  static const BorderRadius buttonRadius = BorderRadius.all(Radius.circular(button));
  static const BorderRadius inputRadius = BorderRadius.all(Radius.circular(input));
  static const BorderRadius modalRadius =
      BorderRadius.vertical(top: Radius.circular(modal));
}
