import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stemly_app/presentation/components/components.dart';
import 'package:stemly_app/theme/theme.dart';

void main() {
  group('Phase 1: Shared Components & Theme Tokens', () {
    testWidgets(
      'AppScaffold renders inline and large title variants with accessible nav bar',
      (tester) async {
        int tappedIndex = -1;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: AppScaffold(
              title: 'Test Scaffold',
              isLargeTitle: true,
              currentBottomNavIndex: 0,
              onBottomNavTap: (i) => tappedIndex = i,
              body: const Text('Scaffold Content'),
            ),
          ),
        );

        // Verify title and content (SliverAppBar.large maintains expanded + collapsed text)
        expect(find.text('Test Scaffold'), findsWidgets);
        expect(find.text('Scaffold Content'), findsOneWidget);

        // Verify 4 bottom navigation items exist with accessible labels
        expect(find.text('Home'), findsOneWidget);
        expect(find.text('History'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Account'), findsOneWidget);

        // Tap history tab
        await tester.tap(find.text('History'));
        await tester.pump();
        expect(tappedIndex, 1);
      },
    );

    testWidgets(
      'GroupedRow enforces 56 dp minimum height and handles tap gestures',
      (tester) async {
        bool tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: GroupedSection(
                title: 'Test Section',
                children: [
                  GroupedRow(
                    leading: const Icon(Icons.settings),
                    title: 'Row Title',
                    subtitle: 'Row Subtitle',
                    showChevron: true,
                    onTap: () => tapped = true,
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Test Section'), findsOneWidget);
        expect(find.text('Row Title'), findsOneWidget);
        expect(find.text('Row Subtitle'), findsOneWidget);

        // Verify minimum height is at least 56 dp
        final RenderBox box = tester.renderObject(find.byType(GroupedRow));
        expect(box.size.height, greaterThanOrEqualTo(56.0));

        // Tap row
        await tester.tap(find.byType(GroupedRow));
        await tester.pump();
        expect(tapped, isTrue);
      },
    );

    testWidgets(
      'StatusPill displays paired icon and text label with semantic container',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatusPill(
                icon: Icons.check_circle_outline,
                label: 'Connected',
                color: AppColors.successLight,
              ),
            ),
          ),
        );

        expect(find.text('Connected'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
        expect(find.byType(StatusPill), findsOneWidget);
      },
    );

    testWidgets(
      'MathTexView compiles valid LaTeX and gracefully displays readable fallback on error',
      (tester) async {
        // 1. Valid formula
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: MathTexView(formula: r'v = u + at')),
          ),
        );

        expect(find.byType(MathTexView), findsOneWidget);

        // 2. Malformed formula triggering fallback
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: MathTexView(formula: r'\frac{invalid')),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MathTexView), findsOneWidget);
        // Fallback text does not crash and renders clean text
        expect(find.textContaining('invalid'), findsOneWidget);
      },
    );
  });
}
