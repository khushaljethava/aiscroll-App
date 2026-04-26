import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/feedback_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/card_model.dart';
import '../../../data/providers/user_provider.dart';
import '../../../shared/widgets/app_tag_chip.dart';
import 'difficulty_badge.dart';

/// Full-screen Inshorts-style reading card for the Learn feed.
///
/// The card is fixed to the PageView's page bounds — meta row, hero emoji,
/// and title stay put while the **body** (explanation + takeaway) scrolls
/// internally so long cards never push layout off-screen. A small Save
/// affordance lives in the top-right of the meta row so readers don't need
/// to open the detail screen to bookmark a card.
class ZineCard extends ConsumerWidget {
  const ZineCard({
    super.key,
    required this.card,
    required this.onOpen,
  });

  final LearningCard card;

  /// Tap on the hero / "Read more" opens the full detail reader where the
  /// Share / Learned / Like actions live.
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final isBookmarked = ref.watch(
      userProvider.select((u) => u.bookmarkedCardIds.contains(card.id)),
    );

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
          color: cs.surface,
          borderRadius: AppRadius.card,
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------------------------------------------------------------
            // Fixed: meta row
            // ---------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: _MetaRow(
                card: card,
                isBookmarked: isBookmarked,
                onToggleBookmark: () {
                  FeedbackService.light(ref);
                  ref.read(userProvider.notifier).toggleBookmark(card.id);
                },
              ),
            ),
            // ---------------------------------------------------------------
            // Fixed: emoji hero
            // ---------------------------------------------------------------
            _HeroBlock(card: card, onTap: onOpen),
            // ---------------------------------------------------------------
            // Fixed: serif title (max 3 lines)
            // ---------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                AppSpacing.sm,
              ),
              child: Text(
                card.title,
                style: tt.headlineSmall?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  height: 1.18,
                  letterSpacing: -0.3,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // ---------------------------------------------------------------
            // Scrollable body — takes remaining height. Explanation + read-
            // more pointer + takeaway ribbon live here so long cards stay
            // within the card bounds.
            // ---------------------------------------------------------------
            Expanded(
              child: Scrollbar(
                thumbVisibility: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.xs,
                    AppSpacing.xl,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.explanation,
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.6,
                          fontSize: 15,
                        ),
                      ),
                      if (card.expandedContent != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        _ReadMoreRow(onTap: onOpen),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      _TakeawayRibbon(takeaway: card.takeaway),
                    ],
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

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.card,
    required this.isBookmarked,
    required this.onToggleBookmark,
  });

  final LearningCard card;
  final bool isBookmarked;
  final VoidCallback onToggleBookmark;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        // Flexible so a long topic tag ellipsizes instead of overflowing
        // the row when paired with the difficulty badge + XP chip + save
        // button on narrow screens.
        Flexible(
          child: AppTagChip(label: card.topicTag, accent: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.sm),
        DifficultyBadge(difficulty: card.difficulty),
        const Spacer(),
        if (card.xpReward > 0) ...[
          AppTagChip(
            label: '+${card.xpReward} XP',
            accent: AppColors.xpGold,
            icon: Icons.bolt_rounded,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        _SaveButton(
          isBookmarked: isBookmarked,
          onTap: onToggleBookmark,
          surface: cs.surfaceContainerHighest,
          outline: cs.outlineVariant,
          activeColor: AppColors.ctaAmber,
          inactiveColor: cs.onSurfaceVariant,
        ),
      ],
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.isBookmarked,
    required this.onTap,
    required this.surface,
    required this.outline,
    required this.activeColor,
    required this.inactiveColor,
  });

  final bool isBookmarked;
  final VoidCallback onTap;
  final Color surface;
  final Color outline;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isBookmarked ? 'Remove from saved' : 'Save card',
      child: Material(
        color: surface,
        shape: CircleBorder(side: BorderSide(color: outline)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(
              isBookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              size: 18,
              color: isBookmarked ? activeColor : inactiveColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroBlock extends StatelessWidget {
  const _HeroBlock({required this.card, required this.onTap});

  final LearningCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Hero block scales with available width but capped so the body has
        // room on tall screens. Landscape-leaning rectangle (w ~ 2.1x h) to
        // leave more vertical room for the scrollable body. Floor on
        // heroHeight so emoji stays readable at very narrow widths.
        final heroWidth = (constraints.maxWidth - AppSpacing.xl * 2)
            .clamp(120.0, 260.0);
        final heroHeight = (heroWidth * 0.52).clamp(120.0, 140.0);
        return Center(
          child: SizedBox(
            width: heroWidth,
            height: heroHeight,
            child: Material(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cs.outlineVariant),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.08),
                      cs.surfaceContainerHighest,
                    ],
                  ),
                ),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(20),
                  child: Center(
                    child: Text(
                      card.emoji,
                      style: TextStyle(fontSize: heroHeight * 0.58),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReadMoreRow extends StatelessWidget {
  const _ReadMoreRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(
              'Read more',
              style: tt.labelLarge?.copyWith(
                color: AppColors.ctaAmber,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 14,
              color: AppColors.ctaAmber,
            ),
          ],
        ),
      ),
    );
  }
}

class _TakeawayRibbon extends StatelessWidget {
  const _TakeawayRibbon({required this.takeaway});

  final String takeaway;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tt = theme.textTheme;
    final cs = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: AppColors.accent, width: 3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 15)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              takeaway,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w500,
                height: 1.45,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
