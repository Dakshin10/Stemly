import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stemly_app/presentation/widgets/degraded_banner.dart';
import 'package:stemly_app/presentation/widgets/state_views.dart';

void main() {
  group('Scan Flow & Observability Widgets', () {
    testWidgets('DegradedModeBanner displays message and warning icon', (WidgetTester tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DegradedModeBanner(
              message: 'Custom fallback notice: High server traffic.',
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      // Verify header and message
      expect(find.text('Fallback AI Mode'), findsOneWidget);
      expect(find.text('Custom fallback notice: High server traffic.'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

      // Verify dismiss button
      final closeBtn = find.byIcon(Icons.close);
      expect(closeBtn, findsOneWidget);
      await tester.tap(closeBtn);
      await tester.pump();

      expect(dismissed, isTrue);
    });

    testWidgets('DegradedModeBanner has accessible semantics', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DegradedModeBanner(),
          ),
        ),
      );

      final semanticsFinder = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == 'Degraded AI Mode Warning',
      );
      expect(semanticsFinder, findsOneWidget);
    });

    testWidgets('EmptyStateView renders title, message, and executes action button', (WidgetTester tester) async {
      bool actionTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateView(
              icon: Icons.history_rounded,
              title: 'No Scans Found',
              message: 'Your history is empty.',
              buttonText: 'Scan Worksheet',
              onAction: () => actionTriggered = true,
            ),
          ),
        ),
      );

      expect(find.text('No Scans Found'), findsOneWidget);
      expect(find.text('Your history is empty.'), findsOneWidget);
      expect(find.byIcon(Icons.history_rounded), findsOneWidget);

      final actionBtn = find.text('Scan Worksheet');
      expect(actionBtn, findsOneWidget);
      await tester.tap(actionBtn);
      await tester.pump();

      expect(actionTriggered, isTrue);
    });

    testWidgets('ErrorStateView renders message and retry button', (WidgetTester tester) async {
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorStateView(
              title: 'Upload Failed',
              message: 'Network connection lost.',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Upload Failed'), findsOneWidget);
      expect(find.text('Network connection lost.'), findsOneWidget);

      final retryBtn = find.text('Try Again');
      expect(retryBtn, findsOneWidget);
      await tester.tap(retryBtn);
      await tester.pump();

      expect(retried, isTrue);
    });
  });
}
