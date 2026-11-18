import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// Apple Gloss Orange Primary Button.
///
/// Follows the Apple HIG Liquid Glass & Gloss specification:
/// - Subtle vertical gradient (top +8% lightness to base orange fill)
/// - 1 dp inner top highlight (White 35%)
/// - Soft orange shadow (Orange 25%, blur 20, offset 0, 6)
/// - Always BLACK text/icon on orange (7:1 contrast)
/// - 52 dp tall, 16 dp superellipse or capsule
/// - Pressed: scale 0.97, shadow shrinks, 120 ms spring, light impact haptic
/// - Disabled: neutral surface2 with textSecondary, no gloss
class PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool isLoading;
  final double? width;
  final bool isCapsule;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.width,
    this.isCapsule = true,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = widget.onPressed != null && !widget.isLoading;
    final isDark = AppColors.isDark(context);
    final isReducedMotion = AppMotion.isReducedMotion(context);

    final BorderRadius radius = widget.isCapsule
        ? BorderRadius.circular(100)
        : AppRadii.buttonRadius;

    // Disabled styling (neutral surface2, no gloss)
    if (!isEnabled) {
      return SizedBox(
        width: widget.width ?? double.infinity,
        height: AppSpacing.buttonHeight,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant(context),
            borderRadius: radius,
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space16),
          child: widget.isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.textSecondary(context),
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      widget.icon!,
                      const SizedBox(width: AppSpacing.space8),
                    ],
                    Flexible(
                      child: Text(
                        widget.label,
                        style: AppTypography.headline(
                          context,
                        ).copyWith(color: AppColors.textSecondary(context)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      );
    }

    // Active Gloss styling
    final Color baseColor = AppColors.primary(context);
    final Color topColor = isDark
        ? AppColors.orangeGlossTopDark
        : AppColors.orangeGlossTopLight;

    return Semantics(
      button: true,
      enabled: true,
      label: widget.label,
      child: SizedBox(
        width: widget.width ?? double.infinity,
        height: AppSpacing.buttonHeight,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: () {
            AppHaptics.buttonPress();
            widget.onPressed!();
          },
          child: AnimatedScale(
            scale: isReducedMotion ? 1.0 : (_isPressed ? 0.97 : 1.0),
            duration: AppMotion.pressDuration,
            curve: AppMotion.curve,
            child: AnimatedContainer(
              duration: AppMotion.pressDuration,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [topColor, baseColor],
                ),
                boxShadow: [
                  BoxShadow(
                    color: baseColor.withValues(
                      alpha: _isPressed ? 0.12 : 0.25,
                    ),
                    blurRadius: _isPressed ? 8 : 16,
                    offset: _isPressed
                        ? const Offset(0, 2)
                        : const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        IconTheme(
                          data: const IconThemeData(
                            color: AppColors.onOrange,
                            size: 20,
                          ),
                          child: widget.icon!,
                        ),
                        const SizedBox(width: AppSpacing.space8),
                      ],
                      Flexible(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                          child: Text(
                            widget.label,
                            key: ValueKey<String>(widget.label),
                            style: AppTypography.headline(context).copyWith(
                              color: AppColors.onOrange,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary action button (52 dp tall, outlined in divider color, solid surface).
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
    final isDark = AppColors.isDark(context);
    final dividerColor = AppColors.divider(context);
    final surfaceColor = isDark ? AppColors.surface2Dark : Colors.white;
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
            backgroundColor: surfaceColor,
            foregroundColor: textColor,
            side: BorderSide(color: dividerColor, width: 1.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.capsule),
            ),
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
                  style: AppTypography.headline(
                    context,
                  ).copyWith(fontWeight: FontWeight.w600),
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

/// Destructive text button (e.g. Delete, Clear).
class DestructiveTextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const DestructiveTextButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.error(context),
        minimumSize: const Size(
          AppSpacing.minTouchTarget,
          AppSpacing.minTouchTarget,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space12),
      ),
      child: Text(
        label,
        style: AppTypography.headline(context).copyWith(
          color: AppColors.error(context),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
