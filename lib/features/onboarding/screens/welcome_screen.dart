import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/local/preferences_service.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/user_provider.dart';
import '../../../data/remote/auth_service.dart';
import '../widgets/auth_button.dart';

/// Entry point for unauthenticated users. Offers four paths:
///  1. Create account (email/password)
///  2. Sign in (email/password)
///  3. Continue with Google
///  4. Continue as guest (skips auth, falls into preference setup)
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _isLoading = false;

  Future<void> _continueWithGoogle() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final auth = ref.read(authServiceProvider);
      final fbUser = await auth.signInWithGoogle();
      final hasComplete =
          await ref.read(userProvider.notifier).pullFromCloudAndMerge(
                firebaseUid: fbUser.uid,
                email: fbUser.email,
                displayName: fbUser.displayName,
                photoUrl: fbUser.photoURL,
                provider: 'google',
              );
      if (!mounted) return;
      if (hasComplete) {
        await PreferencesService.instance.saveOnboardingComplete(true);
        if (!mounted) return;
        context.go(AppRoutes.news);
      } else {
        // Returning user but missing some preferences (or brand new
        // account) — finish the preference flow before landing on news.
        context.go(AppRoutes.onboardingPersona);
      }
    } on AuthCancelled {
      if (!mounted) return;
      setState(() => _isLoading = false);
    } on AuthFailed catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Sign-in failed. Please try again.');
    }
  }

  void _continueAsGuest() {
    if (_isLoading) return;
    context.go(AppRoutes.onboardingPersona);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 64),
              const Text(
                '🤖',
                style: TextStyle(fontSize: 72),
              )
                  .animate()
                  .scale(
                    begin: const Offset(0.6, 0.6),
                    end: const Offset(1.0, 1.0),
                    duration: 500.ms,
                    curve: Curves.elasticOut,
                  )
                  .fadeIn(duration: 400.ms),
              const SizedBox(height: 16),
              const Text(
                'Welcome to AIScroll',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
              const SizedBox(height: 6),
              const Text(
                'Learn AI in seconds. Across every device.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
              const Spacer(),
              AuthButton(
                onPressed: _isLoading
                    ? null
                    : () => context.go(AppRoutes.onboardingRegister),
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textPrimary,
                child: const Text(
                  'Create account',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ).animate().fadeIn(delay: 400.ms, duration: 350.ms),
              const SizedBox(height: 12),
              AuthButton(
                onPressed: _isLoading
                    ? null
                    : () => context.go(AppRoutes.onboardingLogin),
                backgroundColor: AppColors.inkSurface,
                foregroundColor: AppColors.textPrimary,
                child: const Text(
                  'I already have an account',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ).animate().fadeIn(delay: 450.ms, duration: 350.ms),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: AppColors.inkSurface2.withValues(alpha: 0.6),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: AppColors.inkSurface2.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 500.ms, duration: 350.ms),
              const SizedBox(height: 20),
              AuthButton(
                onPressed: _isLoading ? null : _continueWithGoogle,
                backgroundColor: Colors.white,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.googleBlue,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            'G',
                            style: TextStyle(
                              color: AppColors.googleBlue,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Continue with Google',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ).animate().fadeIn(delay: 550.ms, duration: 350.ms),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _isLoading ? null : _continueAsGuest,
                  child: const Text(
                    'Continue without an account',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 600.ms, duration: 350.ms),
              const SizedBox(height: 16),
              Text(
                'By continuing you agree to our Terms & Privacy Policy',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
