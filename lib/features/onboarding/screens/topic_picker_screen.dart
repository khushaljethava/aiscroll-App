import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_semantic_colors.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_tag_chip.dart';
import '../providers/onboarding_provider.dart';

class TopicPickerScreen extends ConsumerWidget {
  const TopicPickerScreen({super.key});

  static const _topics = [
    _TopicOption(id: 'ai_basics', label: 'AI Basics'),
    _TopicOption(id: 'machine_learning', label: 'Machine Learning'),
    _TopicOption(id: 'chatgpt_llms', label: 'ChatGPT & LLMs'),
    _TopicOption(id: 'computer_vision', label: 'Computer Vision'),
    _TopicOption(id: 'generative_ai', label: 'Generative AI'),
    _TopicOption(id: 'ai_ethics', label: 'AI Ethics'),
    _TopicOption(id: 'data_science', label: 'Data Science'),
    _TopicOption(id: 'ai_business', label: 'AI in Business'),
    _TopicOption(id: 'prompt_engineering', label: 'Prompt Engineering'),
    _TopicOption(id: 'future_ai', label: 'Future of AI'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sem = context.sem;
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
              Text(
                'Pick topics you\ncare about',
                style: tt.headlineSmall?.copyWith(height: 1.3),
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
                style: tt.bodyMedium?.copyWith(
                  color: hasEnough ? sem.success : cs.onSurfaceVariant,
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
                      return AppTagChip(
                        label: topic.label,
                        accent: cs.primary,
                        emphasised: isSelected,
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
              AppButton(
                label: 'Continue',
                onPressed: hasEnough
                    ? () => context.go(AppRoutes.onboardingGoal)
                    : null,
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
// Data model
// ---------------------------------------------------------------------------

class _TopicOption {
  const _TopicOption({required this.id, required this.label});
  final String id;
  final String label;
}
