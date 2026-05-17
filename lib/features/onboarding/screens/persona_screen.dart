import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/onboarding_provider.dart';

class PersonaScreen extends ConsumerWidget {
  const PersonaScreen({super.key});

  static const _personas = [
    _PersonaOption(
      id: 'student',
      emoji: '👨‍🎓',
      title: 'Student',
      subtitle: "I'm studying and want to build AI skills",
    ),
    _PersonaOption(
      id: 'professional',
      emoji: '👩‍💼',
      title: 'Professional',
      subtitle: 'I use AI at work or want to stay relevant',
    ),
    _PersonaOption(
      id: 'curious',
      emoji: '🙃',
      title: 'Just Curious',
      subtitle: 'I just want to understand AI basics',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPersona = ref.watch(
      onboardingProvider.select((s) => s.persona),
    );

    return Scaffold(
      // Theme drives scaffold colour.
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              const Text(
                'Who are you?',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(
                    begin: -0.2,
                    end: 0,
                    duration: 400.ms,
                    curve: Curves.easeOut,
                  ),
              const SizedBox(height: 8),
              const Text(
                'Personalize your learning path',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
              const SizedBox(height: 40),
              ...List.generate(_personas.length, (i) {
                final option = _personas[i];
                final isSelected = selectedPersona == option.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _PersonaCard(
                    option: option,
                    isSelected: isSelected,
                    onTap: () {
                      ref
                          .read(onboardingProvider.notifier)
                          .setPersona(option.id);
                      context.go(AppRoutes.onboardingLevel);
                    },
                  ),
                ).animate().fadeIn(
                      delay: Duration(milliseconds: 200 + i * 100),
                      duration: 400.ms,
                    ).slideX(
                      begin: 0.2,
                      end: 0,
                      delay: Duration(milliseconds: 200 + i * 100),
                      duration: 400.ms,
                      curve: Curves.easeOut,
                    );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Persona card widget
// ---------------------------------------------------------------------------

class _PersonaCard extends StatelessWidget {
  const _PersonaCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final _PersonaOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.ctaAmber.withValues(alpha: 0.10)
              : AppColors.inkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.ctaAmber
                : AppColors.inkSurface2.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(
              option.emoji,
              style: const TextStyle(fontSize: 40),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.ctaAmber,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

class _PersonaOption {
  const _PersonaOption({
    required this.id,
    required this.emoji,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final String emoji;
  final String title;
  final String subtitle;
}
