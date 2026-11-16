import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:stemly_app/presentation/components/components.dart';
import 'package:stemly_app/screens/account_screen.dart';
import 'package:stemly_app/screens/login_screen.dart';
import 'package:stemly_app/screens/settings_screen.dart';
import 'package:stemly_app/screens/splash_screen.dart';
import 'package:stemly_app/services/firebase_auth_service.dart';
import 'package:stemly_app/strings.dart';
import 'package:stemly_app/theme/theme.dart';

class MockFirebaseAuthService extends ChangeNotifier implements FirebaseAuthService {
  @override
  User? currentUser;

  @override
  bool get isAuthenticated => currentUser != null;

  @override
  Future<void> initialize() async {}

  @override
  Future<UserCredential?> signInWithGoogle() async => null;

  @override
  Future<void> signOut() async {
    currentUser = null;
    notifyListeners();
  }

  @override
  Future<void> warmUpBackend() async {}

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => "mock-token";

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Phase 2 Screens & HIG Compliance Tests', () {
    testWidgets('SplashScreen displays STEMLY and single tagline "Scan, visualise, learn."',
        (WidgetTester tester) async {
      final mockAuth = MockFirebaseAuthService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FirebaseAuthService>.value(value: mockAuth),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            initialRoute: '/splash',
            routes: {
              '/splash': (c) => const SplashScreen(),
              '/login': (c) => const Scaffold(),
              '/': (c) => const Scaffold(),
            },
          ),
        ),
      );

      // Verify title and tagline
      expect(find.text(AppStrings.appName), findsOneWidget);
      expect(find.text(AppStrings.appTagline), findsOneWidget);
      // Verify no "STEM QUEST"
      expect(find.textContaining('QUEST'), findsNothing);

      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();
    });

    testWidgets('LoginScreen renders Large Title, Why Sign In card, and 52 dp buttons',
        (WidgetTester tester) async {
      final mockAuth = MockFirebaseAuthService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FirebaseAuthService>.value(value: mockAuth),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const LoginScreen(),
          ),
        ),
      );

      expect(find.text(AppStrings.loginTitle), findsOneWidget);
      expect(find.text(AppStrings.whySignInTitle), findsOneWidget);
      expect(find.text(AppStrings.continueWithGoogle), findsOneWidget);
      expect(find.text(AppStrings.continueWithApple), findsOneWidget);
      expect(find.text(AppStrings.continueAsGuest), findsOneWidget);

      // Check button size (PrimaryButton is 52 dp tall)
      final primaryButtonSize = tester.getSize(find.byType(PrimaryButton).first);
      expect(primaryButtonSize.height, 52.0);
    });

    testWidgets('SettingsScreen renders grouped rows with Appearance, Scanning, and AI status',
        (WidgetTester tester) async {
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SettingsScreen(),
          ),
        ),
      );

      expect(find.text(AppStrings.settingsTitle), findsWidgets);
      expect(find.text(AppStrings.sectionAppearance), findsOneWidget);
      expect(find.text(AppStrings.stemlyCloudAI), findsOneWidget);
      expect(find.text(AppStrings.connected), findsOneWidget);
      expect(find.text(AppStrings.clearLocalCache), findsOneWidget);
    });

    testWidgets('AccountScreen renders guest CTA when logged out',
        (WidgetTester tester) async {
      final mockAuth = MockFirebaseAuthService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FirebaseAuthService>.value(value: mockAuth),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const AccountScreen(),
          ),
        ),
      );

      expect(find.text(AppStrings.accountTitle), findsWidgets);
      expect(find.text(AppStrings.signInToSync), findsOneWidget);
      expect(find.text(AppStrings.continueWithGoogle), findsOneWidget);
    });
  });
}
