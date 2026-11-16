import 'dart:ui';
import 'package:flutter/material.dart';

import '../../strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// AppScaffold: Core application layout providing Apple HIG-compliant structure.
/// - Adaptive large-title or standard inline navigation bar.
/// - Standard bottom NavigationBar with blurred translucent glass (or solid under High Contrast / Reduce Transparency).
/// - Automatic bottom padding (bar height + 16) ensuring the last content item is never obscured.
class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final bool isLargeTitle;
  final List<Widget>? actions;
  final Widget? leading;
  final int? currentBottomNavIndex;
  final ValueChanged<int>? onBottomNavTap;
  final FloatingActionButton? floatingActionButton;
  final Color? backgroundColor;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.isLargeTitle = false,
    this.actions,
    this.leading,
    this.currentBottomNavIndex,
    this.onBottomNavTap,
    this.floatingActionButton,
    this.backgroundColor,
  });

  static const double bottomBarHeight = 64.0;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.background(context);
    final hasBottomBar = currentBottomNavIndex != null;
    final extraBottomPadding = hasBottomBar ? (bottomBarHeight + AppSpacing.space16) : AppSpacing.space16;

    if (isLargeTitle) {
      return Scaffold(
        backgroundColor: bg,
        extendBody: hasBottomBar,
        floatingActionButton: floatingActionButton,
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverAppBar.large(
                title: Text(
                  title,
                  style: AppTypography.largeTitle(context),
                ),
                backgroundColor: bg,
                scrolledUnderElevation: 0,
                elevation: 0,
                leading: leading,
                actions: actions,
                pinned: true,
              ),
              SliverPadding(
                padding: EdgeInsets.only(bottom: extraBottomPadding),
                sliver: SliverToBoxAdapter(child: body),
              ),
            ],
          ),
        ),
        bottomNavigationBar: hasBottomBar
            ? _buildBottomBar(context, currentBottomNavIndex!, onBottomNavTap)
            : null,
      );
    }

    return Scaffold(
      backgroundColor: bg,
      extendBody: hasBottomBar,
      floatingActionButton: floatingActionButton,
      appBar: AppBar(
        title: Text(title, style: AppTypography.headline(context)),
        centerTitle: true,
        backgroundColor: AppColors.surface(context),
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: leading ?? _buildDefaultLeading(context),
        actions: actions,
      ),
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: extraBottomPadding),
          child: body,
        ),
      ),
      bottomNavigationBar: hasBottomBar
          ? _buildBottomBar(context, currentBottomNavIndex!, onBottomNavTap)
          : null,
    );
  }

  Widget? _buildDefaultLeading(BuildContext context) {
    final ModalRoute<dynamic>? parentRoute = ModalRoute.of(context);
    final bool canPop = parentRoute?.canPop ?? false;
    if (!canPop) return null;

    return Semantics(
      button: true,
      label: AppStrings.back,
      child: Tooltip(
        message: AppStrings.back,
        child: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    int activeIndex,
    ValueChanged<int>? onSelect,
  ) {
    final isHighContrast = MediaQuery.highContrastOf(context);
    final surfaceColor = AppColors.surface(context);
    final dividerColor = AppColors.divider(context);

    final glassColor = isHighContrast
        ? surfaceColor
        : surfaceColor.withValues(alpha: 0.85);

    void handleTap(int index) {
      if (onSelect != null) {
        onSelect(index);
        return;
      }
      switch (index) {
        case 0:
          Navigator.pushReplacementNamed(context, '/');
          break;
        case 1:
          Navigator.pushReplacementNamed(context, '/history');
          break;
        case 2:
          Navigator.pushReplacementNamed(context, '/settings');
          break;
        case 3:
          Navigator.pushReplacementNamed(context, '/account');
          break;
      }
    }

    final barContent = Container(
      height: bottomBarHeight,
      decoration: BoxDecoration(
        color: glassColor,
        border: Border(top: BorderSide(color: dividerColor, width: 0.8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(
            context: context,
            index: 0,
            active: activeIndex == 0,
            icon: Icons.camera_alt_outlined,
            activeIcon: Icons.camera_alt_rounded,
            label: AppStrings.tabHome,
            onTap: () => handleTap(0),
          ),
          _navItem(
            context: context,
            index: 1,
            active: activeIndex == 1,
            icon: Icons.history_rounded,
            activeIcon: Icons.history_rounded,
            label: AppStrings.tabHistory,
            onTap: () => handleTap(1),
          ),
          _navItem(
            context: context,
            index: 2,
            active: activeIndex == 2,
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings_rounded,
            label: AppStrings.tabSettings,
            onTap: () => handleTap(2),
          ),
          _navItem(
            context: context,
            index: 3,
            active: activeIndex == 3,
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
            label: AppStrings.tabAccount,
            onTap: () => handleTap(3),
          ),
        ],
      ),
    );

    if (isHighContrast) {
      return barContent;
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: barContent,
      ),
    );
  }

  Widget _navItem({
    required BuildContext context,
    required int index,
    required bool active,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required VoidCallback onTap,
  }) {
    final activeColor = AppColors.primary(context);
    final inactiveColor = AppColors.textSecondary(context);
    final color = active ? activeColor : inactiveColor;

    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: AppSpacing.minTouchTarget,
              minHeight: AppSpacing.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(active ? activeIcon : icon, color: color, size: 24),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: AppTypography.caption(context).copyWith(
                      color: color,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
