import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/storage/offline_storage.dart';
import '../services/firebase_auth_service.dart';
import '../strings.dart';
import '../theme/theme.dart';
import 'scan_arc_painter.dart';

/// Redesigned in-app Splash Screen conforming strictly to Apple Human Interface Guidelines.
/// Communicates "scan, then simulate" via a 100 pt glass tile, single scan sweep,
/// parabolic trajectory arc, and typography entrance in ~1.2s.
/// Handed off immediately when initialization completes without artificial delays.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Staggered motion intervals (total ~1200 ms)
  late final Animation<double> _scanProgress;
  late final Animation<double> _arcProgress;
  late final Animation<double> _wordmarkOpacity;
  late final Animation<double> _wordmarkSlide;
  late final Animation<double> _taglineOpacity;

  Timer? _loadingTimer;
  bool _isInitComplete = false;
  bool _showLoadingIndicator = false;
  bool _hasNavigated = false;
  bool _didAnnounceLoading = false;

  // Threshold where the wordmark entrance is reached (~750 ms)
  static const double _wordmarkThreshold = 0.65;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // 1. Thin scan line sweeps top to bottom once across the glyph (0 to 600 ms)
    _scanProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.50, curve: Curves.easeOutCubic),
    );

    // 2. Parabolic arc draws from tile right edge as scan finishes (500 to 920 ms)
    _arcProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.42, 0.77, curve: Curves.easeOutCubic),
    );

    // 3. "STEMLY" wordmark fades & rises 8 pt into place (740 to 990 ms)
    _wordmarkOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.62, 0.83, curve: Curves.easeOutCubic),
    );
    _wordmarkSlide = Tween<double>(begin: 8.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.62, 0.83, curve: Curves.easeOutCubic),
      ),
    );

    // 4. Tagline fades in 80 ms after wordmark (820 to 1070 ms)
    _taglineOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.68, 0.89, curve: Curves.easeOutCubic),
    );

    _controller.addListener(_onAnimationTick);
    _controller.addStatusListener(_onAnimationStatus);

    // Progress indicator: hidden for first 400 ms. Only shows if init takes longer.
    _loadingTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted || _isInitComplete || _hasNavigated) return;
      setState(() {
        _showLoadingIndicator = true;
      });
      if (!_didAnnounceLoading) {
        _didAnnounceLoading = true;
        // ignore: deprecated_member_use
        SemanticsService.announce("Loading", TextDirection.ltr);
      }
    });

    // Start entrance motion & background initialization in parallel
    _controller.forward();
    _performInitialization();
  }

  void _onAnimationTick() {
    // Exit as soon as init completes AND wordmark entrance is reached
    if (_isInitComplete && _controller.value >= _wordmarkThreshold) {
      _navigateNext();
    }
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _isInitComplete) {
      _navigateNext();
    }
  }

  Future<void> _performInitialization() async {
    try {
      // 1. Auth service state restore & verification
      final auth = context.read<FirebaseAuthService>();
      if (!auth.isAuthenticated) {
        try {
          await auth
              .initialize()
              .timeout(const Duration(milliseconds: 400));
        } catch (_) {}
      }

      // 2. OfflineStorage schema v3 initialization & scoping
      try {
        await OfflineStorage.init(userUid: auth.currentUser?.uid)
            .timeout(const Duration(milliseconds: 400));
      } catch (_) {}
    } catch (e) {
      debugPrint("Warning during splash initialization: $e");
    }

    if (!mounted) return;
    _isInitComplete = true;

    // If Reduce Motion is enabled, or sequence already reached wordmark, exit now
    final isReducedMotion = AppMotion.isReducedMotion(context);
    if (isReducedMotion || _controller.value >= _wordmarkThreshold) {
      _navigateNext();
    }
  }

  void _onSkip() {
    if (_hasNavigated || !mounted) return;
    if (_isInitComplete) {
      _navigateNext();
    } else {
      // Fast forward animation to show full brand mark while slow init completes
      _controller.value = 1.0;
    }
  }

  Future<void> _navigateNext() async {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    _loadingTimer?.cancel();
    _controller.stop();

    final auth = context.read<FirebaseAuthService>();
    bool isGuest = false;
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(milliseconds: 200));
      isGuest = prefs.getBool('stemly_is_guest') ?? false;
    } catch (_) {}

    if (!mounted) return;

    // Route to Home if signed in or guest, otherwise to Welcome/Login
    final nextRoute = (auth.isAuthenticated || isGuest) ? '/' : '/login';

    Navigator.pushReplacementNamed(context, nextRoute);
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _controller.removeListener(_onAnimationTick);
    _controller.removeStatusListener(_onAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.backgroundDark;
    final accentColor = AppColors.accentFill(context);
    final textPrimary = AppColors.textPrimary(context);
    final isReducedMotion = AppMotion.isReducedMotion(context);
    final isHighContrast = MediaQuery.highContrastOf(context);

    // In Reduce Motion, show static final frame directly
    if (isReducedMotion && _controller.value < 1.0) {
      _controller.value = 1.0;
    }

    final showGlow = !isHighContrast && !isReducedMotion;
    final taglineColor = isHighContrast
        ? textPrimary
        : AppColors.textSecondary(context);

    return Scaffold(
      backgroundColor: bg,
      body: Semantics(
        label: "STEMLY, Scan, visualise, learn",
        container: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onSkip,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            children: [
                              // Optical centering: 2 flex above, 3 flex below
                              const Spacer(flex: 2),

                              // CENTER BRAND GROUP (Tile, Arc, Wordmark, Tagline)
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // 100 pt Glass Tile + Arc Stack
                                    SizedBox(
                                      width: 100,
                                      height: 100,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        alignment: Alignment.center,
                                        children: [
                                          // Faint ambient radial glow behind tile
                                          if (showGlow)
                                            Positioned(
                                              child: ExcludeSemantics(
                                                child: Container(
                                                  width: 220,
                                                  height: 220,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    gradient: RadialGradient(
                                                      colors: [
                                                        accentColor.withValues(
                                                          alpha: 0.12,
                                                        ),
                                                        accentColor.withValues(
                                                          alpha: 0.0,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),

                                          // 100 pt Glass Tile
                                          Container(
                                            width: 100,
                                            height: 100,
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceDark
                                                  .withValues(alpha: 0.85),
                                              borderRadius:
                                                  BorderRadius.circular(22),
                                              border: Border.all(
                                                color: Colors.white
                                                    .withValues(alpha: 0.12),
                                                width: 1.0,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.35),
                                                  blurRadius: 18,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                // Scan-frame glyph (vector)
                                                Icon(
                                                  Icons
                                                      .document_scanner_rounded,
                                                  size: 48,
                                                  color: accentColor,
                                                ),

                                                // Sweeping scan line inside corner brackets
                                                if (!isReducedMotion)
                                                  ExcludeSemantics(
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            16,
                                                          ),
                                                      child: SizedBox(
                                                        width: 52,
                                                        height: 52,
                                                        child: CustomPaint(
                                                          painter:
                                                              ScanLinePainter(
                                                                progress:
                                                                    _scanProgress
                                                                        .value,
                                                                color:
                                                                    accentColor,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),

                                          // Parabolic arc launching from tile's right edge
                                          if (!isReducedMotion)
                                            Positioned(
                                              left: 100, // exact right edge
                                              top: 28,
                                              child: ExcludeSemantics(
                                                child: SizedBox(
                                                  width: 68,
                                                  height: 44,
                                                  child: CustomPaint(
                                                    painter:
                                                        ProjectileArcPainter(
                                                          progress:
                                                              _arcProgress
                                                                  .value,
                                                          color: accentColor,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: AppSpacing.space24),

                                    // Wordmark (fades and rises 8 pt)
                                    Transform.translate(
                                      offset: Offset(
                                        0.0,
                                        isReducedMotion
                                            ? 0.0
                                            : _wordmarkSlide.value,
                                      ),
                                      child: Opacity(
                                        opacity: isReducedMotion
                                            ? 1.0
                                            : _wordmarkOpacity.value,
                                        child: Text(
                                          AppStrings.appName,
                                          style: AppTypography.largeTitle(
                                            context,
                                          ).copyWith(
                                            letterSpacing: -0.5,
                                            fontWeight: FontWeight.w700,
                                            color: textPrimary,
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: AppSpacing.space8),

                                    // Tagline (fades in 80 ms later)
                                    Opacity(
                                      opacity: isReducedMotion
                                          ? 1.0
                                          : _taglineOpacity.value,
                                      child: Text(
                                        AppStrings.appTagline,
                                        style: AppTypography.body(
                                          context,
                                        ).copyWith(color: taglineColor),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const Spacer(flex: 3),

                              // BOTTOM PROGRESS INDICATOR (Fades in conditionally after 400 ms)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.lg,
                                ),
                                child: AnimatedOpacity(
                                  opacity: _showLoadingIndicator ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 240),
                                  curve: Curves.easeOutCubic,
                                  child: Semantics(
                                    label: "Loading",
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator
                                              .adaptive(
                                                strokeWidth: 2.0,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(accentColor),
                                              ),
                                        ),
                                        const SizedBox(height: AppSpacing.sm),
                                        Text(
                                          "Loading",
                                          style: AppTypography.footnote(
                                            context,
                                          ).copyWith(color: taglineColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
