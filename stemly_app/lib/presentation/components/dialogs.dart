import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../strings.dart';
import '../../theme/app_colors.dart';

/// Adaptive confirmation dialog and action sheet helpers following Apple HIG.
class AppDialogs {
  AppDialogs._();

  /// Shows an adaptive confirmation dialog (Cupertino on iOS, Material 3 on Android).
  static Future<bool> confirm({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = AppStrings.ok,
    String cancelLabel = AppStrings.cancel,
    bool isDestructive = false,
  }) async {
    final result = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: Text(title),
        content: Text(message),
        actions: [
          if (Theme.of(ctx).platform == TargetPlatform.iOS) ...[
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(cancelLabel),
            ),
            CupertinoDialogAction(
              isDestructiveAction: isDestructive,
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(confirmLabel),
            ),
          ] else ...[
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(cancelLabel),
            ),
            FilledButton(
              style: isDestructive
                  ? FilledButton.styleFrom(
                      backgroundColor: AppColors.error(ctx),
                      foregroundColor: AppColors.onPrimary(ctx),
                    )
                  : null,
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(confirmLabel),
            ),
          ],
        ],
      ),
    );

    return result ?? false;
  }

  /// Shows an action sheet for destructive choices.
  static Future<bool> showDestructiveActionSheet({
    required BuildContext context,
    required String title,
    required String message,
    required String destructiveLabel,
    String cancelLabel = AppStrings.cancel,
  }) async {
    final result = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(title),
        message: Text(message),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(destructiveLabel),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
      ),
    );

    return result ?? false;
  }
}
