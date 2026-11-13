import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/xp_constants.dart';
import '../../../core/feedback/feedback_service.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/card_model.dart';
import '../../../data/models/quest_model.dart';
import '../../../data/models/track_model.dart';
import '../../../data/providers/cards_provider.dart';
import '../../../data/providers/user_provider.dart';
import '../../../data/remote/ads_service.dart';
import '../../../data/remote/consent_service.dart';
import '../../../features/ads/widgets/native_ad_card.dart';
import '../../../features/gamification/providers/gamification_provider.dart';
import '../../../features/gamification/providers/quests_provider.dart';
import '../../../features/gamification/widgets/xp_popup_widget.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../providers/feed_provider.dart';
import '../providers/srs_provider.dart';
import '../widgets/inline_quiz_card.dart';
import '../widgets/zine_card.dart';

/// Sentinel marking "show a native ad here" in the learn track item list.
class _LearnAdSlot {
  const _LearnAdSlot();
}

const _learnAdSlot = _LearnAdSlot();

/// Full-screen vertical PageView scoped to a single [LearningTrack].
///
/// Renders the track's concept cards, interleaves the track's quiz
/// questions every [_quizCadence] cards, and caps the scroll with a
/// completion page that offers the boss quiz.
class TrackLearnScreen extends ConsumerStatefulWidget {
  const TrackLearnScreen({super.key, required this.trackId});

  final String trackId;

  @override
  ConsumerState<TrackLearnScreen> createState() =>
      _TrackLearnScreenState();
}

class _TrackLearnScreenState extends ConsumerState<TrackLearnScreen> {
  static const _quizCadence = 4;

  late final PageController _pageController;
  Timer? _dwellTimer;
  String? _dwellCardId;
  // Initialised in [initState] from the saved resume position. Falls back
  // to 0 when there's no saved entry or the saved card has since been
  // removed from the manifest.
  int _currentIndex = 0;

  /// Notifier cache — Riverpod forbids `ref` access in `dispose` and async
  /// callbacks can race with disposal. These are container-scoped StateNotifiers
  /// that outlive the route, so holding references is safe.
  late final FeedNotifier _feedNotifier;
  late final UserNotifier _userNotifier;
  late final GamificationNotifier _gamificationNotifier;
  late final QuestsNotifier _questsNotifier;
  late final SRSNotifier _srsNotifier;

  /// Memoized page list (concept cards interleaved with track-scoped quizzes).
  /// Computed once in [initState] so rebuilds don't recreate it every frame.
  List<dynamic> _items = const [];

  @override
  void initState() {
    super.initState();
    _feedNotifier = ref.read(feedProvider.notifier);
    _userNotifier = ref.read(userProvider.notifier);
    _gamificationNotifier = ref.read(gamificationProvider.notifier);
    _questsNotifier = ref.read(questsProvider.notifier);
    _srsNotifier = ref.read(srsProvider.notifier);

    _items = _computeItems();

    // Resume at the last card the user was on for this track. -1 from
    // indexWhere when the saved card no longer exists; clamp to 0.
    final lastCardId =
        ref.read(userProvider).lastCardByTrack[widget.trackId];
    final resumeIdx = lastCardId == null
        ? 0
        : _items.indexWhere(
            (it) => it is LearningCard && it.id == lastCardId,
          );
    _currentIndex = resumeIdx > 0 ? resumeIdx : 0;
    _pageController = PageController(initialPage: _currentIndex);

    // Defer to the next frame so we don't mutate FeedNotifier (a Riverpod
    // provider) during the initState/build phase, which Riverpod forbids.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _primeDwellForCurrent();
    });
  }

  @override
  void dispose() {
    _dwellTimer?.cancel();
    // Close out any in-flight dwell so FeedNotifier.dwellTimerActive doesn't
    // leak entries. Uses the cached notifier — ref is unavailable here.
    // Deferred to a microtask: Riverpod forbids state mutation during
    // dispose, and endDwell calls `state = ...`. The notifier is a
    // long-lived StateNotifier so the captured reference stays valid.
    final dwellId = _dwellCardId;
    if (dwellId != null) {
      final notifier = _feedNotifier;
      Future.microtask(() => notifier.endDwell(dwellId));
    }
    _pageController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Item composition — concepts interleaved with track-scoped quizzes.
  // ---------------------------------------------------------------------------

  List<dynamic> _computeItems() {
    final cards = ref.read(trackCardsProvider(widget.trackId));
    final allQuizzes = ref.read(allQuizzesProvider);
    final trackCardIds = cards.map((c) => c.id).toSet();
    final trackQuizzes = allQuizzes
        .where((q) => trackCardIds.contains(q.parentCardId))
        .toList();

    final items = <dynamic>[];
    var quizIdx = 0;
    var cardsSinceAd = 0;
    var concretes = 0; // cards + quizzes shown so far (for warmup)
    for (var i = 0; i < cards.length; i++) {
      items.add(cards[i]);
      cardsSinceAd++;
      concretes++;
      final isCadenceHit = (i + 1) % _quizCadence == 0;
      if (isCadenceHit && quizIdx < trackQuizzes.length) {
        items.add(trackQuizzes[quizIdx++]);
        concretes++;
      }
      // Drop a native ad slot every AdConfig.adEvery real items, after a
      // short warmup. Aligns with the news feed's cadence so ad density
      // is consistent across surfaces.
      if (concretes > AdConfig.adWarmup &&
          cardsSinceAd >= AdConfig.adEvery) {
        items.add(_learnAdSlot);
        cardsSinceAd = 0;
      }
    }
    // Tail-append any quizzes still outstanding so we don't lose questions
    // for short tracks where the cadence can't consume all of them.
    while (quizIdx < trackQuizzes.length) {
      items.add(trackQuizzes[quizIdx++]);
    }
    return items;
  }

  // ---------------------------------------------------------------------------
  // Dwell + XP
  // ---------------------------------------------------------------------------

  void _primeDwellForCurrent() {
    if (_items.isEmpty) return;
    // Use _currentIndex so we prime dwell on the resumed card, not just
    // the first one. Bound-check in case the saved index ran off the end.
    final idx = _currentIndex.clamp(0, _items.length - 1);
    final item = _items[idx];
    if (item is LearningCard) {
      _startDwell(item);
      // Also seed the resume position so a fresh open + immediate quit
      // still records something to come back to.
      // ignore: discarded_futures
      _userNotifier.setLastCardForTrack(widget.trackId, item.id);
    }
  }

  // Time on a card before it counts as "read" for XP / progress purposes.
  // Tightened from 15 s → 5 s so swipe-through learners actually accrue XP.
  static const _dwellThreshold = Duration(seconds: 5);

  void _startDwell(LearningCard card) {
    _dwellCardId = card.id;
    _feedNotifier.startDwell(card.id);
    _dwellTimer?.cancel();
    _dwellTimer = Timer(_dwellThreshold, () => _awardReadXP(card));
  }

  Future<void> _awardReadXP(LearningCard card) async {
    // All notifiers are cached fields, so this is safe even if the widget
    // was disposed during the 15 s dwell.
    final counted = await _userNotifier.markCardRead(card.id);
    if (!counted) return;
    // Track-grid progress and the boss-quiz unlock both read off
    // `learnedCardIds`. Without this call, those counters never advance
    // because `markCardRead` only writes the *daily* `readCardIdsToday`
    // (which resets at midnight). Idempotent — safe even if the user
    // also taps the explicit "Mark learned" button on the detail view.
    final newlyLearned = await _userNotifier.markCardLearned(card.id);
    // Track reading is how most users "learn" a card, so it must also feed
    // the learn-new quest — the detail screen's button rarely fires first.
    if (newlyLearned) {
      await _questsNotifier.recordEvent(QuestType.learnNew);
      // Read XP only on a card's first read — re-reading learned cards
      // each day was free XP. Quest + SRS review below still count.
      await _userNotifier.addXP(
        XPConstants.readCard,
        source: 'read_card',
      );
      _gamificationNotifier.triggerXP(XPConstants.readCard);
    }
    await _questsNotifier.recordEvent(QuestType.readCards);
    await _srsNotifier.recordReview(card.id, 3);
  }

  // ---------------------------------------------------------------------------
  // Page change
  // ---------------------------------------------------------------------------

  void _onPageChanged(int index, List<dynamic> items) {
    FeedbackService.selection(ref);
    if (_dwellCardId != null) {
      _feedNotifier.endDwell(_dwellCardId!);
      _dwellTimer?.cancel();
      _dwellCardId = null;
    }
    setState(() => _currentIndex = index);

    // No dwell on the completion sentinel (index == items.length).
    if (index < 0 || index >= items.length) return;
    final item = items[index];
    if (item is LearningCard) {
      _startDwell(item);
      // Persist resume position. Notifier short-circuits same-value writes
      // so this is cheap on rapid swipes.
      // ignore: discarded_futures
      _userNotifier.setLastCardForTrack(widget.trackId, item.id);
    }
  }

  // ---------------------------------------------------------------------------
  // Card actions
  // ---------------------------------------------------------------------------

  void _openDetail(LearningCard card) {
    context.push(AppRoutes.learnCard(card.id), extra: card);
  }

  Future<void> _onQuizAnswer(bool correct, String parentCardId) async {
    await _srsNotifier.recordReview(parentCardId, correct ? 5 : 1);
    if (!correct) return;
    FeedbackService.success(ref);
    await _userNotifier.recordQuizPass();
    _gamificationNotifier.triggerXP(XPConstants.quizPass);
    await _questsNotifier.recordEvent(QuestType.passQuiz);
  }

  void _advanceToNextPage() {
    if (!_pageController.hasClients) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final track = ref.watch(trackByIdProvider(widget.trackId));
    final gamificationState = ref.watch(gamificationProvider);

    if (track == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Track')),
        body: const Center(
          child: AppEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Track not found',
            message: 'This track may have been removed.',
          ),
        ),
      );
    }

    final items = _items;
    final totalPages = items.length + 1; // +1 for completion sentinel

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TrackTopBar(
              track: track,
              currentIndex: _currentIndex,
              total: items.length,
              isAtCompletion: _currentIndex >= items.length,
            ),
            Expanded(
              child: Stack(
                children: [
                  if (items.isEmpty)
                    const _EmptyTrackPlaceholder()
                  else
                    PageView.builder(
                      controller: _pageController,
                      scrollDirection: Axis.vertical,
                      itemCount: totalPages,
                      onPageChanged: (i) => _onPageChanged(i, items),
                      itemBuilder: (context, i) {
                        if (i == items.length) {
                          return _TrackCompletionPage(
                            track: track,
                            onStartBossQuiz: () => context.push(
                              AppRoutes.learnTrackQuiz(track.id),
                            ),
                            onBackToTracks: () {
                              // Pop when we can, fall back to `/learn` for
                              // deep-link or state-restored entries.
                              final router = GoRouter.of(context);
                              if (router.canPop()) {
                                router.pop();
                              } else {
                                router.go(AppRoutes.learn);
                              }
                            },
                          );
                        }
                        final item = items[i];
                        if (item is LearningCard) {
                          return ZineCard(
                            card: item,
                            onOpen: () => _openDetail(item),
                          );
                        }
                        if (item is QuizQuestion) {
                          return InlineQuizCard(
                            question: item,
                            onAnswer: _onQuizAnswer,
                            onNext: _advanceToNextPage,
                          );
                        }
                        if (item is _LearnAdSlot) {
                          return NativeAdCard(key: ValueKey('learn_ad_$i'));
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  if (gamificationState.pendingXP > 0)
                    Positioned(
                      top: AppSpacing.md,
                      right: AppSpacing.lg,
                      child: XpPopupWidget(
                        xp: gamificationState.pendingXP,
                        visible: gamificationState.pendingXP > 0,
                      ),
                    ),
                  if (gamificationState.showLevelUp ||
                      gamificationState.showBadge)
                    Positioned(
                      top: AppSpacing.md + 48,
                      right: AppSpacing.lg,
                      child: XpPopupWidget(
                        xp: 0,
                        visible: true,
                        label: gamificationState.showBadge
                            ? '${BadgeDefinitions.findById(gamificationState.newBadgeId ?? '')?.emoji ?? '🏅'} '
                                '${BadgeDefinitions.findById(gamificationState.newBadgeId ?? '')?.name ?? 'Badge'} unlocked'
                            : 'Level ${gamificationState.newLevel}!',
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Top bar
// -----------------------------------------------------------------------------

class _TrackTopBar extends StatelessWidget {
  const _TrackTopBar({
    required this.track,
    required this.currentIndex,
    required this.total,
    required this.isAtCompletion,
  });

  final LearningTrack track;
  final int currentIndex;
  final int total;
  final bool isAtCompletion;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final progress = total == 0
        ? 0.0
        : (currentIndex.clamp(0, total) / total).clamp(0.0, 1.0);
    final pageLabel = isAtCompletion
        ? 'Finished'
        : total == 0
            ? '—'
            : '${(currentIndex + 1).clamp(1, total)} / $total';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back to tracks',
                icon: const Icon(Icons.arrow_back_rounded,
                    color: AppColors.textPrimary),
                onPressed: () => Navigator.of(context).maybePop().then(
                  (popped) {
                    if (!popped && context.mounted) {
                      context.go(AppRoutes.learn);
                    }
                  },
                ),
              ),
              ExcludeSemantics(
                child: Text(track.emoji,
                    style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    track.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                pageLabel,
                style: tt.labelMedium?.copyWith(
                  color: AppColors.textMutedOnInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: isAtCompletion ? 1.0 : progress,
                minHeight: 3,
                backgroundColor: AppColors.inkSurface2,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.ctaAmber,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Completion page
// -----------------------------------------------------------------------------

class _TrackCompletionPage extends ConsumerWidget {
  const _TrackCompletionPage({
    required this.track,
    required this.onStartBossQuiz,
    required this.onBackToTracks,
  });

  final LearningTrack track;
  final VoidCallback onStartBossQuiz;
  final VoidCallback onBackToTracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final user = ref.watch(userProvider);
    final learnedInTrack = ref
        .watch(trackCardsProvider(track.id))
        .where((c) => user.learnedCardIds.contains(c.id))
        .length;
    final total = track.totalCards;
    final hasBoss = ref
        .watch(allQuizzesProvider)
        .any((q) => ref
            .read(trackCardsProvider(track.id))
            .map((c) => c.id)
            .contains(q.parentCardId));

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
          border: Border.all(color: AppColors.inkHairline),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.accent.withValues(alpha: 0.08),
              AppColors.inkSurface,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xxl,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                track.emoji,
                style: const TextStyle(fontSize: 72),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Track finished',
                textAlign: TextAlign.center,
                style: tt.labelLarge?.copyWith(
                  color: AppColors.accent,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                track.name,
                textAlign: TextAlign.center,
                style: tt.headlineMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  height: 1.14,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                "You've scrolled through every concept in this track.",
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(
                  color: AppColors.textMutedOnInk,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _CompletionStats(
                learned: learnedInTrack,
                total: total,
              ),
              const Spacer(),
              if (hasBoss)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onStartBossQuiz,
                    icon: const Icon(Icons.bolt_rounded, size: 18),
                    label: const Text('Take the boss quiz'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.ctaAmber,
                      foregroundColor: AppColors.inkBlack,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              if (hasBoss) const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onBackToTracks,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Back to tracks'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.inkHairline),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletionStats extends StatelessWidget {
  const _CompletionStats({required this.learned, required this.total});

  final int learned;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.menu_book_rounded,
            value: '$total',
            label: 'Concepts',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatTile(
            icon: Icons.check_circle_rounded,
            value: '$learned',
            label: 'Learned',
            accent: AppColors.accent,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    this.accent,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final color = accent ?? AppColors.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.inkSurface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inkHairline),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: tt.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: tt.labelMedium?.copyWith(
                    color: AppColors.textMutedOnInk,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Empty track — the manifest referenced a track with no cards (or cards
// haven't hydrated yet).
// -----------------------------------------------------------------------------

class _EmptyTrackPlaceholder extends StatelessWidget {
  const _EmptyTrackPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const AppEmptyState(
      icon: Icons.menu_book_outlined,
      title: 'No cards yet',
      message:
          'This track is empty. Pull down or open another track to continue.',
    );
  }
}
