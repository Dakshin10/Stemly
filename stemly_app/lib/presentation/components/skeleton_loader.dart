import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';

/// Skeleton loader that respects user accessibility preferences (`disableAnimations`).
/// Shows static block under reduce motion; subtle pulse under standard motion.
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _opacity;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isReduced = AppMotion.isReducedMotion(context);
    if (!isReduced && _controller == null) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1000),
      )..repeat(reverse: true);
      _opacity = Tween<double>(
        begin: 0.45,
        end: 0.9,
      ).animate(CurvedAnimation(parent: _controller!, curve: Curves.easeInOut));
    } else if (isReduced && _controller != null) {
      _controller?.dispose();
      _controller = null;
      _opacity = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = AppColors.surfaceVariant(context);
    final radius = widget.borderRadius ?? AppRadii.buttonRadius;

    if (_controller == null || _opacity == null) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: baseColor, borderRadius: radius),
      );
    }

    return AnimatedBuilder(
      animation: _opacity!,
      builder: (context, _) {
        return Opacity(
          opacity: _opacity!.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(color: baseColor, borderRadius: radius),
          ),
        );
      },
    );
  }
}

/// A standard card skeleton with title, description, and action placeholders.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space16),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.divider(context), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonLoader(width: 140, height: 20),
          const SizedBox(height: AppSpacing.space12),
          const SkeletonLoader(width: double.infinity, height: 14),
          const SizedBox(height: AppSpacing.space8),
          const SkeletonLoader(width: 200, height: 14),
        ],
      ),
    );
  }
}
