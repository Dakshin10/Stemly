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
    testWidgets('NotesSkeleton renders placeholder blocks with accessible semantics', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NotesSkeleton(),
          ),
        ),
      );

      // Advance one animation tick
      await tester.pump(const Duration(milliseconds: 100));

      // Verify semantics label
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == 'Generating notes, please wait...',
        ),
        findsOneWidget,
      );

      // Verify Card placeholders exist
      expect(find.byType(Card), findsAtLeastNWidgets(2));
      expect(find.byType(ShimmerBox), findsAtLeastNWidgets(5));
    });

    testWidgets('ScanResultScreen renders notes with degraded banner when degraded is true', (WidgetTester tester) async {
      final fakeAuth = FakeAuthService();

      final notesData = {
        "summary": "Projectile motion describes an object thrown in a gravitational field.",
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
    });

    testWidgets('ScanResultScreen renders ErrorStateView when notes payload contains error', (WidgetTester tester) async {
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
    });
  });
}
