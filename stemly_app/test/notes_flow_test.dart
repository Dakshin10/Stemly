import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stemly_app/presentation/widgets/degraded_banner.dart';
import 'package:stemly_app/presentation/widgets/shimmer_skeleton.dart';
import 'package:stemly_app/presentation/widgets/state_views.dart';
import 'package:stemly_app/screens/scan_result_screen.dart';
import 'package:stemly_app/services/firebase_auth_service.dart';

import 'mocks/fake_auth_service.dart';

void main() {
  group('Notes Flow & Skeleton Widgets', () {
    testWidgets(
      'NotesSkeleton renders placeholder blocks with accessible semantics',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: NotesSkeleton())),
        );

        // Advance one animation tick
        await tester.pump(const Duration(milliseconds: 100));

        // Verify semantics label
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Generating notes, please wait...',
          ),
          findsOneWidget,
        );

        // Verify Card placeholders exist
        expect(find.byType(Card), findsAtLeastNWidgets(2));
        expect(find.byType(ShimmerBox), findsAtLeastNWidgets(5));
      },
    );

    testWidgets(
      'ScanResultScreen renders notes with degraded banner when degraded is true',
      (WidgetTester tester) async {
        final fakeAuth = FakeAuthService();

        final notesData = {
          "summary":
              "Projectile motion describes an object thrown in a gravitational field.",
          "key_formula": "Range = (v^2 * sin(2*theta)) / g",
          "variables": ["v (velocity)", "theta (launch angle)", "g (gravity)"],
        };

        await tester.pumpWidget(
          ChangeNotifierProvider<FirebaseAuthService>.value(
            value: fakeAuth,
            child: MaterialApp(
              home: ScanResultScreen(
                topic: "Projectile Motion",
                variables: const ["v", "theta", "g"],
                notesJson: notesData,
                imagePath: "",
                isDegraded: true,
              ),
            ),
          ),
        );

        // Pump to render tabs
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Switch to Notes Tab (index 0)
        final notesTab = find.text("Notes");
        expect(notesTab, findsOneWidget);
        await tester.tap(notesTab);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify DegradedModeBanner is rendered
        expect(find.byType(DegradedModeBanner), findsOneWidget);
        expect(find.text("Fallback AI Mode"), findsOneWidget);

        // Verify notes cards are present
        expect(find.text("Summary"), findsOneWidget);
        expect(find.text("Key formula"), findsOneWidget);
        expect(find.text("Variables"), findsOneWidget);
      },
    );

    testWidgets(
      'ScanResultScreen renders ErrorStateView when notes payload contains error',
      (WidgetTester tester) async {
        final fakeAuth = FakeAuthService();

        await tester.pumpWidget(
          ChangeNotifierProvider<FirebaseAuthService>.value(
            value: fakeAuth,
            child: const MaterialApp(
              home: ScanResultScreen(
                topic: "Quantum Mechanics",
                variables: [],
                notesJson: {"error": "Server connection timed out"},
                imagePath: "",
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Switch to Notes Tab
        await tester.tap(find.text("Notes"));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify ErrorStateView
        expect(find.byType(ErrorStateView), findsOneWidget);
        expect(find.text("Notes Generation Failed"), findsOneWidget);
        expect(find.text("Server connection timed out"), findsOneWidget);
      },
    );

    testWidgets(
      'ScanResultScreen formats stepped examples with preamble, step badges, and final result',
      (WidgetTester tester) async {
        final fakeAuth = FakeAuthService();

        final exampleText =
            r"A soccer ball is kicked with V0 = 20.0 m/s at an angle \theta = 30.0^\circ above the horizontal. (1) Convert the angle to radians: \theta = 30^\circ \times \pi/180 = 0.524 rad. (2) Horizontal component: V0x = 20.0 \cdot cos0.524 = 17.3 m/s. (3) Vertical component: V0y = 20.0 \cdot sin0.524 = 10.0 m/s. (4) Maximum height: H = (20.0^2 \cdot sin^2 0.524)/(2 \cdot 9.81) = (400 \cdot 0.25)/(19.62) \approx 5.1 m. (5) Time of flight: T = (2 \cdot 20.0 \cdot sin0.524)/9.81 = (40 \cdot 0.5)/9.81 \approx 2.04 s. (6) Horizontal range: R = (20.0^2 \cdot sin(2 \cdot 0.524))/9.81 = (400 \cdot sin1.047)/9.81 \approx (400 \cdot 0.866)/9.81 \approx 35.3 m. Thus the ball rises to about 5.1 m, stays aloft for 2.04 s, and lands roughly 35 m away.";

        final notesData = {
          "example": exampleText,
          "formulas": [r"R = \frac{v_0^2 \sin(2\theta)}{g}"],
          "variable_breakdown": {
            "v_0": "Initial launch velocity in m/s",
            "theta": "Launch angle above horizontal",
          },
        };

        await tester.pumpWidget(
          ChangeNotifierProvider<FirebaseAuthService>.value(
            value: fakeAuth,
            child: MaterialApp(
              home: ScanResultScreen(
                topic: "Projectile Motion",
                variables: const ["v0", "theta"],
                notesJson: notesData,
                imagePath: "",
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Switch to Notes Tab
        await tester.tap(find.text("Notes"));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Expand "Example" accordion
        final exampleTile = find.text("Example");
        expect(exampleTile, findsOneWidget);
        await tester.ensureVisible(exampleTile);
        await tester.pumpAndSettle();
        await tester.tap(exampleTile);
        await tester.pumpAndSettle();

        // Verify Problem Scenario preamble is rendered
        expect(find.text("Problem Scenario"), findsOneWidget);

        // Verify step badges 1, 2, 3, 4, 5, 6 exist
        expect(find.text("1"), findsOneWidget);
        expect(find.text("2"), findsOneWidget);
        expect(find.text("3"), findsOneWidget);
        expect(find.text("4"), findsOneWidget);
        expect(find.text("5"), findsOneWidget);
        expect(find.text("6"), findsOneWidget);

        // Verify step titles are cleanly extracted
        expect(find.text("Convert the angle to radians"), findsOneWidget);
        expect(find.text("Horizontal component"), findsOneWidget);
        expect(find.text("Vertical component"), findsOneWidget);
        expect(find.text("Maximum height"), findsOneWidget);
        expect(find.text("Time of flight"), findsOneWidget);
        expect(find.text("Horizontal range"), findsOneWidget);

        // Verify Final Result conclusion banner is rendered
        expect(find.text("Final Result"), findsOneWidget);
      },
    );
  });
}
