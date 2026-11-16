import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'buttons.dart';

/// EmptyState: Calm, focused view presenting an icon, title, explanation, and optional single action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppColors.textSecondary(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant(context),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: textSecondary),
            ),
            const SizedBox(height: AppSpacing.space16),
            Text(
              title,
              style: AppTypography.title2(context),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.space8),
            Text(
              message,
              style: AppTypography.subhead(context),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.space24),
              action!,
            ] else if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.space24),
              PrimaryButton(
                label: actionLabel!,
                onPressed: onAction,
                width: 220,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
