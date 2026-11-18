import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stemly_app/screens/scan_arc_painter.dart';
import 'package:stemly_app/screens/splash_screen.dart';
import 'package:stemly_app/services/firebase_auth_service.dart';
import 'package:stemly_app/strings.dart';
import 'package:stemly_app/theme/theme.dart';

class MockFirebaseAuthService extends ChangeNotifier
    implements FirebaseAuthService {
  @override
  User? currentUser;

  @override
  bool get isAuthenticated => currentUser != null;

  @override
  Future<void> initialize() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestNavigatorObserver extends NavigatorObserver {
  int replaceCount = 0;
  final List<String?> replacedRoutes = [];

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    replaceCount++;
    replacedRoutes.add(newRoute?.settings.name);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SplashScreen Redesign & HIG Compliance Tests', () {
    testWidgets('Renders brand title, tagline, glass tile and semantics label', (
      tester,
    ) async {
      final mockAuth = MockFirebaseAuthService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FirebaseAuthService>.value(value: mockAuth),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            initialRoute: '/splash',
            routes: {
              '/splash': (c) => const SplashScreen(),
              '/login': (c) => const Scaffold(body: Text('Welcome')),
              '/': (c) => const Scaffold(body: Text('Home')),
            },
          ),
        ),
      );

      // Verify wordmark & exact tagline
      expect(find.text(AppStrings.appName), findsOneWidget);
      expect(find.text(AppStrings.appTagline), findsOneWidget);

      // Verify document scanner glyph
      expect(find.byIcon(Icons.document_scanner_rounded), findsOneWidget);

      // Verify accessible semantics announcement
      expect(
        find.bySemanticsLabel('STEMLY, Scan, visualise, learn'),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();
    });

    testWidgets('Progress indicator is hidden for first 400 ms', (tester) async {
      final mockAuth = MockFirebaseAuthService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FirebaseAuthService>.value(value: mockAuth),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            initialRoute: '/splash',
            routes: {
              '/splash': (c) => const SplashScreen(),
              '/login': (c) => const Scaffold(),
              '/': (c) => const Scaffold(),
            },
          ),
        ),
      );

      // At 200 ms: indicator must be hidden (opacity == 0.0)
      await tester.pump(const Duration(milliseconds: 200));

      final animatedOpacityFinder = find.byWidgetPredicate(
        (w) => w is AnimatedOpacity && w.child is Semantics,
      );
      expect(animatedOpacityFinder, findsOneWidget);

      final animatedOpacity = tester.widget<AnimatedOpacity>(animatedOpacityFinder);
      expect(animatedOpacity.opacity, 0.0);

      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pumpAndSettle();
    });

    testWidgets('Reduce Motion renders static frame without scan line or arc', (
      tester,
    ) async {
      final mockAuth = MockFirebaseAuthService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FirebaseAuthService>.value(value: mockAuth),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            initialRoute: '/splash',
            routes: {
              '/splash': (c) => const MediaQuery(
                    data: MediaQueryData(disableAnimations: true),
                    child: SplashScreen(),
                  ),
              '/login': (c) => const Scaffold(),
              '/': (c) => const Scaffold(),
            },
          ),
        ),
      );

      await tester.pump();

      // ScanLinePainter and ProjectileArcPainter must not be rendered when animations are disabled
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is ScanLinePainter,
        ),
        findsNothing,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is ProjectileArcPainter,
        ),
        findsNothing,
      );

      // Wordmark and tagline are immediately visible at full opacity
      expect(find.text(AppStrings.appName), findsOneWidget);
      expect(find.text(AppStrings.appTagline), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
    });

    testWidgets('Navigates exactly once on completion (Single Navigation)', (
      tester,
    ) async {
      final mockAuth = MockFirebaseAuthService();
      final navObserver = TestNavigatorObserver();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FirebaseAuthService>.value(value: mockAuth),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            navigatorObservers: [navObserver],
            initialRoute: '/splash',
            routes: {
              '/splash': (c) => const SplashScreen(),
              '/login': (c) => const Scaffold(body: Text('Welcome Screen')),
              '/': (c) => const Scaffold(body: Text('Home Screen')),
            },
          ),
        ),
      );

      // Initial state: on splash
      expect(navObserver.replaceCount, 0);

      // Advance through entrance & init
      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pumpAndSettle();

      // Verified: Navigates exactly once to /login
      expect(navObserver.replaceCount, 1);
      expect(navObserver.replacedRoutes.last, '/login');

      // Further time progression causes no extra replacement
      await tester.pump(const Duration(seconds: 1));
      expect(navObserver.replaceCount, 1);
    });

    testWidgets('Renders safely under 200% accessibility text scale', (
      tester,
    ) async {
      final mockAuth = MockFirebaseAuthService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FirebaseAuthService>.value(value: mockAuth),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            initialRoute: '/splash',
            routes: {
              '/splash': (c) => const MediaQuery(
                    data: MediaQueryData(
                      size: Size(360, 640),
                      textScaler: TextScaler.linear(2.0),
                    ),
                    child: SplashScreen(),
                  ),
              '/login': (c) => const Scaffold(),
              '/': (c) => const Scaffold(),
            },
          ),
        ),
      );

      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text(AppStrings.appName), findsOneWidget);
      expect(find.text(AppStrings.appTagline), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pumpAndSettle();
    });
  });
}
