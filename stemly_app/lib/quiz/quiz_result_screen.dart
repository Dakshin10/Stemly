import 'package:flutter/material.dart';

import '../presentation/components/components.dart';
import '../strings.dart';
import '../theme/theme.dart';
import 'quiz_play_screen.dart';

/// HIG-compliant Quiz Result Screen for STEMLY.
/// Displays a clean circular score ring, score rating StatusPill,
/// structured answer review without emoji, key takeaway callouts,
/// and primary/secondary actions.
class QuizResultScreen extends StatelessWidget {
  final Map<String, dynamic> quizData;
  final Map<int, int> answers;

  const QuizResultScreen({
    super.key,
    required this.quizData,
    required this.answers,
  });

  @override
  Widget build(BuildContext context) {
    final questions = quizData["questions"] as List<dynamic>?;
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final surface = AppColors.surface(context);
    final divider = AppColors.divider(context);

    if (questions == null || questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(title: const Text("Quiz Results")),
        body: Center(
          child: EmptyState(
            icon: Icons.quiz_outlined,
            title: "No results to display",
            message: "Quiz answer details are unavailable.",
            action: PrimaryButton(
              label: AppStrings.back,
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      );
    }

    int score = 0;
    for (int i = 0; i < questions.length; i++) {
      final q = questions[i] as Map<String, dynamic>?;
      if (q == null) continue;
      final correctIndex = q["correct_index"];
      if (answers[i] == correctIndex) {
        score++;
      }
    }

    final total = questions.length;
    final percentage = ((score / total) * 100).round();

    // Determine performance tier & status pill
    final StatusPill statusPill;
    if (percentage >= 80) {
      statusPill = StatusPill.success(label: AppStrings.mastery);
    } else if (percentage >= 50) {
      statusPill = StatusPill.warning(label: AppStrings.proficient);
    } else {
      statusPill = StatusPill.error(label: AppStrings.needsReview);
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text("Quiz Results", style: AppTypography.headline(context)),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surface,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenMargin,
                ),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.md),

                    // SCORE RING & SUMMARY CARD
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.lg,
                      ),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        border: Border.all(color: divider),
                      ),
                      child: Column(
                        children: [
                          // Circular score ring
                          SizedBox(
                            width: 100,
                            height: 100,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CircularProgressIndicator(
                                  value: percentage / 100.0,
                                  strokeWidth: 8,
                                  backgroundColor: divider,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.primary(context),
                                  ),
                                ),
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "$score / $total",
                                        style: AppTypography.headline(context)
                                            .copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: textPrimary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),

                          Text(
                            "$percentage% Score",
                            style: AppTypography.title2(context).copyWith(
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),

                          statusPill,
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // SECTION HEADER: ANSWER REVIEW
                    Text(
                      AppStrings.answerReview,
                      style: AppTypography.headline(context),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // REVIEW QUESTIONS LIST
                    ...List.generate(total, (i) {
                      final q = questions[i] as Map<String, dynamic>?;
                      if (q == null) return const SizedBox.shrink();

                      final questionText = q["question"]?.toString() ?? "";
                      final options = (q["options"] as List<dynamic>?) ?? [];
                      final correctIndex = (q["correct_index"] as int?) ?? 0;
                      final userIndex = answers[i];
                      final isCorrect = userIndex == correctIndex;
                      final explanation = q["explanation"]?.toString();
                      final takeaway = q["takeaway"]?.toString();

                      final userAnswerText =
                          userIndex != null && userIndex < options.length
                          ? options[userIndex]?.toString() ?? ""
                          : "Not answered";
                      final correctAnswerText = correctIndex < options.length
                          ? options[correctIndex]?.toString() ?? ""
                          : "";

                      return Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(AppRadii.card),
                          border: Border.all(color: divider),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status row
                            Row(
                              children: [
                                Icon(
                                  isCorrect
                                      ? Icons.check_circle_rounded
                                      : Icons.cancel_rounded,
                                  color: isCorrect
                                      ? AppColors.success(context)
                                      : AppColors.error(context),
                                  size: 20,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  isCorrect
                                      ? AppStrings.correct
                                      : AppStrings.incorrect,
                                  style: AppTypography.subhead(context)
                                      .copyWith(
                                        color: isCorrect
                                            ? AppColors.success(context)
                                            : AppColors.error(context),
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const Spacer(),
                                Text(
                                  "${AppStrings.question} ${i + 1}",
                                  style: AppTypography.footnote(context),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),

                            // Question prompt
                            Text(
                              "Q${i + 1}. $questionText",
                              style: AppTypography.headline(context),
                            ),
                            const SizedBox(height: AppSpacing.sm),

                            // Your answer
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${AppStrings.yourAnswer}: ",
                                  style: AppTypography.subhead(context)
                                      .copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: isCorrect
                                            ? AppColors.success(context)
                                            : AppColors.error(context),
                                      ),
                                ),
                                Expanded(
                                  child: Text(
                                    userAnswerText,
                                    style: AppTypography.subhead(
                                      context,
                                    ).copyWith(color: textPrimary),
                                  ),
                                ),
                              ],
                            ),

                            // Correct answer (if user was wrong)
                            if (!isCorrect) ...[
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${AppStrings.correctAnswer}: ",
                                    style: AppTypography.subhead(context)
                                        .copyWith(
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.success(context),
                                        ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      correctAnswerText,
                                      style: AppTypography.subhead(
                                        context,
                                      ).copyWith(color: textPrimary),
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            // Explanation
                            if (explanation != null &&
                                explanation.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                explanation,
                                style: AppTypography.footnote(
                                  context,
                                ).copyWith(color: textSecondary, height: 1.35),
                              ),
                            ],

                            // Key Takeaway callout
                            if (takeaway != null && takeaway.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: AppColors.primary(
                                    context,
                                  ).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.input,
                                  ),
                                  border: Border.all(
                                    color: AppColors.primary(
                                      context,
                                    ).withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.lightbulb_outline_rounded,
                                      size: 18,
                                      color: AppColors.primary(context),
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Expanded(
                                      child: Text(
                                        "${AppStrings.keyTakeaway}: $takeaway",
                                        style: AppTypography.footnote(context)
                                            .copyWith(
                                              color: textPrimary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),

            // BOTTOM ACTIONS (RETAKE & BACK TO NOTES)
            Container(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              decoration: BoxDecoration(
                color: surface,
                border: Border(top: BorderSide(color: divider)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: AppStrings.backToNotes,
                      icon: const Icon(Icons.arrow_back_rounded, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: PrimaryButton(
                      label: AppStrings.retakeQuiz,
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuizPlayScreen(quizData: quizData),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
