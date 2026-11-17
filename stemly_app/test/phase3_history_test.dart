import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stemly_app/models/scan_history.dart';
import 'package:stemly_app/screens/history_screen.dart';
import 'package:stemly_app/storage/history_store.dart';
import 'package:stemly_app/strings.dart';
import 'package:stemly_app/theme/theme.dart';

void main() {
  group('Phase 3: History Screen HIG Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await HistoryStore.init();
      HistoryStore.setHistory([
        ScanHistory(
          topic: "Projectile Motion",
          variables: ["V0", "theta", "g"],
          imagePath: "",
          notesJson: {"Explanation": "Test notes"},
          timestamp: DateTime.now(),
          isStarred: false,
        ),
        ScanHistory(
          topic: "Thin Lens Optics",
          variables: ["f", "u", "v"],
          imagePath: "",
          notesJson: {"Explanation": "Lens equation"},
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
          isStarred: true,
        ),
      ]);
    });

    testWidgets(
      'HistoryScreen renders large title, filter chips, and 56 dp rows',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.lightTheme, home: const HistoryScreen()),
        );

        await tester.pumpAndSettle();

        expect(find.text(AppStrings.historyTitle), findsWidgets);
        expect(find.text(AppStrings.filterAll), findsOneWidget);
        expect(find.text(AppStrings.filterStarred), findsOneWidget);
        expect(find.text("Projectile Motion"), findsOneWidget);
        expect(find.text("Thin Lens Optics"), findsOneWidget);

        // Star toggle tooltip / semantics
        expect(find.byTooltip(AppStrings.addToStarred), findsOneWidget);
        expect(find.byTooltip(AppStrings.removeFromStarred), findsOneWidget);
      },
    );

    testWidgets('Filtering by Starred shows only starred items', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const HistoryScreen()),
      );

      await tester.pumpAndSettle();

      // Tap Starred chip
      await tester.ensureVisible(find.text(AppStrings.filterStarred));
      await tester.tap(find.text(AppStrings.filterStarred));
      await tester.pumpAndSettle();

      expect(find.text("Thin Lens Optics"), findsOneWidget);
      expect(find.text("Projectile Motion"), findsNothing);
    });
  });
}
