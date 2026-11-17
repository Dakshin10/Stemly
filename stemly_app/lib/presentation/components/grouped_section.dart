import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Inset grouped section container holding a series of grouped rows.
class GroupedSection extends StatelessWidget {
  final String? title;
  final String? footer;
  final List<Widget> children;

  const GroupedSection({
    super.key,
    this.title,
    this.footer,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final dividerColor = AppColors.divider(context);
    final surfaceColor = AppColors.surface(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.screenMargin,
                right: AppSpacing.screenMargin,
                bottom: AppSpacing.space8,
              ),
              child: Text(
                title!,
                style: AppTypography.footnote(
                  context,
                ).copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.2),
              ),
            ),
          ],
          Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: AppRadii.cardRadius,
              border: Border.all(color: dividerColor, width: 1.0),
            ),
            child: ClipRRect(
              borderRadius: AppRadii.cardRadius,
              child: Column(
                children: _buildSeparatedChildren(context, dividerColor),
              ),
            ),
          ),
          if (footer != null) ...[
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.screenMargin,
                right: AppSpacing.screenMargin,
                top: AppSpacing.space8,
              ),
              child: Text(footer!, style: AppTypography.footnote(context)),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildSeparatedChildren(
    BuildContext context,
    Color dividerColor,
  ) {
    final result = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      result.add(children[i]);
      if (i < children.length - 1) {
        result.add(
          Padding(
            padding: const EdgeInsets.only(left: 56.0),
            child: Divider(color: dividerColor, height: 1, thickness: 1),
          ),
        );
      }
    }
    return result;
  }
}

/// An individual row within a GroupedSection with min 56 dp height and 44 dp touch targets.
class GroupedRow extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final Color? destructiveColor;

  const GroupedRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = false,
    this.destructiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = destructiveColor ?? AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      label: title,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.groupedRowMinHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space16,
              vertical: AppSpacing.space12,
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    child: leading!,
                  ),
                  const SizedBox(width: AppSpacing.space16),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: AppTypography.body(context).copyWith(
                          color: textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: AppTypography.subhead(
                            context,
                          ).copyWith(color: textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AppSpacing.space12),
                  trailing!,
                ],
                if (showChevron) ...[
                  const SizedBox(width: AppSpacing.space8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: textSecondary,
                    size: 20,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
