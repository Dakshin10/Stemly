import 'package:flutter/foundation.dart';
import 'app_flavor.dart';

/// Centralized Application Configuration
class AppConfig {
  AppConfig._();

  /// Toggle production vs development
  static const bool isProduction = bool.fromEnvironment(
    'dart.vm.product',
    defaultValue: false,
  );

  /// Production backend endpoint
  static const String prodApiUrl = "https://stemly-backend.vercel.app";

  /// Local development backend endpoint (10.0.2.2 for Android emulator, localhost for web/desktop)
  static String get devApiUrl {
    if (kIsWeb) return "http://localhost:8080";
    if (defaultTargetPlatform == TargetPlatform.android)
      return "http://10.0.2.2:8080";
    return "http://localhost:8080";
  }

  /// Active backend base URL resolved from active flavor
  static String get baseUrl => AppFlavor.current.apiBaseUrl;

  /// Default HTTP timeout
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration requestTimeout = Duration(seconds: 35);
  static const Duration uploadTimeout = Duration(seconds: 60);

  /// Offline storage schema version
  static const int storageSchemaVersion = 2;
}
