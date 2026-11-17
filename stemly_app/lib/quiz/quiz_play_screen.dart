import 'package:flutter/material.dart';

import '../presentation/components/components.dart';
import '../strings.dart';
import '../theme/theme.dart';
import 'quiz_result_screen.dart';

/// HIG-compliant Quiz Play Screen for STEMLY.
/// Minimal chrome, clear question presentation, 56+ dp option tiles with letter badges & radio indicators,
/// safe exit confirmation, and disabled next button until an option is selected.
class QuizPlayScreen extends StatefulWidget {
  final Map<String, dynamic> quizData;

  const QuizPlayScreen({super.key, required this.quizData});

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  int _currentIndex = 0;
  final Map<int, int> _answers = {};

  Future<void> _handleExit() async {
    final leave = await AppDialogs.confirm(
      context: context,
      title: AppStrings.exitQuizTitle,
      message: AppStrings.exitQuizMessage,
      confirmLabel: AppStrings.leave,
      cancelLabel: AppStrings.keepGoing,
      isDestructive: true,
    );

    if (leave == true && mounted) {
      Navigator.pop(context);
    }
  }

  void _handleNext(int total) {
    if (_currentIndex < total - 1) {
      setState(() => _currentIndex++);
    } else {
      // Completed quiz
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              QuizResultScreen(quizData: widget.quizData, answers: _answers),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.quizData["questions"] as List<dynamic>?;
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final surface = AppColors.surface(context);
    final divider = AppColors.divider(context);

    if (questions == null || questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(
          title: Text(AppStrings.error, style: AppTypography.headline(context)),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenMargin),
            child: EmptyState(
              icon: Icons.error_outline_rounded,
              title: "No quiz questions",
              message:
                  widget.quizData["error"]?.toString() ??
                  "Quiz questions could not be prepared for this topic.",
              action: PrimaryButton(
                label: AppStrings.back,
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
      );
    }

    final total = questions.length;
    final q = questions[_currentIndex] as Map<String, dynamic>;
    final options = (q["options"] as List<dynamic>?) ?? [];
    final questionText = q["question"]?.toString() ?? "";
    final hasSelected = _answers.containsKey(_currentIndex);
    final isLast = _currentIndex == total - 1;
    final progress = (_currentIndex + 1) / total;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleExit();
      },
      child: Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(
          backgroundColor: surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close_rounded, color: textPrimary, size: 24),
            onPressed: _handleExit,
            tooltip: AppStrings.close,
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Question ${_currentIndex + 1}",
                style: AppTypography.headline(context),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant(context),
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                ),
                child: Text(
                  "${_currentIndex + 1}/$total",
                  style: AppTypography.caption(
                    context,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: divider,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.primary(context),
              ),
              minHeight: 3,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.screenMargin),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.sm),

                      // QUESTION CARD
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(AppRadii.card),
                          border: Border.all(color: divider),
                        ),
                        child: Text(
                          questionText,
                          style: AppTypography.title2(context).copyWith(
                            color: textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      // OPTIONS LIST (>= 56 dp height each)
                      ...List.generate(options.length, (optIndex) {
                        final optionText = options[optIndex]?.toString() ?? "";
                        final isSelected = _answers[_currentIndex] == optIndex;
                        final letter = String.fromCharCode(
                          65 + optIndex,
                        ); // A, B, C, D

                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Semantics(
                            selected: isSelected,
                            button: true,
                            label: "$letter: $optionText",
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _answers[_currentIndex] = optIndex;
                                });
                              },
                              borderRadius: BorderRadius.circular(
                                AppRadii.card,
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                constraints: const BoxConstraints(
                                  minHeight: AppSpacing.groupedRowMinHeight,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm + 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.surfaceVariant(context)
                                      : surface,
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.card,
                                  ),
                                  border: Border.all(
                                    color: isSelected ? textPrimary : divider,
                                    width: isSelected ? 2.0 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Letter badge (solid textPrimary when selected, surfaceVariant when unselected)
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? textPrimary
                                            : AppColors.surfaceVariant(context),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        letter,
                                        style: AppTypography.headline(context)
                                            .copyWith(
                                              color: isSelected
                                                  ? (AppColors.isDark(context)
                                                        ? Colors.black
                                                        : Colors.white)
                                                  : textPrimary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),

                                    // Option Text
                                    Expanded(
                                      child: Text(
                                        optionText,
                                        style: AppTypography.body(context)
                                            .copyWith(
                                              color: textPrimary,
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                            ),
                                      ),
                                    ),

                                    const SizedBox(width: AppSpacing.sm),

                                    // Radio Indicator (solid textPrimary when selected, NOT orange)
                                    Icon(
                                      isSelected
                                          ? Icons.radio_button_checked_rounded
                                          : Icons.radio_button_off_rounded,
                                      color: isSelected
                                          ? textPrimary
                                          : textSecondary,
                                      size: 22,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // BOTTOM ACTION BAR
              Container(
                padding: const EdgeInsets.all(AppSpacing.screenMargin),
                decoration: BoxDecoration(
                  color: surface,
                  border: Border(top: BorderSide(color: divider)),
                ),
                child: Row(
                  children: [
                    if (_currentIndex > 0) ...[
                      Expanded(
                        child: SecondaryButton(
                          label: AppStrings.back,
                          icon: const Icon(Icons.arrow_back_rounded, size: 20),
                          onPressed: () => setState(() => _currentIndex--),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(
                      flex: 2,
                      child: PrimaryButton(
                        label: isLast ? "Finish Quiz" : AppStrings.nextQuestion,
                        icon: isLast
                            ? const Icon(Icons.check_rounded, size: 20)
                            : const Icon(Icons.arrow_forward_rounded, size: 20),
                        onPressed: hasSelected
                            ? () => _handleNext(total)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
