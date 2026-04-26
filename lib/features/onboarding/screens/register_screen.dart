import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/user_provider.dart';
import '../../../data/remote/auth_service.dart';
import '../../../data/remote/firestore_service.dart';
import '../widgets/auth_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String? _validateName(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Name is required';
    if (value.length < 2) return 'Name is too short';
    return null;
  }

  String? _validateEmail(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Email is required';
    final ok = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
    if (!ok) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'At least 6 characters';
    return null;
  }

  String? _validateConfirm(String? v) {
    if (v == null || v.isEmpty) return 'Please confirm your password';
    if (v != _passwordCtrl.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      final auth = ref.read(authServiceProvider);
      final fbUser = await auth.registerWithEmailPassword(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
        displayName: _nameCtrl.text,
      );
      // Brand-new account: stamp local identity, then create the Firestore
      // doc seeded with whatever local guest progress exists.
      await ref.read(userProvider.notifier).signInWithFirebaseUser(
            firebaseUid: fbUser.uid,
            email: fbUser.email,
            displayName: _nameCtrl.text.trim(),
            photoUrl: fbUser.photoURL,
            provider: 'password',
          );
      // Initial profile push — uses merge so a race with the debounced
      // write is harmless.
      await ref
          .read(firestoreServiceProvider)
          .createInitialProfile(ref.read(userProvider));
      if (!mounted) return;
      context.go(AppRoutes.onboardingPersona);
    } on AuthFailed catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Could not create account. Please try again.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go(AppRoutes.onboardingWelcome),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Create your account',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ).animate().fadeIn(duration: 400.ms),
                const SizedBox(height: 6),
                const Text(
                  'Sync your progress across every device.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ).animate().fadeIn(delay: 80.ms, duration: 400.ms),
                const SizedBox(height: 28),
                _LabeledField(
                  label: 'Name',
                  child: TextFormField(
                    controller: _nameCtrl,
                    enabled: !_isLoading,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.name],
                    textInputAction: TextInputAction.next,
                    validator: _validateName,
                    decoration: _inputDecoration(hint: 'Your name'),
                  ),
                ).animate().fadeIn(delay: 150.ms, duration: 350.ms),
                const SizedBox(height: 14),
                _LabeledField(
                  label: 'Email',
                  child: TextFormField(
                    controller: _emailCtrl,
                    enabled: !_isLoading,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    validator: _validateEmail,
                    decoration: _inputDecoration(hint: 'you@example.com'),
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 350.ms),
                const SizedBox(height: 14),
                _LabeledField(
                  label: 'Password',
                  child: TextFormField(
                    controller: _passwordCtrl,
                    enabled: !_isLoading,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.newPassword],
                    textInputAction: TextInputAction.next,
                    validator: _validatePassword,
                    decoration: _inputDecoration(
                      hint: 'At least 6 characters',
                      suffix: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 250.ms, duration: 350.ms),
                const SizedBox(height: 14),
                _LabeledField(
                  label: 'Confirm password',
                  child: TextFormField(
                    controller: _confirmCtrl,
                    enabled: !_isLoading,
                    obscureText: _obscureConfirm,
                    textInputAction: TextInputAction.done,
                    validator: _validateConfirm,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: _inputDecoration(
                      hint: 'Re-enter password',
                      suffix: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 20,
                        ),
                        onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 300.ms, duration: 350.ms),
                const SizedBox(height: 28),
                AuthButton(
                  onPressed: _isLoading ? null : _submit,
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textPrimary,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Create account',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ).animate().fadeIn(delay: 400.ms, duration: 350.ms),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => context.go(AppRoutes.onboardingLogin),
                    child: const Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Already have an account? ',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          TextSpan(
                            text: 'Sign in',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 450.ms, duration: 350.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration({required String hint, Widget? suffix}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
    filled: true,
    fillColor: AppColors.inkSurface,
    suffixIcon: suffix,
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide:
          BorderSide(color: AppColors.primary.withValues(alpha: 0.7), width: 1.4),
    ),
  );
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ),
        child,
      ],
    );
  }
}
