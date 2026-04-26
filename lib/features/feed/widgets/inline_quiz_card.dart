import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/feedback_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/card_model.dart';

/// Full-screen inline quiz page used between learning cards in the Learn
/// PageView. Replaces the older full-screen [QuizCardWidget] that also
/// jumped pages on answer — the new variant simply shows feedback and lets
/// the user swipe to the next card themselves.
class InlineQuizCard extends ConsumerStatefulWidget {
  const InlineQuizCard({
    super.key,
    required this.question,
    required this.onAnswer,
    required this.onNext,
  });

  final QuizQuestion question;

  /// `(correct, parentCardId)`. The parent id lets the consumer route the
  /// rating into spaced repetition for the underlying concept card.
  final void Function(bool correct, String parentCardId) onAnswer;

  /// Called when the user taps "Next" after answering. The parent decides
  /// how to advance the [PageView] (usually `PageController.nextPage`).
  final VoidCallback onNext;

  @override
  ConsumerState<InlineQuizCard> createState() => _InlineQuizCardState();
}

class _InlineQuizCardState extends ConsumerState<InlineQuizCard> {
  int? _selectedIndex;
  bool _answered = false;

  bool get _isCorrect =>
      _answered && _selectedIndex == widget.question.correctIndex;

  void _select(int index) {
    if (_answered) return;
    FeedbackService.selection(ref);
    setState(() {
      _selectedIndex = index;
      _answered = true;
    });
    widget.onAnswer(
      widget.question.isCorrect(index),
      widget.question.parentCardId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.inkSurface,
          borderRadius: AppRadius.card,
          border: Border.all(
            color: AppColors.ctaAmber.withValues(alpha: 0.6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 3, color: AppColors.ctaAmber),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt_rounded,
                          size: 18, color: AppColors.ctaAmber),
                      const SizedBox(width: 6),
                      Text(
                        'Quick Quiz',
                        style: tt.labelLarge?.copyWith(
                          color: AppColors.ctaAmber,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: widget.onNext,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textMutedOnInk,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.sm,
                  AppSpacing.xl,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.question.question,
                      style: tt.headlineSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    for (var i = 0;
                        i < widget.question.options.length;
                        i++)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppSpacing.sm,
                        ),
                        child: _Option(
                          label: widget.question.options[i],
                          index: i,
                          selectedIndex: _selectedIndex,
                          correctIndex: widget.question.correctIndex,
                          answered: _answered,
                          onTap: () => _select(i),
                        ),
                      ),
                    if (_answered) ...[
                      const SizedBox(height: AppSpacing.md),
                      _Feedback(
                        isCorrect: _isCorrect,
                        explanation: widget.question.explanation,
                        xpReward: widget.question.xpReward,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_answered)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.sm,
                  AppSpacing.xl,
                  AppSpacing.md,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: widget.onNext,
                    icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                    label: const Text('Next card'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.index,
    required this.selectedIndex,
    required this.correctIndex,
    required this.answered,
    required this.onTap,
  });

  final String label;
  final int index;
  final int? selectedIndex;
  final int correctIndex;
  final bool answered;
  final VoidCallback onTap;

  Color get _borderColor {
    if (!answered) return AppColors.inkHairline;
    if (index == correctIndex) return AppColors.beginner;
    if (index == selectedIndex) return AppColors.error;
    return AppColors.inkHairline;
  }

  Color get _bgColor {
    if (!answered) return AppColors.inkSurface2;
    if (index == correctIndex) {
      return AppColors.beginner.withValues(alpha: 0.14);
    }
    if (index == selectedIndex) {
      return AppColors.error.withValues(alpha: 0.14);
    }
    return AppColors.inkSurface2;
  }

  Color get _textColor {
    if (!answered) return AppColors.textPrimary;
    if (index == correctIndex) return AppColors.beginner;
    if (index == selectedIndex) return AppColors.error;
    return AppColors.textMutedOnInk;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: answered ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor, width: 1.3),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ),
              if (answered && index == correctIndex)
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.beginner, size: 20),
              if (answered &&
                  index == selectedIndex &&
                  index != correctIndex)
                const Icon(Icons.cancel_rounded,
                    color: AppColors.error, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({
    required this.isCorrect,
    required this.explanation,
    required this.xpReward,
  });

  final bool isCorrect;
  final String explanation;
  final int xpReward;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final color = isCorrect ? AppColors.beginner : AppColors.error;
    return Animate(
      effects: [
        FadeEffect(duration: 220.ms),
        SlideEffect(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
          duration: 220.ms,
          curve: Curves.easeOut,
        ),
      ],
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(color: color, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCorrect ? 'Correct! +$xpReward XP' : 'Not quite',
              style: tt.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              explanation,
              style: tt.bodySmall?.copyWith(
                color: AppColors.textMutedOnInk,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
