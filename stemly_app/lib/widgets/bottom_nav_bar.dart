import 'package:flutter/material.dart';

import '../presentation/components/glass_controls.dart';
import '../strings.dart';

/// Legacy navigation wrapper delegating directly to Apple Liquid Glass [GlassTabBar].
class BottomNavBar extends StatelessWidget {
  final int currentIndex;

  const BottomNavBar({super.key, required this.currentIndex});

  void _go(BuildContext context, int index) {
    if (currentIndex == index) return;
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

  @override
  Widget build(BuildContext context) {
    return GlassTabBar(
      selectedIndex: currentIndex,
      onTabSelected: (index) => _go(context, index),
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
