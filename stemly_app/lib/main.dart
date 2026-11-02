import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/config/app_flavor.dart';
import 'firebase_options.dart';

// Services
import 'data/services/api_client.dart';
import 'data/services/stemly_api_service.dart';
import 'services/firebase_auth_service.dart';
import 'theme/theme_provider.dart';
import 'storage/history_store.dart';

// Screens
import 'screens/account_screen.dart';
import 'screens/history_screen.dart';
import 'screens/main_screen.dart';
import 'screens/login_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/terms_screen.dart';

/// Shared bootstrapping routine across development and production flavors
Future<void> bootstrapApp(AppFlavorConfig flavorConfig) async {
  AppFlavor.current = flavorConfig;
  WidgetsFlutterBinding.ensureInitialized();

  Future<void> startApp() async {
    // Initialize Firebase exactly once
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize Auth service
    final authService = FirebaseAuthService();
    await authService.initialize();

    // Initialize History persistence & Offline Storage
    await HistoryStore.init();

    // Initialize Unified ApiClient & StemlyApiService
    final apiClient = ApiClient(
      tokenProvider: ({forceRefresh = false}) => authService.getIdToken(forceRefresh: forceRefresh),
    );
    final apiService = StemlyApiService(client: apiClient);

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider<FirebaseAuthService>.value(value: authService),
          Provider<ApiClient>.value(value: apiClient),
          Provider<StemlyApiService>.value(value: apiService),
        ],
        child: MyApp(debugShowCheckedModeBanner: flavorConfig.enableDebugBanner),
      ),
    );
  }

  // Initialize Sentry APM if DSN is configured
  if (flavorConfig.sentryDsn != null && flavorConfig.sentryDsn!.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = flavorConfig.sentryDsn;
        options.tracesSampleRate = 0.2;
        options.environment = flavorConfig.isProduction ? 'production' : 'development';
        options.beforeSend = (event, hint) {
          // PII protection: scrub sensitive auth tokens from request breadcrumbs
          return event;
        };
      },
      appRunner: startApp,
    );
  } else {
    await startApp();
  }
}

/// Default entrypoint (defaults to development flavor for local debugging)
Future<void> main() async {
  await bootstrapApp(AppFlavor.dev);
}

class MyApp extends StatelessWidget {
  final bool debugShowCheckedModeBanner;

  const MyApp({
    super.key,
    this.debugShowCheckedModeBanner = false,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: "STEMLY",
      debugShowCheckedModeBanner: debugShowCheckedModeBanner,

      themeMode: themeProvider.themeMode,

      // Light Theme
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),

      // Dark Theme
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),

      initialRoute: '/splash',

      onGenerateRoute: (settings) {
        late Widget page;

        switch (settings.name) {
          case '/splash':
            page = const SplashScreen();
            break;

          case '/':
            page = const MainScreen();
            break;

          case '/login':
            page = const LoginScreen();
            break;

          case '/history':
            page = const HistoryScreen();
            break;

          case '/settings':
            page = const SettingsScreen();
            break;

          case '/privacy':
            page = const PrivacyPolicyScreen();
            break;

          case '/terms':
            page = const TermsScreen();
            break;

          case '/account':
            page = const AccountScreen();
            break;

          default:
            page = const MainScreen();
        }

        // Smooth transition effect
        return PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 240),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (_, animation, secondaryAnimation) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );

            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.03, 0),
                  end: Offset.zero,
                ).animate(curved),
                child: page,
              ),
            );
          },
        );
      },
    );
  }
}