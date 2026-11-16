import 'package:flutter/material.dart';

import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// StatusPill: Displays an icon + text label + status color (success, warning, error, primary).
/// Respects Apple HIG accessible status pairing (color is never used alone).
class StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color? backgroundColor;

  const StatusPill({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? color.withValues(alpha: 0.12);

    return Semantics(
      container: true,
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space12,
          vertical: AppSpacing.space4 + 2,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppRadii.chipRadius,
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: AppSpacing.space4 + 2),
            Text(
              label,
              style: AppTypography.caption(context).copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
