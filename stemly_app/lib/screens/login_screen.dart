import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../presentation/components/components.dart';
import '../services/firebase_auth_service.dart';
import '../strings.dart';
import '../theme/theme.dart';

/// Clean, HIG-compliant Login Screen.
/// Solid background, clear value proposition, 52 dp action buttons, 44 dp touch targets,
/// and calm in-line error feedback.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  bool _navigated = false;

  void _maybeNavigateToHome(FirebaseAuthService auth) {
    if (!mounted || _navigated || !auth.isAuthenticated) return;
    _navigated = true;
    Future.microtask(() {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    });
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = context.read<FirebaseAuthService>();
    try {
      final credential = await authService.signInWithGoogle();
      if (credential != null && mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = AppStrings.connectionError;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleAppleSignIn() {
    if (!kIsWeb && Platform.isIOS) {
      // In production, invoke Sign in with Apple API
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Apple Sign-in is coming soon.")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sign in with Apple is available on Apple devices.")),
      );
    }
  }

  void _continueAsGuest() {
    Navigator.pushReplacementNamed(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FirebaseAuthService>();
    _maybeNavigateToHome(auth);

    final bg = AppColors.background(context);
    final textSecondary = AppColors.textSecondary(context);

    final isReducedMotion = AppMotion.isReducedMotion(context);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // Soft ambient orange orb (max 15-20% area, blurred)
          if (!isReducedMotion)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.20,
              right: -40,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary(context).withValues(alpha: 0.16),
                      AppColors.primary(context).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: AppSpacing.xl),

                          // TOP HEADER
                          Semantics(
                            header: true,
                            child: Text(
                              AppStrings.loginTitle,
                              style: AppTypography.largeTitle(context),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            AppStrings.loginSubtitle,
                            style: AppTypography.body(context).copyWith(color: textSecondary),
                          ),

                          const SizedBox(height: AppSpacing.lg),

                          // INLINE ERROR BANNER (only shown on failure)
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: AppColors.error(context).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppRadii.card),
                                border: Border.all(color: AppColors.error(context).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline_rounded, color: AppColors.error(context)),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: AppTypography.subhead(context).copyWith(
                                        color: AppColors.error(context),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _handleGoogleSignIn,
                                    child: Text(
                                      AppStrings.retry,
                                      style: AppTypography.headline(context).copyWith(
                                        color: AppColors.primary(context),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],

                          // WHY SIGN IN CARD (GLASS SHEET)
                          GlassSurface.sheet(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.whySignInTitle,
                                  style: AppTypography.headline(context),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                _buildBenefitRow(
                                  context,
                                  icon: Icons.devices_rounded,
                                  text: AppStrings.benefitSync,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                _buildBenefitRow(
                                  context,
                                  icon: Icons.lock_outline_rounded,
                                  text: AppStrings.benefitPasswordFree,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                _buildBenefitRow(
                                  context,
                                  icon: Icons.history_rounded,
                                  text: AppStrings.benefitHistory,
                                ),
                              ],
                            ),
                          ),

                      const Spacer(),
                      const SizedBox(height: AppSpacing.lg),

                      // BOTTOM ACTION STACK (52 dp height, 12 dp spacing)
                      PrimaryButton(
                        label: AppStrings.continueWithGoogle,
                        icon: const Icon(Icons.account_circle_outlined, size: 20),
                        isLoading: _isLoading,
                        onPressed: _isLoading ? null : _handleGoogleSignIn,
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      SecondaryButton(
                        label: AppStrings.continueWithApple,
                        icon: const Icon(Icons.apple_rounded, size: 20),
                        onPressed: _isLoading ? null : _handleAppleSignIn,
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      Center(
                        child: TextButton(
                          onPressed: _isLoading ? null : _continueAsGuest,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(double.infinity, AppSpacing.minTouchTarget),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AppStrings.continueAsGuest,
                                style: AppTypography.callout(context).copyWith(
                                  color: AppColors.primary(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                AppStrings.guestFootnote,
                                style: AppTypography.caption(context).copyWith(color: textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // LEGAL FOOTNOTE
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              AppStrings.legalPrefix,
                              style: AppTypography.footnote(context),
                            ),
                            InkWell(
                              onTap: () => Navigator.pushNamed(context, '/terms'),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                child: Text(
                                  AppStrings.termsOfService,
                                  style: AppTypography.footnote(context).copyWith(
                                    color: AppColors.primary(context),
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                            Text(
                              AppStrings.legalAnd,
                              style: AppTypography.footnote(context),
                            ),
                            InkWell(
                              onTap: () => Navigator.pushNamed(context, '/privacy'),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                child: Text(
                                  AppStrings.privacyPolicy,
                                  style: AppTypography.footnote(context).copyWith(
                                    color: AppColors.primary(context),
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  ),
);
  }

  Widget _buildBenefitRow(BuildContext context, {required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary(context)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: AppTypography.subhead(context).copyWith(
              color: AppColors.textPrimary(context),
            ),
          ),
        ),
      ],
    );
  }
}
