import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../providers/onboarding_provider.dart';

/// Editorial payoff shown after the funnel: confirms the picks and routes to
/// News. [OnboardingNotifier.completeOnboarding] has already run on the
/// daily-goal screen, so this screen only summarizes state and forwards.
class OnboardingDoneScreen extends ConsumerWidget {
  const OnboardingDoneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sem = context.sem;
    final s = ref.watch(onboardingProvider);

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              Text(value,
                  style:
                      tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.editorialGutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                "You're all set",
                textAlign: TextAlign.center,
                style: tt.displaySmall?.copyWith(color: cs.primary),
              ).animate().fadeIn(duration: 400.ms).slideY(
                  begin: 0.15, end: 0, duration: 400.ms, curve: Curves.easeOut),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Your feed is tuned to you. Here’s the plan:',
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
              const SizedBox(height: AppSpacing.xxl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: sem.sectionSurface,
                  borderRadius: AppRadius.card,
                  border: Border.all(color: sem.hairline),
                ),
                child: Column(
                  children: [
                    row('Knowledge level',
                        knowledgeLabelFromValue(s.knowledgeLevel)),
                    row('Topics', '${s.selectedTopics.length} chosen'),
                    row('Daily goal', '${s.dailyGoal} cards/day'),
                  ],
                ),
              ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
              const Spacer(),
              AppButton(
                label: 'Start learning',
                onPressed: () => context.go(AppRoutes.news),
              ).animate().fadeIn(delay: 450.ms, duration: 400.ms),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}
