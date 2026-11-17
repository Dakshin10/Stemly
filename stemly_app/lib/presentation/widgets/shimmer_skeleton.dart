import 'package:flutter/material.dart';

/// Lightweight pulsing shimmer block for skeleton loading states.
class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.35, end: 0.75).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton loading state for STEM Notes Generation.
class NotesSkeleton extends StatelessWidget {
  const NotesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: "Generating notes, please wait...",
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Topic
            const ShimmerBox(width: 220, height: 28, borderRadius: 6),
            const SizedBox(height: 12),
            const ShimmerBox(width: double.infinity, height: 16),
            const SizedBox(height: 8),
            const ShimmerBox(width: 280, height: 16),
            const SizedBox(height: 24),

            // Concept Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 140, height: 20),
                    SizedBox(height: 12),
                    ShimmerBox(width: double.infinity, height: 14),
                    SizedBox(height: 8),
                    ShimmerBox(width: double.infinity, height: 14),
                    SizedBox(height: 8),
                    ShimmerBox(width: 200, height: 14),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Formula Block
            Card(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 160, height: 18),
                    SizedBox(height: 14),
                    Center(
                      child: ShimmerBox(
                        width: 240,
                        height: 32,
                        borderRadius: 8,
                      ),
                    ),
                    SizedBox(height: 14),
                    ShimmerBox(width: double.infinity, height: 14),
                    SizedBox(height: 6),
                    ShimmerBox(width: 180, height: 14),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Key Takeaways
            const ShimmerBox(width: 150, height: 22),
            const SizedBox(height: 14),
            for (int i = 0; i < 3; i++) ...[
              const Row(
                children: [
                  ShimmerBox(width: 10, height: 10, borderRadius: 5),
                  SizedBox(width: 12),
                  Expanded(
                    child: ShimmerBox(width: double.infinity, height: 14),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

/// Skeleton loading state for Quiz Generation.
class QuizSkeleton extends StatelessWidget {
  const QuizSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: "Generating quiz questions, please wait...",
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question Progress Header
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ShimmerBox(width: 100, height: 16),
                ShimmerBox(width: 60, height: 16),
              ],
            ),
            const SizedBox(height: 12),
            const ShimmerBox(
              width: double.infinity,
              height: 8,
              borderRadius: 4,
            ),
            const SizedBox(height: 24),

            // Question Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: double.infinity, height: 18),
                    SizedBox(height: 10),
                    ShimmerBox(width: 260, height: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 4 Multiple Choice Option Skeletons
            for (int i = 0; i < 4; i++) ...[
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 14.0,
                  ),
                  child: Row(
                    children: [
                      ShimmerBox(width: 24, height: 24, borderRadius: 12),
                      SizedBox(width: 14),
                      Expanded(
                        child: ShimmerBox(width: double.infinity, height: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            const Spacer(),

            // Submit Button Skeleton
            const ShimmerBox(
              width: double.infinity,
              height: 50,
              borderRadius: 25,
            ),
          ],
        ),
      ),
    );
  }
}
