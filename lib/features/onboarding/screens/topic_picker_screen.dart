import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/onboarding_provider.dart';

class TopicPickerScreen extends ConsumerWidget {
  const TopicPickerScreen({super.key});

  static const _topics = [
    _TopicOption(id: 'ai_basics', label: 'AI Basics', emoji: '🤖'),
    _TopicOption(id: 'machine_learning', label: 'Machine Learning', emoji: '🧠'),
    _TopicOption(id: 'chatgpt_llms', label: 'ChatGPT & LLMs', emoji: '💬'),
    _TopicOption(
        id: 'computer_vision', label: 'Computer Vision', emoji: '👁️'),
    _TopicOption(
        id: 'generative_ai', label: 'Generative AI', emoji: '🎨'),
    _TopicOption(id: 'ai_ethics', label: 'AI Ethics', emoji: '🔐'),
    _TopicOption(id: 'data_science', label: 'Data Science', emoji: '📊'),
    _TopicOption(id: 'ai_business', label: 'AI in Business', emoji: '⚙️'),
    _TopicOption(
        id: 'prompt_engineering', label: 'Prompt Engineering', emoji: '🧑‍💻'),
    _TopicOption(id: 'future_ai', label: 'Future of AI', emoji: '🚀'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTopics = ref.watch(
      onboardingProvider.select((s) => s.selectedTopics),
    );
    final hasEnough = selectedTopics.length >= 3;

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
                'Pick topics you\ncare about',
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
              Text(
                hasEnough
                    ? '${selectedTopics.length} selected — nice!'
                    : 'Choose at least 3',
                style: TextStyle(
                  color: hasEnough
                      ? AppColors.accent
                      : AppColors.textSecondary,
                  fontSize: 15,
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
              const SizedBox(height: 32),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: List.generate(_topics.length, (i) {
                      final topic = _topics[i];
                      final isSelected = selectedTopics.contains(topic.id);
                      return _TopicChip(
                        topic: topic,
                        isSelected: isSelected,
                        onTap: () {
                          ref
                              .read(onboardingProvider.notifier)
                              .toggleTopic(topic.id);
                        },
                      )
                          .animate()
                          .fadeIn(
                            delay: Duration(milliseconds: 150 + i * 50),
                            duration: 350.ms,
                          )
                          .scale(
                            begin: const Offset(0.8, 0.8),
                            end: const Offset(1.0, 1.0),
                            delay: Duration(milliseconds: 150 + i * 50),
                            duration: 350.ms,
                            curve: Curves.easeOut,
                          );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      hasEnough ? () => context.go(AppRoutes.onboardingGoal) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ctaAmber,
                    disabledBackgroundColor:
                        AppColors.inkSurface2.withValues(alpha: 0.5),
                    foregroundColor: AppColors.inkBlack,
                    disabledForegroundColor:
                        AppColors.textSecondary,
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
              ).animate().fadeIn(delay: 700.ms, duration: 400.ms),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Topic chip
// ---------------------------------------------------------------------------

class _TopicChip extends StatelessWidget {
  const _TopicChip({
    required this.topic,
    required this.isSelected,
    required this.onTap,
  });

  final _TopicOption topic;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.ctaAmber : AppColors.inkSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? AppColors.ctaAmber
                : AppColors.inkSurface2.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(topic.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(
              topic.label,
              style: TextStyle(
                color: isSelected
                    ? AppColors.inkBlack
                    : AppColors.textSecondary,
                fontSize: 14,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
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

class _TopicOption {
  const _TopicOption({
    required this.id,
    required this.label,
    required this.emoji,
  });

  final String id;
  final String label;
  final String emoji;
}
