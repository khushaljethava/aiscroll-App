import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/onboarding_provider.dart';

class KnowledgeLevelScreen extends ConsumerWidget {
  const KnowledgeLevelScreen({super.key});

  static const _labels = ['Nothing', 'A Little', 'Quite a Bit', 'A Lot'];
  static const _emojis = ['🤷', '🌱', '💡', '🧠'];
  static const _descriptions = [
    "That's perfectly fine — we'll start from scratch.",
    "You have some ideas. We'll build on that.",
    "You know the basics. Time to go deeper.",
    "You're already ahead. Let's sharpen your edge.",
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(
      onboardingProvider.select((s) => s.knowledgeLevel),
    );
    final stepIndex = level.round().clamp(0, 3);

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
                'What do you know\nabout AI?',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(
                    begin: -0.2,
                    end: 0,
                    duration: 400.ms,
                    curve: Curves.easeOut,
                  ),
              const SizedBox(height: 8),
              const Text(
                'Be honest — we tailor your feed accordingly',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
              const SizedBox(height: 56),
              // Level display
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Column(
                    key: ValueKey(stepIndex),
                    children: [
                      Text(
                        _emojis[stepIndex],
                        style: const TextStyle(fontSize: 64),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _labels[stepIndex],
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _descriptions[stepIndex],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
              const SizedBox(height: 48),
              // Slider
              _StyledSlider(
                value: level,
                onChanged: (v) {
                  ref
                      .read(onboardingProvider.notifier)
                      .setKnowledgeLevel(v);
                },
              ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
              // Step labels
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _labels
                      .map(
                        (l) => Text(
                          l,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go(AppRoutes.onboardingTopics),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ctaAmber,
                    foregroundColor: AppColors.inkBlack,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Styled slider
// ---------------------------------------------------------------------------

class _StyledSlider extends StatelessWidget {
  const _StyledSlider({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderThemeData(
        activeTrackColor: AppColors.ctaAmber,
        inactiveTrackColor: AppColors.inkSurface2,
        thumbColor: AppColors.ctaAmber,
        overlayColor: AppColors.ctaAmber.withValues(alpha: 0.15),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
        trackHeight: 6,
      ),
      child: Slider(
        value: value,
        min: 0,
        max: 3,
        divisions: 3,
        onChanged: onChanged,
      ),
    );
  }
}
