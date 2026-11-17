import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../presentation/components/components.dart';
import '../services/firebase_auth_service.dart';
import '../strings.dart';
import '../theme/theme.dart';

/// Minimal, calm Splash Screen following Apple HIG.
/// Displays clean STEMLY brand mark on a Liquid Glass card with a soft blurred orange ambient orb.
/// Maximum duration: 1.4 seconds (or immediately when auth initializes).
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
    final isReducedMotion = AppMotion.isReducedMotion(context);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // Soft ambient orange orb (max 15-20% area, blurred)
          if (!isReducedMotion)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.28,
              left: MediaQuery.of(context).size.width * 0.25,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      primary.withValues(alpha: 0.18),
                      primary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),

                  // Brand Icon Mark in Glass Card
                  GlassSurface(
                    width: 96,
                    height: 96,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Center(
                      child: Icon(
                        Icons.document_scanner_rounded,
                        size: 46,
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
                    style: AppTypography.callout(
                      context,
                    ).copyWith(color: textSecondary),
                  ),

                  const Spacer(flex: 2),

                  // Thin Accessible Progress Indicator
                  SizedBox(
                    width: 22,
                    height: 22,
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
        ],
      ),
    );
  }
}
