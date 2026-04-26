import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/xp_constants.dart';
import '../../../core/feedback/feedback_service.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/card_model.dart';
import '../../../data/models/quest_model.dart';
import '../../../data/providers/cards_provider.dart';
import '../../../data/providers/user_provider.dart';
import '../../../features/gamification/providers/gamification_provider.dart';
import '../../../features/gamification/providers/quests_provider.dart';
import '../../../shared/widgets/app_tag_chip.dart';
import '../providers/feed_provider.dart';
import '../providers/srs_provider.dart';
import '../widgets/difficulty_badge.dart';

/// Full-screen reader for a single [LearningCard]. The XP award flow (dwell
/// timer + mark-read) lives here now — in the list-based feed, scrolling past
/// a card no longer counts as a read.
class LearnDetailScreen extends ConsumerStatefulWidget {
  const LearnDetailScreen({
    super.key,
    required this.cardId,
    this.initialCard,
  });

  final String cardId;
  final LearningCard? initialCard;

  @override
  ConsumerState<LearnDetailScreen> createState() =>
      _LearnDetailScreenState();
}

class _LearnDetailScreenState extends ConsumerState<LearnDetailScreen> {
  Timer? _dwellTimer;
  bool _awarded = false;

  /// Riverpod forbids `ref` access after the widget is disposed, so we cache
  /// every notifier this screen mutates during [initState] and use the cached
  /// references from [dispose] and from any async path that may outlive the
  /// route. The notifiers themselves are container-scoped and outlive the
  /// route, so holding onto them is safe.
  late final FeedNotifier _feedNotifier;
  late final UserNotifier _userNotifier;
  late final GamificationNotifier _gamificationNotifier;
  late final QuestsNotifier _questsNotifier;
  late final SRSNotifier _srsNotifier;

  @override
  void initState() {
    super.initState();
    _feedNotifier = ref.read(feedProvider.notifier);
    _userNotifier = ref.read(userProvider.notifier);
    _gamificationNotifier = ref.read(gamificationProvider.notifier);
    _questsNotifier = ref.read(questsProvider.notifier);
    _srsNotifier = ref.read(srsProvider.notifier);
    // Record dwell start synchronously — no post-frame callback. The
    // StateNotifier is a container-scoped singleton, not a descendant of
    // this element, so calling `state = …` on it during initState is safe
    // and avoids the race where a fast back-navigation disposes the element
    // before the callback fires.
    _feedNotifier.startDwell(widget.cardId);
    // Award XP after 15s of reading.
    _dwellTimer = Timer(const Duration(seconds: 15), _awardXp);
  }

  @override
  void dispose() {
    _dwellTimer?.cancel();
    // End dwell telemetry regardless of whether XP was awarded. Uses the
    // cached notifier — `ref` is unavailable at this point.
    _feedNotifier.endDwell(widget.cardId);
    super.dispose();
  }

  Future<void> _awardXp() async {
    if (_awarded) return;
    _awarded = true;
    final card = _resolveCard();
    if (card == null) return;
    // All notifiers are cached fields — safe to call even if the user
    // navigated away during the 15s dwell. They're container-scoped so
    // outlive the route.
    final counted = await _userNotifier.markCardRead(card.id);
    if (!counted) return;
    await _userNotifier.addXP(XPConstants.readCard, source: 'read_card');
    _gamificationNotifier.triggerXP(XPConstants.readCard);
    await _questsNotifier.recordEvent(QuestType.readCards);
    // Light familiarity rating — we've read it but not committed.
    await _srsNotifier.recordReview(card.id, 3);
  }

  LearningCard? _resolveCard() {
    if (widget.initialCard != null) return widget.initialCard;
    final all = ref.read(allCardsProvider);
    for (final c in all) {
      if (c.id == widget.cardId) return c;
    }
    return null;
  }

  Future<void> _markLearned(LearningCard card) async {
    FeedbackService.medium(ref);
    // Snapshot the "was new" state BEFORE awaiting anything — the widget
    // could be disposed during the await, which invalidates `ref`. This
    // read happens synchronously on the tap, so `ref` is still valid.
    final wasNew = !ref.read(userProvider).learnedCardIds.contains(card.id);
    await _userNotifier.markCardLearned(card.id);
    await _srsNotifier.recordReview(card.id, 4);
    if (wasNew) {
      await _userNotifier.addXP(
        XPConstants.learnedSwipe,
        source: 'learned',
      );
      _gamificationNotifier.triggerXP(XPConstants.learnedSwipe);
      await _questsNotifier.recordEvent(QuestType.learnNew);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1400),
          content: Text(
            wasNew
                ? 'Marked as learned · +${XPConstants.learnedSwipe} XP'
                : 'Already in your learned list',
          ),
        ),
      );
  }

  Future<void> _toggleBookmark(LearningCard card) async {
    FeedbackService.light(ref);
    await _userNotifier.toggleBookmark(card.id);
  }

  Future<void> _share(LearningCard card) async {
    FeedbackService.light(ref);
    await SharePlus.instance.share(
      ShareParams(
        text: 'Check out this AI concept: ${card.title}\n\n${card.takeaway}',
        subject: card.title,
      ),
    );
    await _questsNotifier.recordEvent(QuestType.shareCard);
  }

  @override
  Widget build(BuildContext context) {
    final card = _resolveCard();
    final tt = Theme.of(context).textTheme;
    final user = ref.watch(userProvider);

    if (card == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Card')),
        body: const Center(child: Text('Card no longer available.')),
      );
    }

    final isBookmarked = user.bookmarkedCardIds.contains(card.id);
    final isLearned = user.learnedCardIds.contains(card.id);

    return Scaffold(
      // Theme drives scaffold colour — inkBlack in dark, paper in light.
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop().then((popped) {
            if (!popped && context.mounted) {
              GoRouter.of(context).go(AppRoutes.learn);
            }
          }),
        ),
        actions: [
          IconButton(
            tooltip: isBookmarked ? 'Remove bookmark' : 'Save for later',
            icon: Icon(
              isBookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: isBookmarked ? AppColors.ctaAmber : null,
            ),
            onPressed: () => _toggleBookmark(card),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.editorialGutter,
              AppSpacing.md,
              AppSpacing.editorialGutter,
              120,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _Hero(card: card),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    AppTagChip(
                      label: card.topicTag,
                      accent: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    DifficultyBadge(difficulty: card.difficulty),
                    const Spacer(),
                    if (card.xpReward > 0)
                      AppTagChip(
                        label: '+${card.xpReward} XP',
                        accent: AppColors.xpGold,
                        icon: Icons.bolt_rounded,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  card.title,
                  style: tt.displaySmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    height: 1.08,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _PullTakeaway(takeaway: card.takeaway),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  card.explanation,
                  style: tt.bodyLarge?.copyWith(
                    fontSize: 17,
                    height: 1.7,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (card.expandedContent != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  _SectionTitle(title: 'Going deeper'),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    card.expandedContent!,
                    style: tt.bodyLarge?.copyWith(
                      fontSize: 16,
                      height: 1.7,
                      color: AppColors.textMutedOnInk,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxxl),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        card: card,
        isLearned: isLearned,
        onMarkLearned: () => _markLearned(card),
        onShare: () => _share(card),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Sub-widgets
// -----------------------------------------------------------------------------

class _Hero extends StatelessWidget {
  const _Hero({required this.card});

  final LearningCard card;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.inkSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.inkHairline),
        ),
        child: Center(
          child: Text(card.emoji, style: const TextStyle(fontSize: 64)),
        ),
      ),
    );
  }
}

class _PullTakeaway extends StatelessWidget {
  const _PullTakeaway({required this.takeaway});

  final String takeaway;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: AppColors.accent, width: 3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 18)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              takeaway,
              style: tt.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
                height: 1.45,
                fontSize: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 16,
          height: 2,
          color: AppColors.ctaAmber,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title.toUpperCase(),
          style: tt.labelMedium?.copyWith(
            color: AppColors.ctaAmber,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.card,
    required this.isLearned,
    required this.onMarkLearned,
    required this.onShare,
  });

  final LearningCard card;
  final bool isLearned;
  final VoidCallback onMarkLearned;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        decoration: const BoxDecoration(
          color: AppColors.inkBlack,
          border: Border(
            top: BorderSide(color: AppColors.inkHairline, width: 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onMarkLearned,
                icon: Icon(
                  isLearned
                      ? Icons.check_circle_rounded
                      : Icons.check_rounded,
                  size: 18,
                ),
                label: Text(isLearned ? 'Learned' : 'I know this'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isLearned ? AppColors.accent : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _RoundIconButton(
              icon: Icons.ios_share_rounded,
              tooltip: 'Share',
              onTap: onShare,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: AppColors.inkSurface2,
      shape: const CircleBorder(
        side: BorderSide(color: AppColors.inkHairline),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child:
              Icon(icon, size: 20, color: AppColors.textPrimary),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
