import 'package:flutter/material.dart';

import '../../strings.dart';
import '../../theme/theme.dart';
import 'glass_controls.dart';

/// AppScaffold: Core application layout providing Apple HIG Liquid Glass structure.
/// - Adaptive large-title or standard inline navigation bar.
/// - Floating GlassTabBar capsule floating above content.
/// - Automatic bottom clearance (88 dp) ensuring content is never obscured.
/// - 24 dp subtle edge gradient fade at scroll edges.
class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final bool isLargeTitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
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
    this.automaticallyImplyLeading = true,
    this.currentBottomNavIndex,
    this.onBottomNavTap,
    this.floatingActionButton,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.background(context);
    final hasBottomBar = currentBottomNavIndex != null;
    final extraBottomPadding = hasBottomBar ? AppSpacing.scrollBottomPadding : AppSpacing.space20;
    // Primary bottom nav tab destinations (Home, History, Settings, Account) must never imply a back button
    final bool shouldImplyLeading = automaticallyImplyLeading && currentBottomNavIndex == null;

    Widget content;

    if (isLargeTitle) {
      content = Scaffold(
        backgroundColor: bg,
        extendBody: hasBottomBar,
        floatingActionButton: floatingActionButton,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverAppBar.large(
                    title: Text(
                      title,
                      style: AppTypography.largeTitle(context),
                    ),
                    backgroundColor: Colors.transparent,
                    scrolledUnderElevation: 0,
                    elevation: 0,
                    automaticallyImplyLeading: shouldImplyLeading,
                    leading: leading,
                    actions: actions,
                    pinned: true,
                  ),
                  SliverPadding(
                    padding: EdgeInsets.only(bottom: extraBottomPadding),
                    sliver: SliverToBoxAdapter(
                      child: body,
                    ),
                  ),
                ],
              ),

              // 24 dp top edge gradient fade
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 24,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          bg.withValues(alpha: 0.8),
                          bg.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: hasBottomBar
            ? _buildGlassBottomBar(context, currentBottomNavIndex!, onBottomNavTap)
            : null,
      );
    } else {
      content = Scaffold(
        backgroundColor: bg,
        extendBody: hasBottomBar,
        floatingActionButton: floatingActionButton,
        appBar: AppBar(
          title: Text(title, style: AppTypography.headline(context)),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          automaticallyImplyLeading: shouldImplyLeading,
          leading: leading ?? (shouldImplyLeading ? _buildDefaultLeading(context) : null),
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
            ? _buildGlassBottomBar(context, currentBottomNavIndex!, onBottomNavTap)
            : null,
      );
    }

    return content;
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

  Widget _buildGlassBottomBar(
    BuildContext context,
    int activeIndex,
    ValueChanged<int>? onSelect,
  ) {
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

    return GlassTabBar(
      selectedIndex: activeIndex,
      onTabSelected: handleTap,
      items: const [
        GlassTabItem(
          icon: Icons.camera_alt_rounded,
          label: AppStrings.tabHome,
        ),
        GlassTabItem(
          icon: Icons.history_rounded,
          label: AppStrings.tabHistory,
        ),
        GlassTabItem(
          icon: Icons.settings_rounded,
          label: AppStrings.tabSettings,
        ),
        GlassTabItem(
          icon: Icons.person_rounded,
          label: AppStrings.tabAccount,
        ),
      ],
    );
  }
}
