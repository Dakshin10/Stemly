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
    final extraBottomPadding = hasBottomBar
        ? AppSpacing.scrollBottomPadding
        : AppSpacing.space20;
    // Primary bottom nav tab destinations (Home, History, Settings, Account) must never imply a back button
    final bool shouldImplyLeading =
        automaticallyImplyLeading && currentBottomNavIndex == null;

    Widget content;

    if (isLargeTitle) {
      content = Scaffold(
        backgroundColor: bg,
        extendBody: hasBottomBar,
        floatingActionButton: floatingActionButton,
        body: SafeArea(
          top: false,
          bottom: false,
          child: Stack(
            children: [
              CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _LargeTitleHeaderDelegate(
                      title: title,
                      leading:
                          leading ??
                          (shouldImplyLeading
                              ? _buildDefaultLeading(context)
                              : null),
                      actions: actions,
                      backgroundColor: bg,
                      topPadding: MediaQuery.paddingOf(context).top,
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.only(bottom: extraBottomPadding),
                    sliver: SliverToBoxAdapter(child: body),
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
            ? _buildGlassBottomBar(
                context,
                currentBottomNavIndex!,
                onBottomNavTap,
              )
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
          leading:
              leading ??
              (shouldImplyLeading ? _buildDefaultLeading(context) : null),
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
            ? _buildGlassBottomBar(
                context,
                currentBottomNavIndex!,
                onBottomNavTap,
              )
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
        GlassTabItem(icon: Icons.camera_alt_rounded, label: AppStrings.tabHome),
        GlassTabItem(icon: Icons.history_rounded, label: AppStrings.tabHistory),
        GlassTabItem(
          icon: Icons.settings_rounded,
          label: AppStrings.tabSettings,
        ),
        GlassTabItem(icon: Icons.person_rounded, label: AppStrings.tabAccount),
      ],
    );
  }
}

/// Custom HIG-compliant Large Title Header Delegate.
/// - Eliminates excessive Material 3 empty padding above the title.
/// - Positions large title tightly under the status bar (~8-12 dp).
/// - Gracefully cross-fades large title into compact pinned navigation bar on scroll.
/// - Preserves leading and action buttons in a pinned 44 dp bar.
class _LargeTitleHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final Color backgroundColor;
  final double topPadding;

  _LargeTitleHeaderDelegate({
    required this.title,
    this.leading,
    this.actions,
    required this.backgroundColor,
    required this.topPadding,
  });

  bool get hasTopBar =>
      (actions != null && actions!.isNotEmpty) || leading != null;

  @override
  double get minExtent => topPadding + 44.0;

  @override
  double get maxExtent => topPadding + (hasTopBar ? 96.0 : 60.0);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final double collapseRange = maxExtent - minExtent;
    final double progress = collapseRange > 0.0
        ? (shrinkOffset / collapseRange).clamp(0.0, 1.0)
        : 1.0;

    final isScrolled = shrinkOffset > 4.0 || overlapsContent;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background with subtle glass/surface tint when scrolled
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: isScrolled
                  ? backgroundColor.withValues(alpha: 0.94)
                  : Colors.transparent,
              border: isScrolled
                  ? Border(
                      bottom: BorderSide(
                        color: AppColors.divider(
                          context,
                        ).withValues(alpha: progress),
                        width: 0.5,
                      ),
                    )
                  : null,
            ),
          ),
        ),

        // Large title: seated right below status bar (or below top action bar if present)
        Positioned(
          left: AppSpacing.screenMargin,
          right: AppSpacing.screenMargin,
          top: topPadding + (hasTopBar ? 44.0 : 8.0) - (shrinkOffset * 0.4),
          child: Opacity(
            opacity: (1.0 - progress * 1.6).clamp(0.0, 1.0),
            child: Text(
              title,
              style: AppTypography.largeTitle(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),

        // Pinned compact 44 dp top bar
        Positioned(
          left: 0,
          right: 0,
          top: topPadding,
          height: 44.0,
          child: Row(
            children: [
              // Leading slot
              if (leading != null)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: leading!,
                )
              else
                const SizedBox(width: AppSpacing.screenMargin),

              // Compact inline title: fades in as large title scrolls away
              Expanded(
                child: Opacity(
                  opacity: progress,
                  child: Text(
                    title,
                    textAlign: hasTopBar ? TextAlign.center : TextAlign.start,
                    style: AppTypography.headline(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // Actions slot
              if (actions != null && actions!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: actions!,
                  ),
                )
              else
                const SizedBox(width: AppSpacing.screenMargin),
            ],
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _LargeTitleHeaderDelegate oldDelegate) {
    return oldDelegate.title != title ||
        oldDelegate.leading != leading ||
        oldDelegate.actions != actions ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.topPadding != topPadding;
  }
}
