import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// Segmented Control following Apple HIG Neutral specification.
///
/// Features:
/// - Smooth gliding active indicator pill with cubic motion curve (260ms)
/// - Solid Black (#000000) on White text (Light mode)
/// - Solid White (#FFFFFF) on Black text (Dark mode)
/// - Smooth text color transition via AnimatedDefaultTextStyle
/// - IntrinsicHeight & IntrinsicWidth safe without speculative LayoutBuilder
class AppSegmentedControl<T> extends StatelessWidget {
  final T groupValue;
  final ValueChanged<T> onValueChanged;
  final Map<T, String> children;
  final double? itemWidth;

  const AppSegmentedControl({
    super.key,
    required this.groupValue,
    required this.onValueChanged,
    required this.children,
    this.itemWidth,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final selectedBg = isDark ? Colors.white : Colors.black;
    final selectedFg = isDark ? Colors.black : Colors.white;
    final unselectedFg = AppColors.textPrimary(context);

    final entries = children.entries.toList();
    final itemCount = entries.length;
    final selectedIndex = entries.indexWhere((e) => e.key == groupValue);
    final effectiveIndex = selectedIndex >= 0 ? selectedIndex : 0;

    int maxChars = 0;
    for (final label in children.values) {
      if (label.length > maxChars) maxChars = label.length;
    }

    final double widthPerItem =
        itemWidth ?? (maxChars * 8.5 + 32.0).clamp(68.0, 155.0);
    final double totalWidth = widthPerItem * itemCount + 6.0;

    return Container(
      width: totalWidth,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface2(context),
        borderRadius: BorderRadius.circular(AppRadii.capsule),
      ),
      child: Stack(
        children: [
          // Gliding Active Indicator Pill
          AnimatedPositioned(
            duration: AppMotion.getEffectiveDuration(
              context,
              const Duration(milliseconds: 260),
            ),
            curve: Curves.easeOutCubic,
            left: effectiveIndex * widthPerItem,
            top: 0,
            bottom: 0,
            width: widthPerItem,
            child: Container(
              decoration: BoxDecoration(
                color: selectedBg,
                borderRadius: BorderRadius.circular(AppRadii.capsule),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isDark ? 0.30 : 0.12,
                    ),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
                ],
              ),
            ),
          ),

          // Touch Targets Row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: entries.asMap().entries.map((mapEntry) {
              final index = mapEntry.key;
              final entry = mapEntry.value;
              final isSelected = index == effectiveIndex;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (!isSelected) {
                    AppHaptics.selection();
                    onValueChanged(entry.key);
                  }
                },
                child: Container(
                  width: widthPerItem,
                  constraints: const BoxConstraints(minHeight: 36),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  alignment: Alignment.center,
                  child: AnimatedDefaultTextStyle(
                    duration: AppMotion.getEffectiveDuration(
                      context,
                      const Duration(milliseconds: 200),
                    ),
                    curve: Curves.easeOutCubic,
                    style: AppTypography.subhead(context).copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? selectedFg : unselectedFg,
                    ),
                    child: Text(
                      entry.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
