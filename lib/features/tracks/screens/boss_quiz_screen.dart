import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/xp_constants.dart';
import '../../../core/feedback/feedback_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/card_model.dart';
import '../../../data/providers/user_provider.dart';
import '../../../features/feed/providers/srs_provider.dart';
import '../../../features/feed/widgets/quiz_card_widget.dart';
import '../../../features/gamification/providers/gamification_provider.dart';
import '../providers/boss_quiz_provider.dart';

/// Multi-question boss quiz. Pass threshold 70%.
/// First-time pass awards `XPConstants.trackComplete`; replays don't.
class BossQuizScreen extends ConsumerStatefulWidget {
  const BossQuizScreen({super.key, required this.trackId});

  final String trackId;

  @override
  ConsumerState<BossQuizScreen> createState() => _BossQuizScreenState();
}

class _BossQuizScreenState extends ConsumerState<BossQuizScreen> {
  late final List<QuizQuestion> _questions;
  final List<bool> _answers = [];
  int _currentIdx = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _questions = ref.read(bossQuizPoolProvider(widget.trackId));
  }

  int get _passThreshold => (_questions.length * 0.7).ceil();
  int get _correctCount => _answers.where((a) => a).length;
  bool get _passed => _correctCount >= _passThreshold;

  Future<void> _onAnswer(bool correct, String parentCardId) async {
    _answers.add(correct);

    // Each answer feeds SRS for the parent card (same mapping as feed).
    await ref
        .read(srsProvider.notifier)
        .recordReview(parentCardId, correct ? 5 : 1);
  }

  bool _xpAwarded = false;

  Future<void> _next() async {
    if (_currentIdx + 1 >= _questions.length) {
      await _tallyResults();
      if (mounted) setState(() => _finished = true);
    } else {
      setState(() => _currentIdx += 1);
    }
  }

  Future<void> _tallyResults() async {
    if (!_passed) return;
    final awarded = await ref
        .read(userProvider.notifier)
        .awardBossQuizCompletion(widget.trackId);
    _xpAwarded = awarded;
    if (awarded) {
      ref
          .read(gamificationProvider.notifier)
          .triggerXP(XPConstants.trackComplete);
      FeedbackService.heavy(ref);
      FeedbackService.click(ref);
    } else {
      FeedbackService.medium(ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.length < kBossQuizMinimumQuestions) {
      return _NotEnoughContent(trackId: widget.trackId);
    }

    if (_finished) {
      return _BossResultScreen(
        trackId: widget.trackId,
        correctCount: _correctCount,
        total: _questions.length,
        passThreshold: _passThreshold,
        passed: _passed,
        // True when the user passed but XP was NOT awarded — i.e., a replay.
        alreadyMastered: _passed && !_xpAwarded,
        onRetry: _reset,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Boss Quiz · ${_currentIdx + 1} / ${_questions.length}',
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentIdx + 1) / _questions.length,
            backgroundColor: AppColors.inkSurface2,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 4,
          ),
        ),
      ),
      body: QuizCardWidget(
        // Key ensures state (selected option, answered flag) resets per q.
        key: ValueKey(_questions[_currentIdx].id),
        question: _questions[_currentIdx],
        onAnswer: (correct, parentCardId) =>
            _onAnswer(correct, parentCardId),
        onNext: _next,
      ),
    );
  }

  void _reset() {
    setState(() {
      _answers.clear();
      _currentIdx = 0;
      _finished = false;
      _xpAwarded = false;
    });
  }
}

// ---------------------------------------------------------------------------
// Result screen
// ---------------------------------------------------------------------------

class _BossResultScreen extends ConsumerWidget {
  const _BossResultScreen({
    required this.trackId,
    required this.correctCount,
    required this.total,
    required this.passThreshold,
    required this.passed,
    required this.alreadyMastered,
    required this.onRetry,
  });

  final String trackId;
  final int correctCount;
  final int total;
  final int passThreshold;
  final bool passed;
  final bool alreadyMastered;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                passed ? '🏆' : '💪',
                style: const TextStyle(fontSize: 72),
              ),
              const SizedBox(height: 16),
              Text(
                passed
                    ? (alreadyMastered
                        ? 'Track already mastered'
                        : 'Track mastered!')
                    : 'Not quite',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$correctCount / $total correct',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pass threshold: $passThreshold',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              if (passed && !alreadyMastered)
                _XpReward(xp: XPConstants.trackComplete),
              if (passed && alreadyMastered)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Replay for practice — no XP reward.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              if (!passed) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onRetry,
                    child: const Text('Retry'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back to track'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _XpReward extends StatelessWidget {
  const _XpReward({required this.xp});

  final int xp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.xpGold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: AppColors.xpGold.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Text(
        '+$xp XP',
        style: const TextStyle(
          color: AppColors.xpGold,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fallback — track has < 3 quizzes
// ---------------------------------------------------------------------------

class _NotEnoughContent extends StatelessWidget {
  const _NotEnoughContent({required this.trackId});

  final String trackId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Boss Quiz')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📭', style: TextStyle(fontSize: 72)),
              const SizedBox(height: 16),
              const Text(
                'Not enough quiz content yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This track needs more quiz cards before a boss quiz can be run.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to track'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
