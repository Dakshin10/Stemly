import 'package:flutter/foundation.dart';

enum Flavor { dev, prod }

/// Immutable Flavor Configuration for Stemly App
class AppFlavorConfig {
  final Flavor flavor;
  final String name;
  final String apiBaseUrl;
  final String? sentryDsn;
  final bool enableDebugBanner;

  const AppFlavorConfig({
    required this.flavor,
    required this.name,
    required this.apiBaseUrl,
    this.sentryDsn,
    this.enableDebugBanner = false,
  });

  bool get isProduction => flavor == Flavor.prod;
  bool get isDevelopment => flavor == Flavor.dev;
}

class AppFlavor {
  AppFlavor._();

  static const String _envSentryDsn = String.fromEnvironment('SENTRY_DSN');
  static const String _envProdApiUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://stemly-backend-hash-uc.a.run.app',
  );

  /// Development Flavor Configuration
  static const AppFlavorConfig dev = AppFlavorConfig(
    flavor: Flavor.dev,
    name: 'Development',
    apiBaseUrl: kIsWeb ? 'http://localhost:8080' : 'http://10.0.2.2:8080',
    sentryDsn: null,
    enableDebugBanner: false,
  );

  /// Production Flavor Configuration
  static final AppFlavorConfig prod = AppFlavorConfig(
    flavor: Flavor.prod,
    name: 'Production',
    apiBaseUrl: _envProdApiUrl,
    sentryDsn: _envSentryDsn.isNotEmpty ? _envSentryDsn : null,
    enableDebugBanner: false,
  );

  /// Active flavor configuration (defaults to dev for hot reload & test runner compatibility)
  static AppFlavorConfig current = dev;
}
