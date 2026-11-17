import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// Non-intrusive notification banner displayed when backend AI is running in degraded mode.
/// Follows Apple HIG calm styling with neutral surface, subtle warning badge, and secondary text.
class DegradedModeBanner extends StatelessWidget {
  final String? message;
  final VoidCallback? onDismiss;

  const DegradedModeBanner({
    super.key,
    this.message,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final surface = AppColors.surface(context);
    final divider = AppColors.divider(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final warningColor = AppColors.accentText(context);

    return Semantics(
      label: "Degraded AI Mode Warning",
      hint: message ?? "Operating in fallback AI mode. Standard explanations are provided.",
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: warningColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: warningColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Fallback AI Mode",
                    style: AppTypography.subhead(context).copyWith(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message ?? "Standard curriculum content provided. Generative AI will resume when service load normalizes.",
                    style: AppTypography.footnote(context).copyWith(
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (onDismiss != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.close, size: 18, color: textSecondary),
                onPressed: onDismiss,
                tooltip: "Dismiss notice",
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
