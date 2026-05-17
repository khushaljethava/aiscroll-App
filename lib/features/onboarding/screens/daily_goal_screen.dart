import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/user_provider.dart';
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
      emoji: '⚡',
      description: 'Light daily habit, easy to maintain',
    ),
    _GoalOption(
      cards: 10,
      label: 'Balanced',
      duration: '~10 min',
      emoji: '🎯',
      description: 'Recommended for steady progress',
    ),
    _GoalOption(
      cards: 15,
      label: 'Intensive',
      duration: '~15 min',
      emoji: '🚀',
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
    context.go(AppRoutes.news);
  }

  @override
  Widget build(BuildContext context) {
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
              const Text(
                'Set your daily goal',
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
                'How many cards a day works for you?',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
              const SizedBox(height: 40),
              ...List.generate(_goals.length, (i) {
                final goal = _goals[i];
                final isSelected = selectedGoal == goal.cards;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _GoalCard(
                    goal: goal,
                    isSelected: isSelected,
                    onTap: () {
                      ref
                          .read(onboardingProvider.notifier)
                          .setDailyGoal(goal.cards);
                    },
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isFinishing ? null : _finishOnboarding,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ctaAmber,
                    foregroundColor: AppColors.inkBlack,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isFinishing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.inkBlack,
                          ),
                        )
                      : const Text(
                    'Finish',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
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
// Goal card widget
// ---------------------------------------------------------------------------

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.isSelected,
    required this.onTap,
  });

  final _GoalOption goal;
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
              ? AppColors.ctaAmber.withValues(alpha: 0.12)
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
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.ctaAmber.withValues(alpha: 0.2)
                    : AppColors.inkSurface2.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  goal.emoji,
                  style: const TextStyle(fontSize: 26),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${goal.cards} cards/day',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.ctaAmber.withValues(alpha: 0.25)
                              : AppColors.inkSurface2.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          goal.label,
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.ctaAmber
                                : AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    goal.duration,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    goal.description,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
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

class _GoalOption {
  const _GoalOption({
    required this.cards,
    required this.label,
    required this.duration,
    required this.emoji,
    required this.description,
  });

  final int cards;
  final String label;
  final String duration;
  final String emoji;
  final String description;
}
