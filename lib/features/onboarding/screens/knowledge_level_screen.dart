import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_button.dart';
import '../providers/onboarding_provider.dart';

class KnowledgeLevelScreen extends ConsumerWidget {
  const KnowledgeLevelScreen({super.key});

  static const _labels = ['Nothing', 'A Little', 'Quite a Bit', 'A Lot'];
  static const _descriptions = [
    "That's perfectly fine — we'll start from scratch.",
    "You have some ideas. We'll build on that.",
    "You know the basics. Time to go deeper.",
    "You're already ahead. Let's sharpen your edge.",
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
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
              Text(
                'What do you know\nabout AI?',
                style: tt.headlineSmall?.copyWith(height: 1.3),
              ).animate().fadeIn(duration: 400.ms).slideY(
                    begin: -0.2,
                    end: 0,
                    duration: 400.ms,
                    curve: Curves.easeOut,
                  ),
              const SizedBox(height: 8),
              Text(
                'Be honest — we tailor your feed accordingly',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
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
                        _labels[stepIndex],
                        textAlign: TextAlign.center,
                        style: tt.displaySmall?.copyWith(color: cs.primary),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _descriptions[stepIndex],
                        textAlign: TextAlign.center,
                        style:
                            tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
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
                          style: tt.labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      )
                      .toList(),
                ),
              ),
              const Spacer(),
              AppButton(
                label: 'Continue',
                onPressed: () => context.go(AppRoutes.onboardingTopics),
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
    final cs = Theme.of(context).colorScheme;
    return SliderTheme(
      data: SliderThemeData(
        activeTrackColor: cs.primary,
        inactiveTrackColor: cs.surfaceContainerHighest,
        thumbColor: cs.primary,
        overlayColor: cs.primary.withValues(alpha: 0.15),
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
