import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stemly_app/presentation/widgets/shimmer_skeleton.dart';
import 'package:stemly_app/quiz/quiz_play_screen.dart';
import 'package:stemly_app/quiz/quiz_result_screen.dart';

void main() {
  final sampleQuizData = {
    "topic": "Kinematics",
    "questions": [
      {
        "question": "What is the acceleration due to gravity on Earth?",
        "options": ["9.8 m/s²", "5.0 m/s²", "12.2 m/s²", "0 m/s²"],
        "correct_index": 0,
        "explanation":
            "Standard terrestrial gravity is approximately 9.8 m/s².",
      },
      {
        "question": "Which quantity is a vector?",
        "options": ["Speed", "Distance", "Velocity", "Mass"],
        "correct_index": 2,
        "explanation": "Velocity has both magnitude and direction.",
      },
    ],
  };

  group('Quiz Flow & Skeleton Widgets', () {
    testWidgets('QuizSkeleton renders placeholder question and options', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: QuizSkeleton())),
      );

      // Advance pulse animation frame
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label ==
                  'Generating quiz questions, please wait...',
        ),
        findsOneWidget,
      );

      // 1 question card + 4 option cards
      expect(find.byType(Card), findsNWidgets(5));
    });

    testWidgets(
      'QuizPlayScreen displays question, selects option, and completes quiz',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(home: QuizPlayScreen(quizData: sampleQuizData)),
        );

        await tester.pumpAndSettle();

        // Check Question 1 header and prompt
        expect(find.text("Question 1"), findsOneWidget);
        expect(find.text("1/2"), findsOneWidget);
        expect(
          find.text("What is the acceleration due to gravity on Earth?"),
          findsOneWidget,
        );
        expect(find.text("9.8 m/s²"), findsOneWidget);

        // Select first option
        await tester.tap(find.text("9.8 m/s²"));
        await tester.pumpAndSettle();

        // Advance to next question
        final nextBtn = find.text("Next");
        expect(nextBtn, findsOneWidget);
        await tester.tap(nextBtn);
        await tester.pumpAndSettle();

        // Check Question 2
        expect(find.text("Question 2"), findsOneWidget);
        expect(find.text("2/2"), findsOneWidget);
        expect(find.text("Which quantity is a vector?"), findsOneWidget);

        // Select Velocity option
        await tester.tap(find.text("Velocity"));
        await tester.pumpAndSettle();

        // Submit Quiz via Finish Quiz button
        final finishBtn = find.text("Finish Quiz");
        expect(finishBtn, findsOneWidget);
        await tester.tap(finishBtn);
        await tester.pumpAndSettle();

        // Should transition to QuizResultScreen with 100% score (2/2)
        expect(find.text("2 / 2"), findsOneWidget);
        expect(find.text("100% Score"), findsOneWidget);
      },
    );

    testWidgets('QuizResultScreen displays score breakdown and explanations', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QuizResultScreen(
            quizData: sampleQuizData,
            answers: const {
              0: 0,
              1: 0,
            }, // Question 1 correct (0), Question 2 incorrect (0 instead of 2)
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1 out of 2 correct = 50%
      expect(find.text("1 / 2"), findsOneWidget);
      expect(find.text("50% Score"), findsOneWidget);

      // Verify questions are shown in review list with Q1 and Q2 prefixes
      expect(
        find.text("Q1. What is the acceleration due to gravity on Earth?"),
        findsOneWidget,
      );
      expect(find.text("Q2. Which quantity is a vector?"), findsOneWidget);
    });
  });
}
