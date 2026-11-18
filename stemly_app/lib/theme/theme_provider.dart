import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themePrefKey = 'stemly_theme_mode';

  // -------------------------------
  // THEME MODE (Default: Dark Mode)
  // -------------------------------
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_themePrefKey);
      if (savedMode != null) {
        if (savedMode == 'light') {
          _themeMode = ThemeMode.light;
        } else if (savedMode == 'system') {
          _themeMode = ThemeMode.system;
        } else {
          _themeMode = ThemeMode.dark;
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      String val = 'dark';
      if (mode == ThemeMode.light) val = 'light';
      if (mode == ThemeMode.system) val = 'system';
      await prefs.setString(_themePrefKey, val);
    } catch (_) {}
  }

  Future<void> toggleTheme(bool enableDarkMode) async {
    await setThemeMode(enableDarkMode ? ThemeMode.dark : ThemeMode.light);
  }

  // -------------------------------
  // NOTIFICATIONS TOGGLE
  // -------------------------------
  bool _notifications = true;
  bool get notifications => _notifications;

  void toggleNotifications(bool value) {
    _notifications = value;
    notifyListeners();
  }

  // -------------------------------
  // WI-FI ONLY MODE
  // -------------------------------
  bool _wifiOnly = false;
  bool get wifiOnly => _wifiOnly;

  void toggleWifiOnly(bool value) {
    _wifiOnly = value;
    notifyListeners();
  }
}
