import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radii.dart';

/// Full ThemeData definitions for Light and Dark modes conforming to Apple HIG & Material 3.
/// Neutrals are 80-85% of visible surfaces; Orange is the interactive accent (15-20% rule).
class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // LIGHT THEME (White / Surface #F5F5F7 / Orange Accent)
  // ---------------------------------------------------------------------------
  static ThemeData get lightTheme {
    final colorScheme = const ColorScheme.light(
      primary: AppColors.orangeFillLight,
      onPrimary: AppColors.onOrange,
      surface: AppColors.surfaceLight,
      onSurface: AppColors.textPrimaryLight,
      surfaceContainerHighest: AppColors.surfaceVariantLight,
      onSurfaceVariant: AppColors.textSecondaryLight,
      error: AppColors.errorLight,
      onError: Colors.white,
      outline: AppColors.dividerLight,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      dividerColor: AppColors.dividerLight,
      canvasColor: AppColors.surfaceLight,

      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimaryLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textPrimaryLight, size: 22),
      ),

      // Card Theme (No elevation, 1dp border in divider color)
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.cardRadius,
          side: const BorderSide(color: AppColors.dividerLight, width: 1.0),
        ),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.modal),
          side: const BorderSide(color: AppColors.dividerLight, width: 1.0),
        ),
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.sheetRadius),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariantLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadii.inputRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.inputRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.inputRadius,
          borderSide: const BorderSide(
            color: AppColors.orangeFillLight,
            width: 1.5,
          ),
        ),
        hintStyle: const TextStyle(color: AppColors.textSecondaryLight),
      ),

      // Slider Theme (Orange active track & thumb)
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.orangeFillLight,
        inactiveTrackColor: AppColors.surfaceVariantLight,
        thumbColor: AppColors.orangeFillLight,
        overlayColor: Color(0x26FF6B00), // 15% orange overlay
        trackHeight: 4,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10),
      ),

      // Switch Theme (On: black track with white thumb in Light; Off: surface2)
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return AppColors.textSecondaryLight;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.textPrimaryLight;
          }
          return AppColors.surface2Light;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerLight,
        thickness: 1,
        space: 1,
      ),

      // Tab Bar Theme (Rounded capsule splash & elastic indicator)
      tabBarTheme: TabBarThemeData(
        splashFactory: InkSparkle.splashFactory,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return AppColors.orangeFillLight.withValues(alpha: 0.14);
          }
          return Colors.transparent;
        }),
        indicatorSize: TabBarIndicatorSize.tab,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DARK THEME (Black #000000 / Surface #1C1C1E / Orange #FF8A3D)
  // ---------------------------------------------------------------------------
  static ThemeData get darkTheme {
    final colorScheme = const ColorScheme.dark(
      primary: AppColors.orangeFillDark,
      onPrimary: AppColors.onOrange,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.textPrimaryDark,
      surfaceContainerHighest: AppColors.surfaceVariantDark,
      onSurfaceVariant: AppColors.textSecondaryDark,
      error: AppColors.errorDark,
      onError: Colors.black,
      outline: AppColors.dividerDark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      dividerColor: AppColors.dividerDark,
      canvasColor: AppColors.surfaceDark,

      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textPrimaryDark, size: 22),
      ),

      // Card Theme (No elevation, 1dp border in divider color)
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.cardRadius,
          side: const BorderSide(color: AppColors.dividerDark, width: 1.0),
        ),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.modal),
          side: const BorderSide(color: AppColors.dividerDark, width: 1.0),
        ),
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.sheetRadius),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariantDark,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadii.inputRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.inputRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.inputRadius,
          borderSide: const BorderSide(
            color: AppColors.orangeFillDark,
            width: 1.5,
          ),
        ),
        hintStyle: const TextStyle(color: AppColors.textSecondaryDark),
      ),

      // Slider Theme (Orange active track & thumb)
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.orangeFillDark,
        inactiveTrackColor: AppColors.surfaceVariantDark,
        thumbColor: AppColors.orangeFillDark,
        overlayColor: Color(0x33FF8A3D),
        trackHeight: 4,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10),
      ),

      // Switch Theme (On: white track with black thumb in Dark; Off: surface2)
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.black;
          }
          return AppColors.textSecondaryDark;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.textPrimaryDark;
          }
          return AppColors.surface2Dark;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerDark,
        thickness: 1,
        space: 1,
      ),

      // Tab Bar Theme (Rounded capsule splash & elastic indicator)
      tabBarTheme: TabBarThemeData(
        splashFactory: InkSparkle.splashFactory,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return AppColors.orangeFillDark.withValues(alpha: 0.14);
          }
          return Colors.transparent;
        }),
        indicatorSize: TabBarIndicatorSize.tab,
      ),
    );
  }
}
