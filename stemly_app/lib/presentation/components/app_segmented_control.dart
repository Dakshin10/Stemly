import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// Segmented Control following Apple HIG Neutral specification.
///
/// Selected segment:
/// - Light mode: Solid Black (#000000) with White text
/// - Dark mode: Solid White (#FFFFFF) with Black text
/// Unselected segment:
/// - Surface2 (#E8E8ED in light, #2C2C2E in dark) with textPrimary
class AppSegmentedControl<T> extends StatelessWidget {
  final T groupValue;
  final ValueChanged<T> onValueChanged;
  final Map<T, String> children;

  const AppSegmentedControl({
    super.key,
    required this.groupValue,
    required this.onValueChanged,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final selectedBg = isDark ? Colors.white : Colors.black;
    final selectedFg = isDark ? Colors.black : Colors.white;
    final unselectedFg = AppColors.textPrimary(context);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface2(context),
        borderRadius: BorderRadius.circular(AppRadii.capsule),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: children.entries.map((entry) {
          final isSelected = entry.key == groupValue;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (!isSelected) {
                AppHaptics.selection();
                onValueChanged(entry.key);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              constraints: const BoxConstraints(minHeight: 36, minWidth: 44),
              decoration: BoxDecoration(
                color: isSelected ? selectedBg : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadii.capsule),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.2 : 0.08,
                          ),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                entry.value,
                style: AppTypography.subhead(context).copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? selectedFg : unselectedFg,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
