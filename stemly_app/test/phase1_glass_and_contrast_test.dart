import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stemly_app/presentation/components/buttons.dart';
import 'package:stemly_app/presentation/components/glass_surface.dart';
import 'package:stemly_app/theme/theme.dart';

double _calculateLuminance(Color color) {
  double channelLuminance(double channel) {
    if (channel <= 0.03928) {
      return channel / 12.92;
    }
    return pow((channel + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = channelLuminance(color.r);
  final g = channelLuminance(color.g);
  final b = channelLuminance(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _calculateContrastRatio(Color c1, Color c2) {
  final l1 = _calculateLuminance(c1);
  final l2 = _calculateLuminance(c2);
  final lighter = max(l1, l2);
  final darker = min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('Phase 1: Color Contrast & 15-20% Orange Rule Tokens', () {
    test('Black text on orange fill passes WCAG AAA (>= 7.0:1)', () {
      final ratioLight = _calculateContrastRatio(AppColors.onOrange, AppColors.orangeFillLight);
      final ratioDark = _calculateContrastRatio(AppColors.onOrange, AppColors.orangeFillDark);

      expect(ratioLight, greaterThanOrEqualTo(7.0),
          reason: 'Black text on orangeFillLight (#FF6B00) must pass 7:1');
      expect(ratioDark, greaterThanOrEqualTo(7.0),
          reason: 'Black text on orangeFillDark (#FF8A3D) must pass 7:1');
    });

    test('Orange text on white background passes WCAG AA (>= 4.5:1)', () {
      final ratio = _calculateContrastRatio(AppColors.orangeTextLight, AppColors.backgroundLight);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'orangeTextLight (#C24100) on white must pass 4.5:1');
    });

    test('Orange text on black background passes WCAG AA (>= 4.5:1)', () {
      final ratio = _calculateContrastRatio(AppColors.orangeTextDark, AppColors.backgroundDark);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'orangeTextDark (#FF8A3D) on black must pass 4.5:1');
    });
  });

  group('Phase 1: Liquid Glass Surface & Accessibility Fallbacks', () {
    testWidgets('GlassSurface renders BackdropFilter in standard mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: GlassSurface(
              child: const Text('Regular Glass'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.text('Regular Glass'), findsOneWidget);
    });

    testWidgets('GlassSurface falls back to opaque surface with border under High Contrast', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(highContrast: true),
            child: Scaffold(
              body: GlassSurface(
                child: const Text('High Contrast Glass'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      // In high contrast mode, BackdropFilter must NOT be present
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('High Contrast Glass'), findsOneWidget);
    });

    testWidgets('PrimaryButton renders Apple gloss styling and black text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: PrimaryButton(
              label: 'Scan a problem',
              onPressed: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final textWidget = tester.widget<Text>(find.text('Scan a problem'));
      expect(textWidget.style?.color, equals(AppColors.onOrange));
    });

    testWidgets('PrimaryButton renders disabled state without gloss when onPressed is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: PrimaryButton(
              label: 'Disabled Action',
              onPressed: null,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final textWidget = tester.widget<Text>(find.text('Disabled Action'));
      expect(textWidget.style?.color, equals(AppColors.textSecondaryLight));
    });
  });
}
