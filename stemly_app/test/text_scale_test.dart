import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stemly_app/presentation/components/components.dart';
import 'package:stemly_app/quiz/quiz_play_screen.dart';
import 'package:stemly_app/screens/scan_result_screen.dart';
import 'package:stemly_app/services/firebase_auth_service.dart';
import 'package:stemly_app/theme/theme.dart';

class MockFirebaseAuthService extends ChangeNotifier implements FirebaseAuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('App components and screens render safely with 200% accessibility text scale', (tester) async {
    final mockAuth = MockFirebaseAuthService();

    // 1. Test Shared Components under 2.0x scale
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<FirebaseAuthService>.value(value: mockAuth),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 900),
              textScaler: TextScaler.linear(2.0),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    StatusPill.success(label: 'Mastery Level'),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Scan a problem',
                      onPressed: () {},
                    ),
                    const SizedBox(height: 16),
                    SecondaryButton(
                      label: 'Choose from gallery',
                      onPressed: () {},
                    ),
                    const SizedBox(height: 16),
                    GroupedSection(
                      title: 'Settings Section',
                      children: [
                        GroupedRow(
                          leading: const Icon(Icons.palette_outlined),
                          title: 'Appearance',
                          subtitle: 'Custom color mode and theme',
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Mastery Level'), findsOneWidget);
    expect(find.text('Scan a problem'), findsOneWidget);
    expect(find.text('Settings Section'), findsOneWidget);

    // 2. Test ScanResultScreen under 2.0x text scale
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<FirebaseAuthService>.value(value: mockAuth),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 900),
              textScaler: TextScaler.linear(2.0),
            ),
            child: const ScanResultScreen(
              topic: 'Projectile Motion',
              variables: ['v0=20', 'theta=45'],
              notesJson: {
                'Explanation': 'This is an explanation of projectile motion.',
              },
              imagePath: 'test_path.jpg',
              targetQuestion: 'Find maximum height',
              latexFormula: r'H = \frac{v_0^2 \sin^2\theta}{2g}',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Projectile Motion'), findsOneWidget);
    expect(find.text('Find maximum height'), findsOneWidget);

    // 3. Test QuizPlayScreen under 2.0x text scale
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const MediaQuery(
          data: MediaQueryData(
            size: Size(400, 900),
            textScaler: TextScaler.linear(2.0),
          ),
          child: QuizPlayScreen(
            quizData: {
              'topic': 'Physics',
              'questions': [
                {
                  'question': 'What is the standard acceleration due to gravity on Earth?',
                  'options': ['9.8 m/s²', '8.9 m/s²', '10.5 m/s²', '9.0 m/s²'],
                  'correct_index': 0,
                  'explanation': 'Standard gravity g is approximately 9.8 m/s².',
                }
              ],
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Question 1'), findsOneWidget);
    expect(find.text('9.8 m/s²'), findsOneWidget);
  });
}
