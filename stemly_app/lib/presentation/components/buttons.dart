import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Primary action button (52 dp tall, brand primary fill, WCAG AA contrast).
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool isLoading;
  final double? width;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppColors.primary(context);
    final onPrimaryColor = AppColors.onPrimary(context);

    return Semantics(
      button: true,
      enabled: onPressed != null && !isLoading,
      label: label,
      child: SizedBox(
        width: width ?? double.infinity,
        height: AppSpacing.buttonHeight,
        child: FilledButton(
          onPressed: isLoading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: onPrimaryColor,
            disabledBackgroundColor: primaryColor.withValues(alpha: 0.38),
            disabledForegroundColor: onPrimaryColor.withValues(alpha: 0.38),
            shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space16),
            elevation: 0,
          ),
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(onPrimaryColor),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      icon!,
                      const SizedBox(width: AppSpacing.space8),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        style: AppTypography.headline(context).copyWith(
                          color: onPrimaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Secondary action button (52 dp tall, outlined in divider color).
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final double? width;

  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final dividerColor = AppColors.divider(context);
    final textColor = AppColors.textPrimary(context);

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: SizedBox(
        width: width ?? double.infinity,
        height: AppSpacing.buttonHeight,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: textColor,
            side: BorderSide(color: dividerColor, width: 1.0),
            shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space16),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                icon!,
                const SizedBox(width: AppSpacing.space8),
              ],
              Flexible(
                child: Text(
                  label,
                  style: AppTypography.headline(context).copyWith(
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Destructive text action button (minimum 44x44 dp target, error token).
class DestructiveTextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;

  const DestructiveTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final errorColor = AppColors.error(context);

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppSpacing.minTouchTarget,
          minWidth: AppSpacing.minTouchTarget,
        ),
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: errorColor,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space16,
              vertical: AppSpacing.space8,
            ),
            shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                icon!,
                const SizedBox(width: AppSpacing.space8),
              ],
              Text(
                label,
                style: AppTypography.headline(context).copyWith(color: errorColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
