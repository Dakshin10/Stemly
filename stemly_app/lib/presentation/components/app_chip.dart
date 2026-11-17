import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// HIG-compliant Chip and Variable Badge.
///
/// Rules:
/// - Surface2 fill (#E8E8ED in light, #2C2C2E in dark)
/// - textPrimary label
/// - No colored borders
/// - "To find" chips: subtle 1 dp border in textSecondary + target icon + text
class AppChip extends StatelessWidget {
  final String label;
  final Widget? icon;
  final bool isSelected;
  final bool isToFind;
  final VoidCallback? onTap;

  const AppChip({
    super.key,
    required this.label,
    this.icon,
    this.isSelected = false,
    this.isToFind = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final surface2 = AppColors.surface2(context);

    // Selected state uses solid black (light) / solid white (dark)
    final bg = isSelected
        ? (isDark ? Colors.white : Colors.black)
        : surface2;
    final fg = isSelected
        ? (isDark ? Colors.black : Colors.white)
        : textPrimary;

    Border? border;
    if (isToFind) {
      border = Border.all(
        color: textSecondary.withValues(alpha: 0.6),
        width: 1.0,
      );
    }

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isToFind) ...[
          Icon(Icons.track_changes_rounded, size: 14, color: fg),
          const SizedBox(width: 4),
        ] else if (icon != null) ...[
          icon!,
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: AppTypography.footnote(context).copyWith(
            color: fg,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: () {
          AppHaptics.selection();
          onTap!();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadii.chip),
            border: border,
          ),
          child: content,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: border,
      ),
      child: content,
    );
  }
}
