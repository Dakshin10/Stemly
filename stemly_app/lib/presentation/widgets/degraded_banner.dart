import 'package:flutter/material.dart';

/// Non-intrusive notification banner displayed when backend AI is running in degraded mode.
class DegradedModeBanner extends StatelessWidget {
  final String? message;
  final VoidCallback? onDismiss;

  const DegradedModeBanner({
    super.key,
    this.message,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF3E2723) : const Color(0xFFFFF3E0);
    final borderColor = isDark ? const Color(0xFFFFB74D) : const Color(0xFFFF9800);
    final textColor = isDark ? const Color(0xFFFFE0B2) : const Color(0xFFE65100);

    return Semantics(
      label: "Degraded AI Mode Warning",
      hint: message ?? "Operating in fallback AI mode. Standard explanations are provided.",
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor.withValues(alpha: 0.5), width: 1.2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: borderColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Fallback AI Mode",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message ?? "Standard curriculum content provided. Generative AI will resume when service load normalizes.",
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            if (onDismiss != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.close, size: 18, color: textColor),
                onPressed: onDismiss,
                tooltip: "Dismiss notice",
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
