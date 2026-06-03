import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/brand.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_semantic_colors.dart';
import '../../../data/local/preferences_service.dart';
import '../../../shared/widgets/brand_wordmark.dart';
import '../../../data/providers/analytics_provider.dart';
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
      // ignore: discarded_futures
      ref.read(analyticsServiceProvider).logLogin(method: 'google');
      // ignore: discarded_futures
      ref.read(analyticsServiceProvider).setUserId(fbUser.uid);
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sem = context.sem;
    // Google brand blue — required exact value per Google's brand guidelines.
    const googleBlue = Color(0xFF4285F4);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 64),
              const BrandWordmark()
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.1, end: 0, duration: 400.ms),
              const SizedBox(height: 6),
              Text(
                Brand.tagline,
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
              const Spacer(),
              AuthButton(
                onPressed: _isLoading
                    ? null
                    : () => context.go(AppRoutes.onboardingRegister),
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                child: Text(
                  'Create account',
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ).animate().fadeIn(delay: 400.ms, duration: 350.ms),
              const SizedBox(height: 12),
              AuthButton(
                onPressed: _isLoading
                    ? null
                    : () => context.go(AppRoutes.onboardingLogin),
                backgroundColor: sem.sectionSurface,
                foregroundColor: cs.onSurface,
                child: Text(
                  'I already have an account',
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ).animate().fadeIn(delay: 450.ms, duration: 350.ms),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
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
                          color: googleBlue,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'G',
                            style: tt.titleLarge?.copyWith(
                              color: googleBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Continue with Google',
                            style: tt.titleMedium?.copyWith(
                              color: Colors.black87,
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
                  child: Text(
                    'Continue without an account',
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 600.ms, duration: 350.ms),
              const SizedBox(height: 16),
              Text(
                'By continuing you agree to our Terms & Privacy Policy',
                textAlign: TextAlign.center,
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
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
