import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/services/stemly_api_service.dart';
import '../data/storage/offline_storage.dart';
import '../presentation/components/components.dart';
import '../services/firebase_auth_service.dart';
import '../strings.dart';
import '../theme/theme.dart';

/// HIG-compliant Account Screen for STEMLY.
/// Displays user identity, daily AI usage, sync status, and safe destructive actions.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _handleSignOut(BuildContext context, FirebaseAuthService authService) async {
    final confirmed = await AppDialogs.confirm(
      context: context,
      title: AppStrings.signOutConfirmTitle,
      message: AppStrings.signOutConfirmBody,
      confirmLabel: AppStrings.signOut,
      isDestructive: true,
    );

    if (confirmed == true) {
      await authService.signOut();
    }
  }

  Future<void> _handleDeleteAccount(BuildContext context, FirebaseAuthService authService) async {
    final step1 = await AppDialogs.confirm(
      context: context,
      title: AppStrings.deleteAccountStep1Title,
      message: AppStrings.deleteAccountStep1Body,
      confirmLabel: AppStrings.delete,
      isDestructive: true,
    );

    if (step1 != true || !context.mounted) return;

    final step2 = await AppDialogs.confirm(
      context: context,
      title: AppStrings.deleteAccountStep2Title,
      message: AppStrings.deleteAccountStep2Body,
      confirmLabel: AppStrings.delete,
      isDestructive: true,
    );

    if (step2 == true && context.mounted) {
      try {
        final apiService = context.read<StemlyApiService>();
        await apiService.deleteMyData();
        await OfflineStorage.clearAll();
        await authService.signOut();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Account and data deleted.")),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to delete account: $e")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<FirebaseAuthService>();
    final user = authService.currentUser;
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    return AppScaffold(
      title: AppStrings.accountTitle,
      isLargeTitle: true,
      currentBottomNavIndex: 3,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin),
        child: user == null
            ? _buildGuestView(context)
            : _buildAuthenticatedView(context, user, authService, textPrimary, textSecondary),
      ),
    );
  }

  Widget _buildGuestView(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.xl),
        EmptyState(
          icon: Icons.account_circle_outlined,
          title: AppStrings.signInToSync,
          message:
              "Sign in to unlock synced history, study notes, and personalised visualisations across your devices.",
          action: PrimaryButton(
            label: AppStrings.continueWithGoogle,
            icon: const Icon(Icons.login_rounded, size: 20),
            onPressed: () => Navigator.pushNamed(context, '/login'),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  Widget _buildAuthenticatedView(
    BuildContext context,
    dynamic user,
    FirebaseAuthService authService,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),

        // 80 DP AVATAR + NAME + EMAIL
        Center(
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceVariant(context),
                ),
                child: ClipOval(
                  child: user.photoURL != null && user.photoURL!.isNotEmpty
                      ? Image.network(
                          user.photoURL!,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stackTrace) => Icon(
                            Icons.person_rounded,
                            size: 40,
                            color: textSecondary,
                          ),
                        )
                      : Icon(
                          Icons.person_rounded,
                          size: 40,
                          color: textSecondary,
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                user.displayName ?? "STEMLY Student",
                style: AppTypography.title2(context),
              ),
              const SizedBox(height: 2),
              Text(
                user.email ?? "",
                style: AppTypography.subhead(context),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // USAGE & SYNC SECTION
        GroupedSection(
          title: "Usage & Status",
          children: [
            GroupedRow(
              leading: Icon(Icons.bolt_rounded, color: AppColors.warning(context), size: 22),
              title: AppStrings.dailyAIUsage,
              subtitle: "42 of 50 ${AppStrings.leftToday} • ${AppStrings.resetsAtMidnight}",
            ),
            GroupedRow(
              leading: Icon(Icons.cloud_done_rounded, color: AppColors.success(context), size: 22),
              title: AppStrings.syncStatus,
              trailing: StatusPill.success(label: AppStrings.synced),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.lg),

        // PRIVACY & TERMS SECTION
        GroupedSection(
          title: "Legal",
          children: [
            GroupedRow(
              leading: Icon(Icons.lock_outline_rounded, color: textPrimary, size: 22),
              title: AppStrings.privacyPolicy,
              trailing: Icon(Icons.chevron_right_rounded, color: textSecondary, size: 20),
              onTap: () => Navigator.pushNamed(context, '/privacy'),
            ),
            GroupedRow(
              leading: Icon(Icons.description_outlined, color: textPrimary, size: 22),
              title: AppStrings.termsOfService,
              trailing: Icon(Icons.chevron_right_rounded, color: textSecondary, size: 20),
              onTap: () => Navigator.pushNamed(context, '/terms'),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),

        // DESTRUCTIVE ACTIONS
        SecondaryButton(
          label: AppStrings.signOut,
          icon: const Icon(Icons.logout_rounded, size: 20),
          onPressed: () => _handleSignOut(context, authService),
        ),
        const SizedBox(height: AppSpacing.sm),

        DestructiveTextButton(
          label: AppStrings.deleteAccount,
          onPressed: () => _handleDeleteAccount(context, authService),
        ),

        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}
