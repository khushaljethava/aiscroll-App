import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_option_card.dart';
import '../providers/onboarding_provider.dart';

class PersonaScreen extends ConsumerWidget {
  const PersonaScreen({super.key});

  static const _personas = [
    _PersonaOption(
      id: 'student',
      title: 'Student',
      subtitle: "I'm studying and want to build AI skills",
    ),
    _PersonaOption(
      id: 'professional',
      title: 'Professional',
      subtitle: 'I use AI at work or want to stay relevant',
    ),
    _PersonaOption(
      id: 'curious',
      title: 'Just curious',
      subtitle: 'I just want to understand AI basics',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
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
              Text(
                'Who are you?',
                style: tt.headlineSmall,
              ).animate().fadeIn(duration: 400.ms).slideY(
                    begin: -0.2,
                    end: 0,
                    duration: 400.ms,
                    curve: Curves.easeOut,
                  ),
              const SizedBox(height: 8),
              Text(
                'Personalize your learning path',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
              const SizedBox(height: 40),
              ...List.generate(_personas.length, (i) {
                final option = _personas[i];
                final isSelected = selectedPersona == option.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: AppOptionCard(
                    title: option.title,
                    subtitle: option.subtitle,
                    selected: isSelected,
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
// Data model
// ---------------------------------------------------------------------------

class _PersonaOption {
  const _PersonaOption({
    required this.id,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final String title;
  final String subtitle;
}
