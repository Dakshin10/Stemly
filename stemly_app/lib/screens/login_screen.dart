import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../presentation/components/components.dart';
import '../services/firebase_auth_service.dart';
import '../strings.dart';
import '../theme/theme.dart';

enum AuthMode { signIn, signUp }

/// Clean, HIG-compliant Login Screen with Email/Password & Social Auth.
/// Adheres to Apple HIG: solid background, calm 44/52 dp touch targets,
/// smooth segmented mode switching, accessible password visibility controls,
/// and inline error feedback.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  AuthMode _authMode = AuthMode.signIn;
  bool _isLoading = false;
  String? _errorMessage;
  String? _infoMessage;
  bool _navigated = false;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  void _maybeNavigateToHome(FirebaseAuthService auth) {
    if (!mounted || _navigated || !auth.isAuthenticated) return;
    _navigated = true;
    Future.microtask(() {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    });
  }

  Future<void> _handleEmailAuth() async {
    setState(() {
      _errorMessage = null;
      _infoMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = AppStrings.enterValidEmail);
      return;
    }

    if (password.length < 6) {
      setState(() => _errorMessage = AppStrings.passwordLengthError);
      return;
    }

    if (_authMode == AuthMode.signUp) {
      final confirm = _confirmPasswordController.text;
      if (password != confirm) {
        setState(() => _errorMessage = AppStrings.passwordsDoNotMatch);
        return;
      }
    }

    setState(() => _isLoading = true);
    final authService = context.read<FirebaseAuthService>();

    try {
      if (_authMode == AuthMode.signIn) {
        await authService.signInWithEmail(email, password);
      } else {
        await authService.signUpWithEmail(
          email,
          password,
          displayName: name.isNotEmpty ? name : null,
        );
      }

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    } catch (error) {
      if (!mounted) return;
      final raw = error.toString().replaceFirst("Exception: ", "");
      setState(() {
        _errorMessage = raw;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorMessage = "Enter your email address above to receive a reset link.";
        _infoMessage = null;
      });
      _emailFocus.requestFocus();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    final authService = context.read<FirebaseAuthService>();
    try {
      await authService.sendPasswordReset(email);
      if (mounted) {
        setState(() {
          _infoMessage = AppStrings.resetPasswordSent;
        });
      }
    } catch (error) {
      if (!mounted) return;
      final raw = error.toString().replaceFirst("Exception: ", "");
      setState(() {
        _errorMessage = raw;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Apple Sign-in is coming soon.")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Sign in with Apple is available on Apple devices."),
        ),
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
          // Ambient soft orange orb
          if (!isReducedMotion)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.15,
              right: -50,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary(context).withValues(alpha: 0.14),
                      AppColors.primary(context).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenMargin,
                vertical: AppSpacing.md,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.md),

                    // TOP HEADER
                            Semantics(
                              header: true,
                              child: Text(
                                AppStrings.loginTitle,
                                style: AppTypography.largeTitle(context),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              AppStrings.loginSubtitle,
                              style: AppTypography.body(
                                context,
                              ).copyWith(color: textSecondary),
                            ),

                            const SizedBox(height: AppSpacing.md),

                            // MODE SWITCHER (Sign In vs Create Account)
                            Center(
                              child: AppSegmentedControl<AuthMode>(
                                groupValue: _authMode,
                                onValueChanged: (mode) {
                                  setState(() {
                                    _authMode = mode;
                                    _errorMessage = null;
                                    _infoMessage = null;
                                  });
                                },
                                children: const {
                                  AuthMode.signIn: AppStrings.signIn,
                                  AuthMode.signUp: AppStrings.signUp,
                                },
                              ),
                            ),

                            const SizedBox(height: AppSpacing.md),

                            // INLINE ERROR BANNER
                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: AppColors.error(
                                    context,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.card,
                                  ),
                                  border: Border.all(
                                    color: AppColors.error(
                                      context,
                                    ).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline_rounded,
                                      color: AppColors.error(context),
                                      size: 20,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: AppTypography.subhead(context)
                                            .copyWith(
                                              color: AppColors.error(context),
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                            ],

                            // INLINE INFO/SUCCESS BANNER
                            if (_infoMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: AppColors.success(
                                    context,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.card,
                                  ),
                                  border: Border.all(
                                    color: AppColors.success(
                                      context,
                                    ).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline_rounded,
                                      color: AppColors.success(context),
                                      size: 20,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        _infoMessage!,
                                        style: AppTypography.subhead(context)
                                            .copyWith(
                                              color: AppColors.success(context),
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                            ],

                            // INPUT FIELDS (Smooth sliding & expand transitions)
                            AnimatedCrossFade(
                              duration: const Duration(milliseconds: 260),
                              firstCurve: Curves.easeOutCubic,
                              secondCurve: Curves.easeOutCubic,
                              sizeCurve: Curves.easeOutCubic,
                              crossFadeState: _authMode == AuthMode.signUp
                                  ? CrossFadeState.showFirst
                                  : CrossFadeState.showSecond,
                              firstChild: Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                child: _buildInputField(
                                  context,
                                  controller: _nameController,
                                  focusNode: _nameFocus,
                                  nextFocusNode: _emailFocus,
                                  hintText: AppStrings.fullNameHint,
                                  labelText: AppStrings.fullName,
                                  prefixIcon: Icons.person_outline_rounded,
                                  textCapitalization: TextCapitalization.words,
                                ),
                              ),
                              secondChild: const SizedBox.shrink(),
                            ),

                            _buildInputField(
                              context,
                              controller: _emailController,
                              focusNode: _emailFocus,
                              nextFocusNode: _passwordFocus,
                              hintText: AppStrings.emailHint,
                              labelText: AppStrings.email,
                              prefixIcon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                            ),
                            const SizedBox(height: AppSpacing.sm),

                            _buildInputField(
                              context,
                              controller: _passwordController,
                              focusNode: _passwordFocus,
                              nextFocusNode: _authMode == AuthMode.signUp
                                  ? _confirmPasswordFocus
                                  : null,
                              hintText: AppStrings.passwordHint,
                              labelText: AppStrings.password,
                              prefixIcon: Icons.lock_outline_rounded,
                              obscureText: _obscurePassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                  color: textSecondary,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              onSubmitted: (_) {
                                if (_authMode == AuthMode.signIn) {
                                  _handleEmailAuth();
                                }
                              },
                            ),

                            AnimatedCrossFade(
                              duration: const Duration(milliseconds: 260),
                              firstCurve: Curves.easeOutCubic,
                              secondCurve: Curves.easeOutCubic,
                              sizeCurve: Curves.easeOutCubic,
                              crossFadeState: _authMode == AuthMode.signUp
                                  ? CrossFadeState.showFirst
                                  : CrossFadeState.showSecond,
                              firstChild: Padding(
                                padding: const EdgeInsets.only(top: AppSpacing.sm),
                                child: _buildInputField(
                                  context,
                                  controller: _confirmPasswordController,
                                  focusNode: _confirmPasswordFocus,
                                  hintText: AppStrings.confirmPasswordHint,
                                  labelText: AppStrings.confirmPassword,
                                  prefixIcon: Icons.lock_outline_rounded,
                                  obscureText: _obscureConfirmPassword,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      size: 20,
                                      color: textSecondary,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword;
                                      });
                                    },
                                  ),
                                  onSubmitted: (_) => _handleEmailAuth(),
                                ),
                              ),
                              secondChild: const SizedBox.shrink(),
                            ),

                            // FORGOT PASSWORD LINK
                            AnimatedCrossFade(
                              duration: const Duration(milliseconds: 220),
                              firstCurve: Curves.easeOutCubic,
                              secondCurve: Curves.easeOutCubic,
                              sizeCurve: Curves.easeOutCubic,
                              crossFadeState: _authMode == AuthMode.signIn
                                  ? CrossFadeState.showFirst
                                  : CrossFadeState.showSecond,
                              firstChild: Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _isLoading
                                      ? null
                                      : _handleForgotPassword,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                      horizontal: 8,
                                    ),
                                    minimumSize: const Size(44, 36),
                                  ),
                                  child: Text(
                                    AppStrings.forgotPassword,
                                    style: AppTypography.footnote(context)
                                        .copyWith(
                                          color: AppColors.primary(context),
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ),
                              secondChild: const SizedBox.shrink(),
                            ),

                            const SizedBox(height: AppSpacing.sm),

                            // PRIMARY ACTION BUTTON (Sign In / Create Account)
                            PrimaryButton(
                              label: _authMode == AuthMode.signIn
                                  ? AppStrings.signIn
                                  : AppStrings.signUp,
                              isLoading: _isLoading,
                              onPressed: _isLoading ? null : _handleEmailAuth,
                            ),

                            const SizedBox(height: AppSpacing.md),

                            // DIVIDER WITH TEXT
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: AppColors.divider(context),
                                    thickness: 1,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                  ),
                                  child: Text(
                                    AppStrings.orContinueWith,
                                    style: AppTypography.caption(context)
                                        .copyWith(color: textSecondary),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: AppColors.divider(context),
                                    thickness: 1,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: AppSpacing.md),

                            // GOOGLE & APPLE ACTION BUTTONS
                            SecondaryButton(
                              label: AppStrings.continueWithGoogle,
                              icon: Image.asset(
                                'assets/icons/google_logo.png',
                                width: 20,
                                height: 20,
                              ),
                              onPressed: _isLoading ? null : _handleGoogleSignIn,
                            ),
                            const SizedBox(height: AppSpacing.sm),

                            SecondaryButton(
                              label: AppStrings.continueWithApple,
                              icon: const Icon(Icons.apple_rounded, size: 20),
                              onPressed: _isLoading ? null : _handleAppleSignIn,
                            ),
                            const SizedBox(height: AppSpacing.sm),

                            // GUEST MODE
                            Center(
                              child: TextButton(
                                onPressed: _isLoading ? null : _continueAsGuest,
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(
                                    double.infinity,
                                    AppSpacing.minTouchTarget,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      AppStrings.continueAsGuest,
                                      style: AppTypography.callout(context)
                                          .copyWith(
                                            color: AppColors.primary(context),
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      AppStrings.guestFootnote,
                                      style: AppTypography.caption(
                                        context,
                                      ).copyWith(color: textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: AppSpacing.md),

                            // WHY SIGN IN SHEET
                            GlassSurface.sheet(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppStrings.whySignInTitle,
                                    style: AppTypography.headline(context),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  _buildBenefitRow(
                                    context,
                                    icon: Icons.devices_rounded,
                                    text: AppStrings.benefitSync,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  _buildBenefitRow(
                                    context,
                                    icon: Icons.lock_outline_rounded,
                                    text: AppStrings.benefitPasswordFree,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  _buildBenefitRow(
                                    context,
                                    icon: Icons.history_rounded,
                                    text: AppStrings.benefitHistory,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: AppSpacing.md),

                            // LEGAL FOOTNOTE
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.xs,
                              ),
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    AppStrings.legalPrefix,
                                    style: AppTypography.footnote(context),
                                  ),
                                  InkWell(
                                    onTap: () =>
                                        Navigator.pushNamed(context, '/terms'),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 8,
                                      ),
                                      child: Text(
                                        AppStrings.termsOfService,
                                        style: AppTypography.footnote(context)
                                            .copyWith(
                                              color: AppColors.primary(context),
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    AppStrings.legalAnd,
                                    style: AppTypography.footnote(context),
                                  ),
                                  InkWell(
                                    onTap: () => Navigator.pushNamed(
                                      context,
                                      '/privacy',
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 8,
                                      ),
                                      child: Text(
                                        AppStrings.privacyPolicy,
                                        style: AppTypography.footnote(context)
                                            .copyWith(
                                              color: AppColors.primary(context),
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                        ),
                      ),
                    ),
                  ),
        ],
      ),
    );
  }

  Widget _buildInputField(
    BuildContext context, {
    required TextEditingController controller,
    required FocusNode focusNode,
    FocusNode? nextFocusNode,
    required String hintText,
    required String labelText,
    required IconData prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    bool autocorrect = true,
    TextCapitalization textCapitalization = TextCapitalization.none,
    ValueChanged<String>? onSubmitted,
  }) {
    final textSecondary = AppColors.textSecondary(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface2(context),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: AppColors.divider(context).withValues(alpha: 0.5),
          width: 1.0,
        ),
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        keyboardType: keyboardType,
        autocorrect: autocorrect,
        textCapitalization: textCapitalization,
        textInputAction:
            nextFocusNode != null ? TextInputAction.next : TextInputAction.done,
        onFieldSubmitted: (val) {
          if (nextFocusNode != null) {
            nextFocusNode.requestFocus();
          } else if (onSubmitted != null) {
            onSubmitted(val);
          }
        },
        style: AppTypography.body(context),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: AppTypography.subhead(context).copyWith(
            color: textSecondary,
          ),
          hintText: hintText,
          hintStyle: AppTypography.subhead(context).copyWith(
            color: textSecondary.withValues(alpha: 0.5),
          ),
          prefixIcon: Icon(prefixIcon, size: 20, color: textSecondary),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitRow(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary(context)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: AppTypography.footnote(
              context,
            ).copyWith(color: AppColors.textPrimary(context)),
          ),
        ),
      ],
    );
  }
}
