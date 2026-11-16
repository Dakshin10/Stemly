import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import 'glass_surface.dart';

/// Item definition for [GlassTabBar].
class GlassTabItem {
  final IconData icon;
  final String label;

  const GlassTabItem({
    required this.icon,
    required this.label,
  });
}

/// Floating Apple Liquid Glass Tab Bar.
///
/// Specifications:
/// - 64 dp tall capsule floating above content
/// - Inset 16 dp from the sides, 12 dp above safe area bottom
/// - Sliding glass "lens" indicator driven by Apple playful spring
/// - Selected icon and label tint orange (#FF6B00 / #FF8A3D)
/// - Subtly compresses on press (scale 0.98) with selection haptics
class GlassTabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final List<GlassTabItem> items;

  const GlassTabBar({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.floatingTabBarInset,
          0,
          AppSpacing.floatingTabBarInset,
          AppSpacing.floatingTabBarBottomClearance + bottomInset,
        ),
        child: SizedBox(
          height: AppSpacing.floatingTabBarHeight,
          child: GlassSurface.capsule(
            padding: const EdgeInsets.all(4),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tabWidth = constraints.maxWidth / items.length;

                return Stack(
                  children: [
                    // Sliding Glass Lens Indicator
                    AnimatedPositioned(
                      duration: AppMotion.getEffectiveDuration(
                        context,
                        const Duration(milliseconds: 350),
                      ),
                      curve: Curves.easeOutCubic,
                      left: selectedIndex * tabWidth,
                      top: 0,
                      width: tabWidth,
                      height: constraints.maxHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary(context).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: AppColors.primary(context).withValues(alpha: 0.28),
                            width: 1.0,
                          ),
                        ),
                      ),
                    ),

                    // Tab Buttons
                    Row(
                      children: List.generate(items.length, (index) {
                        final item = items[index];
                        final isSelected = selectedIndex == index;

                        return Expanded(
                          child: _GlassTabButton(
                            item: item,
                            isSelected: isSelected,
                            onTap: () {
                              if (selectedIndex != index) {
                                AppHaptics.selection();
                                onTabSelected(index);
                              }
                            },
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassTabButton extends StatefulWidget {
  final GlassTabItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _GlassTabButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_GlassTabButton> createState() => _GlassTabButtonState();
}

class _GlassTabButtonState extends State<_GlassTabButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.primary(context);
    final inactiveColor = AppColors.textSecondary(context);
    final isReducedMotion = AppMotion.isReducedMotion(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: isReducedMotion ? 1.0 : (_isPressed ? 0.94 : 1.0),
        duration: AppMotion.pressDuration,
        curve: AppMotion.curve,
        child: Container(
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.item.icon,
                size: 22,
                color: widget.isSelected ? activeColor : inactiveColor,
              ),
              const SizedBox(height: 2),
              Text(
                widget.item.label,
                style: AppTypography.caption(context).copyWith(
                  fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: widget.isSelected ? activeColor : inactiveColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating Apple Liquid Glass Top Navigation Bar.
class GlassNavBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool isCollapsed;

  const GlassNavBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.isCollapsed = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56.0);

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return GlassSurface(
      height: 56.0 + topPadding,
      padding: EdgeInsets.only(top: topPadding),
      borderRadius: BorderRadius.zero,
      child: NavigationToolbar(
        leading: leading != null
            ? ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: leading,
              )
            : null,
        middle: Text(
          title,
          style: AppTypography.headline(context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: actions != null && actions!.isNotEmpty
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: actions!,
              )
            : null,
        centerMiddle: true,
      ),
    );
  }
}

/// 44x44 dp Liquid Glass Circular Icon Button.
class GlassIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final double size;

  const GlassIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.color,
    this.size = 20,
  });

  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.color ?? AppColors.textPrimary(context);
    final isReducedMotion = AppMotion.isReducedMotion(context);

    Widget button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onPressed == null ? null : (_) => setState(() => _isPressed = true),
      onTapUp: widget.onPressed == null ? null : (_) => setState(() => _isPressed = false),
      onTapCancel: widget.onPressed == null ? null : () => setState(() => _isPressed = false),
      onTap: () {
        if (widget.onPressed != null) {
          AppHaptics.selection();
          widget.onPressed!();
        }
      },
      child: AnimatedScale(
        scale: isReducedMotion ? 1.0 : (_isPressed ? 0.92 : 1.0),
        duration: AppMotion.pressDuration,
        curve: AppMotion.curve,
        child: SizedBox(
          width: AppSpacing.minTouchTarget,
          height: AppSpacing.minTouchTarget,
          child: GlassSurface.capsule(
            child: Center(
              child: Icon(
                widget.icon,
                size: widget.size,
                color: widget.onPressed == null
                    ? iconColor.withValues(alpha: 0.35)
                    : iconColor,
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }

    return button;
  }
}

/// Floating Liquid Glass Composer (pinned above the keyboard).
class GlassComposer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isSending;
  final String hintText;

  const GlassComposer({
    super.key,
    required this.controller,
    required this.onSend,
    this.isSending = false,
    this.hintText = "Ask AI assistant...",
  });

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      borderRadius: BorderRadius.circular(AppRadii.composer),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: AppTypography.body(context),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: AppTypography.subhead(context),
                border: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: AppSpacing.controlSpacing),
          SizedBox(
            width: AppSpacing.minTouchTarget,
            height: AppSpacing.minTouchTarget,
            child: IconButton(
              icon: isSending
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary(context),
                      ),
                    )
                  : Icon(Icons.arrow_upward_rounded, color: AppColors.primary(context)),
              onPressed: isSending ? null : onSend,
            ),
          ),
        ],
      ),
    );
  }
}
