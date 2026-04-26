import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/feedback/feedback_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/card_model.dart';

class QuizCardWidget extends ConsumerStatefulWidget {
  const QuizCardWidget({
    super.key,
    required this.question,
    required this.onNext,
    required this.onAnswer,
  });

  final QuizQuestion question;
  final VoidCallback onNext;

  /// `(correct, parentCardId)` — parentCardId lets the consumer route the
  /// rating into spaced-repetition for the underlying concept card.
  final void Function(bool correct, String parentCardId) onAnswer;

  @override
  ConsumerState<QuizCardWidget> createState() => _QuizCardWidgetState();
}

class _QuizCardWidgetState extends ConsumerState<QuizCardWidget> {
  int? _selectedIndex;
  bool _answered = false;

  bool get _isCorrect =>
      _answered && _selectedIndex == widget.question.correctIndex;

  void _selectOption(int index) {
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

  void _skip() {
    if (!_answered) {
      setState(() => _answered = true);
      widget.onAnswer(false, widget.question.parentCardId);
    }
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E1B4B), Color(0xFF13113A)],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            _QuizAccentBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _QuizHeader(onSkip: _skip),
                    const SizedBox(height: 20),
                    _QuestionText(question: widget.question.question),
                    const SizedBox(height: 24),
                    ..._buildOptions(),
                    if (_answered) ...[
                      const SizedBox(height: 20),
                      _AnswerFeedback(
                        isCorrect: _isCorrect,
                        explanation: widget.question.explanation,
                        xpReward: widget.question.xpReward,
                      ),
                      const SizedBox(height: 20),
                      _NextButton(onNext: widget.onNext),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildOptions() {
    return List.generate(widget.question.options.length, (i) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _OptionButton(
          label: widget.question.options[i],
          index: i,
          selectedIndex: _selectedIndex,
          correctIndex: widget.question.correctIndex,
          answered: _answered,
          onTap: () => _selectOption(i),
        ),
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _QuizAccentBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      width: double.infinity,
      color: AppColors.warning,
    );
  }
}

class _QuizHeader extends StatelessWidget {
  const _QuizHeader({required this.onSkip});

  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Row(
          children: [
            Text('Quick Quiz', style: TextStyle(color: AppColors.warning, fontSize: 14, fontWeight: FontWeight.bold)),
            SizedBox(width: 4),
            Text('⚡', style: TextStyle(fontSize: 14)),
          ],
        ),
        GestureDetector(
          onTap: onSkip,
          child: const Text(
            'Skip',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuestionText extends StatelessWidget {
  const _QuestionText({required this.question});

  final String question;

  @override
  Widget build(BuildContext context) {
    return Text(
      question,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        height: 1.4,
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
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
    if (!answered) return AppColors.inkSurface2;
    if (index == correctIndex) return AppColors.beginner;
    if (index == selectedIndex) return AppColors.error;
    return AppColors.inkSurface2;
  }

  Color get _bgColor {
    if (!answered) return AppColors.inkSurface2.withValues(alpha: 0.3);
    if (index == correctIndex) return AppColors.beginner.withValues(alpha: 0.15);
    if (index == selectedIndex) return AppColors.error.withValues(alpha: 0.15);
    return AppColors.inkSurface2.withValues(alpha: 0.15);
  }

  Color get _textColor {
    if (!answered) return AppColors.textPrimary;
    if (index == correctIndex) return AppColors.beginner;
    if (index == selectedIndex) return AppColors.error;
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor, width: 1.5),
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
                  ),
                ),
              ),
              if (answered && index == correctIndex)
                const Icon(Icons.check_circle, color: AppColors.beginner, size: 20),
              if (answered && index == selectedIndex && index != correctIndex)
                const Icon(Icons.cancel, color: AppColors.error, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnswerFeedback extends StatelessWidget {
  const _AnswerFeedback({
    required this.isCorrect,
    required this.explanation,
    required this.xpReward,
  });

  final bool isCorrect;
  final String explanation;
  final int xpReward;

  @override
  Widget build(BuildContext context) {
    return Animate(
      effects: [
        FadeEffect(duration: 300.ms),
        SlideEffect(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
          duration: 300.ms,
          curve: Curves.easeOut,
        ),
      ],
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isCorrect
              ? AppColors.beginner.withValues(alpha: 0.12)
              : AppColors.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCorrect
                ? AppColors.beginner.withValues(alpha: 0.4)
                : AppColors.error.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCorrect ? '✓ Correct! +$xpReward XP' : '✗ Not quite',
              style: TextStyle(
                color: isCorrect ? AppColors.beginner : AppColors.error,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              explanation,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onNext,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Next Card',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 6),
            Text('→', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
