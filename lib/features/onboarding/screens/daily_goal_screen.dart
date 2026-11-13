import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../data/providers/user_provider.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_option_card.dart';
import '../providers/onboarding_provider.dart';

class DailyGoalScreen extends ConsumerStatefulWidget {
  const DailyGoalScreen({super.key});

  @override
  ConsumerState<DailyGoalScreen> createState() => _DailyGoalScreenState();
}

class _DailyGoalScreenState extends ConsumerState<DailyGoalScreen> {
  bool _isFinishing = false;

  static const _goals = [
    _GoalOption(
      cards: 5,
      label: 'Quick',
      duration: '~5 min',
      description: 'Light daily habit, easy to maintain',
    ),
    _GoalOption(
      cards: 10,
      label: 'Balanced',
      duration: '~10 min',
      description: 'Recommended for steady progress',
    ),
    _GoalOption(
      cards: 15,
      label: 'Intensive',
      duration: '~15 min',
      description: 'For the serious learner',
    ),
  ];

  Future<void> _finishOnboarding() async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);
    final user = ref.read(userProvider);
    await ref.read(onboardingProvider.notifier).completeOnboarding(
          stayGuest: user.isGuest,
        );
    if (!mounted) return;
    context.go(AppRoutes.onboardingDone);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final selectedGoal = ref.watch(
      onboardingProvider.select((s) => s.dailyGoal),
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
                'Set your daily goal',
                style: tt.headlineSmall,
              ).animate().fadeIn(duration: 400.ms).slideY(
                    begin: -0.2,
                    end: 0,
                    duration: 400.ms,
                    curve: Curves.easeOut,
                  ),
              const SizedBox(height: 8),
              Text(
                'How many cards a day works for you?',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
              const SizedBox(height: 40),
              ...List.generate(_goals.length, (i) {
                final goal = _goals[i];
                final isSelected = selectedGoal == goal.cards;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: AppOptionCard(
                    selected: isSelected,
                    onTap: () {
                      ref
                          .read(onboardingProvider.notifier)
                          .setDailyGoal(goal.cards);
                    },
                    leading: SizedBox(
                      width: 44,
                      child: Text(
                        '${goal.cards}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                    ),
                    title: '${goal.cards} cards/day',
                    subtitle: '${goal.duration} · ${goal.description}',
                    trailing: AppBadge(
                      label: goal.label,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(
                      delay: Duration(milliseconds: 200 + i * 100),
                      duration: 400.ms,
                    )
                    .slideX(
                      begin: 0.2,
                      end: 0,
                      delay: Duration(milliseconds: 200 + i * 100),
                      duration: 400.ms,
                      curve: Curves.easeOut,
                    );
              }),
              const Spacer(),
              AppButton(
                label: 'Finish',
                loading: _isFinishing,
                onPressed: _isFinishing ? null : _finishOnboarding,
              ).animate().fadeIn(delay: 600.ms, duration: 400.ms),
              const SizedBox(height: 24),
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

class _GoalOption {
  const _GoalOption({
    required this.cards,
    required this.label,
    required this.duration,
    required this.description,
  });

  final int cards;
  final String label;
  final String duration;
  final String description;
}
