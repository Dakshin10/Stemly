import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/storage/offline_storage.dart';
import '../presentation/components/components.dart';
import '../strings.dart';
import '../theme/theme.dart';

/// HIG-compliant Settings Screen for STEMLY.
/// Grouped insets, 56 dp rows, adaptive controls, and plain-language labels.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showThemePicker(BuildContext context, ThemeProvider provider) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text("Select Appearance"),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              provider.setThemeMode(ThemeMode.system);
              Navigator.pop(ctx);
            },
            child: const Text(AppStrings.themeSystem),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              provider.setThemeMode(ThemeMode.light);
              Navigator.pop(ctx);
            },
            child: const Text(AppStrings.themeLight),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              provider.setThemeMode(ThemeMode.dark);
              Navigator.pop(ctx);
            },
            child: const Text(AppStrings.themeDark),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text(AppStrings.cancel),
        ),
      ),
    );
  }

  void _showAiDetailDialog(BuildContext context) {
    AppDialogs.confirm(
      context: context,
      title: AppStrings.stemlyCloudAI,
      message:
          "STEMLY uses high-speed cloud intelligence to transcribe diagrams, generate mathematical notes, and synthesize real-time physics simulations.",
      confirmLabel: AppStrings.ok,
    );
  }

  Future<void> _clearLocalCache(BuildContext context) async {
    final confirmed = await AppDialogs.confirm(
      context: context,
      title: AppStrings.clearCacheConfirmTitle,
      message: AppStrings.clearCacheConfirmBody,
      confirmLabel: AppStrings.delete,
      isDestructive: true,
    );

    if (confirmed == true) {
      await OfflineStorage.clearAll();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Local cache cleared.")),
        );
      }
    }
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return AppStrings.themeSystem;
      case ThemeMode.light:
        return AppStrings.themeLight;
      case ThemeMode.dark:
        return AppStrings.themeDark;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final textSecondary = AppColors.textSecondary(context);

    return AppScaffold(
      title: AppStrings.settingsTitle,
      isLargeTitle: true,
      currentBottomNavIndex: 2,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.sm),

            // 1. APPEARANCE
            GroupedSection(
              title: AppStrings.sectionAppearance,
              children: [
                GroupedRow(
                  leading: Icon(
                    Icons.palette_outlined,
                    color: AppColors.primary(context),
                    size: 22,
                  ),
                  title: AppStrings.theme,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _themeModeLabel(themeProvider.themeMode),
                        style: AppTypography.subhead(context),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: textSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                  onTap: () => _showThemePicker(context, themeProvider),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // 2. NOTIFICATIONS
            GroupedSection(
              title: AppStrings.sectionNotifications,
              children: [
                GroupedRow(
                  leading: Icon(
                    Icons.notifications_none_rounded,
                    color: AppColors.primary(context),
                    size: 22,
                  ),
                  title: "Study reminders",
                  subtitle: AppStrings.notificationExplanation,
                  trailing: CupertinoSwitch(
                    value: themeProvider.notifications,
                    activeTrackColor: AppColors.primary(context),
                    onChanged: (val) => themeProvider.toggleNotifications(val),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // 3. SCANNING
            GroupedSection(
              title: AppStrings.sectionScanning,
              children: [
                GroupedRow(
                  leading: Icon(
                    Icons.wifi_rounded,
                    color: AppColors.primary(context),
                    size: 22,
                  ),
                  title: AppStrings.wifiOnly,
                  subtitle: AppStrings.wifiOnlyExplanation,
                  trailing: CupertinoSwitch(
                    value: themeProvider.wifiOnly,
                    activeTrackColor: AppColors.primary(context),
                    onChanged: (val) => themeProvider.toggleWifiOnly(val),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // 4. AI STATUS
            GroupedSection(
              title: AppStrings.sectionAI,
              children: [
                GroupedRow(
                  leading: Icon(
                    Icons.auto_awesome,
                    color: AppColors.primary(context),
                    size: 22,
                  ),
                  title: AppStrings.stemlyCloudAI,
                  subtitle: "Multimodal reasoning & simulations",
                  trailing: StatusPill.success(label: AppStrings.connected),
                  onTap: () => _showAiDetailDialog(context),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // 5. DATA & PRIVACY
            GroupedSection(
              title: AppStrings.sectionDataPrivacy,
              children: [
                GroupedRow(
                  leading: Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.primary(context),
                    size: 22,
                  ),
                  title: AppStrings.privacyPolicy,
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: textSecondary,
                    size: 20,
                  ),
                  onTap: () => Navigator.pushNamed(context, '/privacy'),
                ),
                GroupedRow(
                  leading: Icon(
                    Icons.description_outlined,
                    color: AppColors.primary(context),
                    size: 22,
                  ),
                  title: AppStrings.termsOfService,
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: textSecondary,
                    size: 20,
                  ),
                  onTap: () => Navigator.pushNamed(context, '/terms'),
                ),
                GroupedRow(
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error(context),
                    size: 22,
                  ),
                  title: AppStrings.clearLocalCache,
                  onTap: () => _clearLocalCache(context),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // 6. ABOUT
            GroupedSection(
              title: AppStrings.sectionAbout,
              children: [
                GroupedRow(
                  leading: Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.primary(context),
                    size: 22,
                  ),
                  title: AppStrings.version,
                  trailing: Text(
                    "1.0.0",
                    style: AppTypography.subhead(context),
                  ),
                ),
                GroupedRow(
                  leading: Icon(
                    Icons.article_outlined,
                    color: AppColors.primary(context),
                    size: 22,
                  ),
                  title: AppStrings.licenses,
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: textSecondary,
                    size: 20,
                  ),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: AppStrings.appName,
                    applicationVersion: "1.0.0",
                    applicationLegalese: "© 2026 STEMLY. All rights reserved.",
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
