import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/firebase_auth_service.dart';
import '../strings.dart';
import '../theme/theme.dart';

/// Minimal, calm Splash Screen following Apple HIG.
/// Displays clean STEMLY brand mark, tagline, and a subtle progress indicator.
/// Maximum duration: 1.5 seconds (or immediately when auth initializes).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _startBootstrap();
  }

  void _startBootstrap() {
    // Complete bootstrap within 1.2-1.5s max
    _timeoutTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      final auth = context.read<FirebaseAuthService>();
      final nextRoute = auth.isAuthenticated ? '/' : '/login';
      Navigator.pushReplacementNamed(context, nextRoute);
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.background(context);
    final primary = AppColors.primary(context);
    final textSecondary = AppColors.textSecondary(context);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),

              // Brand Icon Mark
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant(context),
                  borderRadius: AppRadii.cardRadius,
                  border: Border.all(color: AppColors.divider(context), width: 1.0),
                ),
                child: Center(
                  child: Icon(
                    Icons.document_scanner_rounded,
                    size: 44,
                    color: primary,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.space24),

              // App Name
              Text(
                AppStrings.appName,
                style: AppTypography.largeTitle(context).copyWith(
                  letterSpacing: -0.5,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: AppSpacing.space8),

              // Single Tagline
              Text(
                AppStrings.appTagline,
                style: AppTypography.callout(context).copyWith(
                  color: textSecondary,
                ),
              ),

              const Spacer(flex: 2),

              // Thin Accessible Progress Indicator
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator.adaptive(
                  strokeWidth: 2.0,
                  valueColor: AlwaysStoppedAnimation<Color>(primary),
                ),
              ),

              const SizedBox(height: AppSpacing.space16),

              Text(
                AppStrings.splashLoading,
                style: AppTypography.footnote(context),
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
