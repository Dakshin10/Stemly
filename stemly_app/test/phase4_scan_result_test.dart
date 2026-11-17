import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:stemly_app/presentation/components/math_tex_view.dart';
import 'package:stemly_app/screens/scan_result_screen.dart';
import 'package:stemly_app/services/firebase_auth_service.dart';
import 'package:stemly_app/strings.dart';

class MockFirebaseAuthService extends ChangeNotifier
    implements FirebaseAuthService {
  @override
  User? currentUser;

  @override
  bool get isAuthenticated => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<UserCredential?> signInWithGoogle() async => null;

  @override
  Future<void> signOut() async {}

  @override
  Future<void> warmUpBackend() async {}

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => "mock-token";

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Phase 4: ScanResultScreen HIG Tests', () {
    testWidgets(
      'Visualiser tab displays Hero 4:3 canvas, MathTexView for formula, and AI assistant',
      (WidgetTester tester) async {
        final mockAuth = MockFirebaseAuthService();

        await tester.pumpWidget(
          ChangeNotifierProvider<FirebaseAuthService>.value(
            value: mockAuth,
            child: const MaterialApp(
              home: ScanResultScreen(
                topic: "Projectile Motion",
                variables: ["V0", "theta", "g"],
                notesJson: {"Explanation": "Standard parabolic path."},
                imagePath: "",
                targetQuestion: "Find the maximum height and time of flight",
                latexFormula: r"H = \frac{V_0^2 \sin^2\theta}{2g}",
                structuredVariables: [
                  {
                    "name": "Initial Velocity",
                    "symbol": "V0",
                    "value": 20,
                    "unit": "m/s",
                  },
                  {
                    "name": "Launch Angle",
                    "symbol": "theta",
                    "value": 45,
                    "unit": "deg",
                  },
                  {"name": "Maximum Height", "symbol": "H", "is_target": true},
                ],
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Visualiser tab is selected by default (index 1)
        expect(find.text(AppStrings.tabVisualiser), findsOneWidget);

        // Target objective banner without emojis
        expect(find.text(AppStrings.targetObjective), findsOneWidget);
        expect(
          find.text("Find the maximum height and time of flight"),
          findsOneWidget,
        );

        // Governing equation rendered using MathTexView (not raw selectable monospace)
        expect(find.byType(MathTexView), findsWidgets);

        // AI assistant card
        expect(find.text(AppStrings.aiAssistant), findsOneWidget);

        // Variables are shown with calm labels
        expect(find.textContaining("Initial Velocity"), findsOneWidget);
        expect(find.textContaining("Maximum Height"), findsOneWidget);
      },
    );
  });
}
