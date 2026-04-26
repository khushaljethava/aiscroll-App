import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/feedback/feedback_service.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/news_model.dart';
import '../../../data/providers/news_provider.dart';
import '../../../data/providers/user_provider.dart';
import '../../../data/remote/ads_service.dart';
import '../../../features/ads/widgets/native_ad_card.dart';
import '../../../shared/widgets/app_empty_state.dart';

/// Sentinel item type used to mark "show a native ad here" slots in the
/// news / learn feeds.
class _FeedAdSlot {
  const _FeedAdSlot();
}

const _adSlot = _FeedAdSlot();

/// Interleaves an ad sentinel into [items] every [AdConfig.adEvery] real
/// items, with an [AdConfig.adWarmup]-item warmup at the start.
List<Object> interleaveAds<T extends Object>(List<T> items) {
  if (items.length <= AdConfig.adWarmup) return List<Object>.from(items);
  final out = <Object>[];
  for (var i = 0; i < items.length; i++) {
    out.add(items[i]);
    final shown = i + 1;
    if (shown > AdConfig.adWarmup &&
        (shown - AdConfig.adWarmup) % AdConfig.adEvery == 0) {
      out.add(_adSlot);
    }
  }
  return out;
}

/// Inshorts-style vertical News feed.
///
/// Each article fills a full screen: cover image in the top half, category
/// overline + headline + lead paragraph below, and a compact action bar
/// with Save / Share / Read-full. A slim top bar exposes the category
/// rail and a manual refresh button. Swipe vertically to move between
/// stories.
class NewsScreen extends ConsumerStatefulWidget {
  const NewsScreen({super.key});

  @override
  ConsumerState<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends ConsumerState<NewsScreen> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    FeedbackService.light(ref);
    await ref.read(newsProvider.notifier).refresh();
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  void _onPageChanged(int i, List<Object> items) {
    FeedbackService.selection(ref);
    // Auto-mark as read once the user lands on a page. Skip ad sentinels.
    if (i >= 0 && i < items.length) {
      final item = items[i];
      if (item is NewsArticle) {
        // ignore: discarded_futures
        ref.read(userProvider.notifier).markNewsRead(item.id);
      }
    }
  }

  Future<void> _onBookmark(NewsArticle article) async {
    FeedbackService.light(ref);
    final messenger = ScaffoldMessenger.of(context);
    final saved =
        await ref.read(userProvider.notifier).toggleNewsBookmark(article.id);
    if (!mounted) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1600),
          content: Text(saved ? 'Saved to your bookmarks' : 'Removed'),
        ),
      );
  }

  Future<void> _onShare(NewsArticle article) async {
    FeedbackService.light(ref);
    ref.read(userProvider.notifier).logNewsShare(article.id);
    await SharePlus.instance.share(
      ShareParams(
        text: '${article.headline}\n\n${article.sourceUrl}',
        subject: article.headline,
      ),
    );
  }

  Future<void> _onOpenSource(NewsArticle article) async {
    FeedbackService.light(ref);
    ref.read(userProvider.notifier).logNewsSourceOpen(article.id);
    final uri = Uri.tryParse(article.sourceUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _onReadFull(NewsArticle article) {
    context.push(AppRoutes.newsDetail(article.id), extra: article);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(newsProvider);
    final user = ref.watch(userProvider);
    final visible = state.visibleArticles;
    final feedItems = interleaveAds<NewsArticle>(visible);
    final selectedCategory = state.selectedCategoryKey;
    final categoryByKey = {for (final c in state.categories) c.key: c};

    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _StaleBanner(state: state),
              _CategoryRail(
                categories: state.categories,
                selectedKey: selectedCategory,
                onSelect: (key) {
                  FeedbackService.selection(ref);
                  ref.read(newsProvider.notifier).selectCategory(key);
                  if (_pageController.hasClients) {
                    _pageController.jumpToPage(0);
                  }
                },
              ),
              Expanded(
                child: _FeedBody(
                  state: state,
                  items: feedItems,
                  categoryByKey: categoryByKey,
                  pageController: _pageController,
                  bookmarkedIds: user.bookmarkedNewsIds,
                  readIds: user.readNewsIds,
                  onPageChanged: (i) => _onPageChanged(i, feedItems),
                  onRefresh: _onRefresh,
                  onOpen: _onReadFull,
                  onBookmark: _onBookmark,
                  onShare: _onShare,
                  onOpenSource: _onOpenSource,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.state});

  final NewsState state;

  @override
  Widget build(BuildContext context) {
    final last = state.lastSyncedAt;
    final stale = last == null ||
        DateTime.now().difference(last) > const Duration(hours: 24);
    if (!stale || state.lastError == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        0,
        AppSpacing.screenGutter,
        AppSpacing.sm,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 16, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Showing cached stories - ${state.lastError}',
              style: const TextStyle(fontSize: 12, color: AppColors.warning),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Category rail
// -----------------------------------------------------------------------------

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({
    required this.categories,
    required this.selectedKey,
    required this.onSelect,
  });

  final List<NewsCategory> categories;
  final String? selectedKey;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter),
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, i) {
          if (i == 0) {
            return _RailChip(
              label: 'For You',
              accent: AppColors.ctaAmber,
              selected: selectedKey == null,
              onTap: () => onSelect(null),
            );
          }
          final cat = categories[i - 1];
          return _RailChip(
            label: cat.label,
            accent: AppColors.categoryAccent(cat.key),
            selected: selectedKey == cat.key,
            onTap: () => onSelect(cat.key),
          );
        },
      ),
    );
  }
}

class _RailChip extends StatelessWidget {
  const _RailChip({
    required this.label,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = selected ? cs.onSurface : Colors.transparent;
    final fg = selected ? cs.surface : cs.onSurfaceVariant;
    return Center(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Material(
          color: bg,
          shape: StadiumBorder(
            side: BorderSide(
              color: selected ? cs.onSurface : cs.outlineVariant,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontSize: 12.5,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Feed body — full-screen PageView
// -----------------------------------------------------------------------------

class _FeedBody extends StatelessWidget {
  const _FeedBody({
    required this.state,
    required this.items,
    required this.categoryByKey,
    required this.pageController,
    required this.bookmarkedIds,
    required this.readIds,
    required this.onPageChanged,
    required this.onRefresh,
    required this.onOpen,
    required this.onBookmark,
    required this.onShare,
    required this.onOpenSource,
  });

  final NewsState state;
  final List<Object> items;
  final Map<String, NewsCategory> categoryByKey;
  final PageController pageController;
  final List<String> bookmarkedIds;
  final List<String> readIds;
  final ValueChanged<int> onPageChanged;
  final Future<void> Function() onRefresh;
  final ValueChanged<NewsArticle> onOpen;
  final ValueChanged<NewsArticle> onBookmark;
  final ValueChanged<NewsArticle> onShare;
  final ValueChanged<NewsArticle> onOpenSource;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      if (state.refreshing) {
        return const _LoadingSkeleton();
      }
      final cs = Theme.of(context).colorScheme;
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: cs.onSurface,
        backgroundColor: cs.surfaceContainerHighest,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 80),
            AppEmptyState(
              icon: Icons.article_outlined,
              title: state.articles.isEmpty
                  ? 'No stories yet'
                  : 'Nothing in this section',
              message: state.articles.isEmpty
                  ? 'Pull down or hit refresh to fetch the latest news.'
                  : 'Pick another category above, or tap "For You".',
            ),
          ],
        ),
      );
    }

    // Vertical PageView — one full-screen story per page. Gestures match
    // Inshorts: swipe up for next, down for previous.
    return PageView.builder(
      controller: pageController,
      scrollDirection: Axis.vertical,
      onPageChanged: onPageChanged,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is _FeedAdSlot) {
          return NativeAdCard(key: ValueKey('news_ad_$index'));
        }
        final article = item as NewsArticle;
        final category = categoryByKey[article.categoryKey];
        return _StoryPage(
          article: article,
          categoryLabel: category?.label ?? article.categoryKey,
          accent: AppColors.categoryAccent(article.categoryKey),
          isSaved: bookmarkedIds.contains(article.id),
          isRead: readIds.contains(article.id),
          onOpen: () => onOpen(article),
          onBookmark: () => onBookmark(article),
          onShare: () => onShare(article),
          onOpenSource: () => onOpenSource(article),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Story page — Inshorts-style hero layout
// -----------------------------------------------------------------------------

class _StoryPage extends StatelessWidget {
  const _StoryPage({
    required this.article,
    required this.categoryLabel,
    required this.accent,
    required this.isSaved,
    required this.isRead,
    required this.onOpen,
    required this.onBookmark,
    required this.onShare,
    required this.onOpenSource,
  });

  final NewsArticle article;
  final String categoryLabel;
  final Color accent;
  final bool isSaved;
  final bool isRead;
  final VoidCallback onOpen;
  final VoidCallback onBookmark;
  final VoidCallback onShare;
  final VoidCallback onOpenSource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tt = theme.textTheme;
    final cs = theme.colorScheme;
    final hasImage =
        article.coverImageUrl != null && article.coverImageUrl!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Material(
        color: cs.surface,
        borderRadius: AppRadius.card,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppRadius.card,
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero image block. Reduced from flex 5 (≈45 % of card) to
                // flex 4 (≈36 %) so headline + summary breathe more on
                // editorial-heavy stories. Wrapped in ClipRRect with the
                // top-corner radius so the image can never paint past the
                // card's rounded corners — Material's outer antiAlias clip
                // already handles this in most cases, but some Flutter /
                // Android Impeller paths drop the antialiased clip on
                // network images, so this is a defensive belt-and-braces.
                Expanded(
                  flex: 4,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppRadius.xl),
                      topRight: Radius.circular(AppRadius.xl),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (hasImage)
                          CachedNetworkImage(
                            imageUrl: article.coverImageUrl!,
                            fit: BoxFit.cover,
                            fadeInDuration:
                                const Duration(milliseconds: 220),
                            placeholder: (_, _) =>
                                Container(color: cs.surfaceContainerHighest),
                            errorWidget: (_, _, _) =>
                                _PhotoFallback(accent: accent),
                          )
                        else
                          _PhotoFallback(accent: accent),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(height: 3, color: accent),
                      ),
                      Positioned(
                        left: AppSpacing.md,
                        top: AppSpacing.md,
                        child: _Overline(label: categoryLabel, accent: accent),
                      ),
                      if (article.isPinned)
                        Positioned(
                          right: AppSpacing.md,
                          top: AppSpacing.md,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppColors.ctaAmber.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.push_pin_rounded,
                                    size: 12,
                                    color: AppColors.ctaAmber),
                                SizedBox(width: 4),
                                Text(
                                  'FEATURED',
                                  style: TextStyle(
                                    color: AppColors.ctaAmber,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Subtle bottom scrim so the overline reads cleanly
                      // against any photograph.
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 40,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.35),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  ),
                ),
                // Text region — fixed height (no internal scroll). Summary
                // truncates with ellipsis and a soft fade hints there's
                // more in the detail reader. The source row lives in its
                // own lane below the summary's Stack so the fade gradient
                // can never overlap the avatar/source name. Summary
                // maxLines is computed from the actual available height
                // via LayoutBuilder so the last line never renders as a
                // half-clipped glyph.
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.lg,
                      AppSpacing.xl,
                      AppSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _relativeTime(article.publishedAt),
                              style: tt.labelMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                                letterSpacing: 0.3,
                              ),
                            ),
                            if (isRead) ...[
                              const SizedBox(width: AppSpacing.sm),
                              const _ReadPill(),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          article.headline,
                          // Defensive cap — most headlines are 2-3
                          // lines; a freak 5-liner shouldn't push the
                          // source row off-screen.
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleLarge?.copyWith(
                            color: cs.onSurface,
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            height: 1.22,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Expanded(
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    const fontSize = 15.5;
                                    const heightFactor = 1.55;
                                    final lineHeight = fontSize * heightFactor;
                                    final lines =
                                        (constraints.maxHeight / lineHeight)
                                            .floor()
                                            .clamp(1, 7);
                                    return Text(
                                      article.summary,
                                      maxLines: lines,
                                      overflow: TextOverflow.ellipsis,
                                      style: tt.bodyLarge?.copyWith(
                                        color: cs.onSurfaceVariant,
                                        height: heightFactor,
                                        fontSize: fontSize,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                height: 24,
                                child: IgnorePointer(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          cs.surface.withValues(alpha: 0),
                                          cs.surface.withValues(alpha: 0.92),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _SourceRow(
                          sourceName: article.sourceName,
                          accent: accent,
                        ),
                      ],
                    ),
                  ),
                ),
                // Action bar pinned at the bottom.
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: cs.outlineVariant),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _PrimaryCta(
                          label: 'Read full story',
                          onTap: onOpen,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _RoundAction(
                        icon: isSaved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        active: isSaved,
                        activeColor: AppColors.ctaAmber,
                        tooltip:
                            isSaved ? 'Remove bookmark' : 'Save for later',
                        onTap: onBookmark,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _RoundAction(
                        icon: Icons.ios_share_rounded,
                        tooltip: 'Share',
                        onTap: onShare,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _RoundAction(
                        icon: Icons.open_in_new_rounded,
                        tooltip: 'Open source',
                        onTap: onOpenSource,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.35),
            AppColors.inkBlack,
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.article_outlined,
          size: 48,
          color: Colors.white24,
        ),
      ),
    );
  }
}

class _Overline extends StatelessWidget {
  const _Overline({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _ReadPill extends StatelessWidget {
  const _ReadPill();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 12, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            'Read',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.sourceName, required this.accent});

  final String sourceName;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final initial =
        sourceName.isNotEmpty ? sourceName[0].toUpperCase() : 'N';
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent,
            shape: BoxShape.circle,
          ),
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            sourceName,
            style: tt.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 12,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.inkBlack,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: AppColors.inkBlack,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.onTap,
    this.active = false,
    this.activeColor,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final Color? activeColor;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = active ? (activeColor ?? AppColors.ctaAmber) : cs.onSurface;
    final button = Material(
      color: cs.surfaceContainerHighest,
      shape: CircleBorder(
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 20, color: fg),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

// -----------------------------------------------------------------------------
// Loading skeleton
// -----------------------------------------------------------------------------

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
          children: [
            Expanded(
              flex: 5,
              child: DecoratedBox(
                decoration: BoxDecoration(color: cs.surfaceContainerHighest),
              ),
            ),
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _SkeletonBar(width: 72, height: 14),
                    SizedBox(height: AppSpacing.md),
                    _SkeletonBar(width: double.infinity, height: 18),
                    SizedBox(height: AppSpacing.sm),
                    _SkeletonBar(width: double.infinity, height: 18),
                    SizedBox(height: AppSpacing.sm),
                    _SkeletonBar(width: 240, height: 18),
                    SizedBox(height: AppSpacing.lg),
                    _SkeletonBar(width: double.infinity, height: 12),
                    SizedBox(height: 6),
                    _SkeletonBar(width: 280, height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBar extends StatefulWidget {
  const _SkeletonBar({required this.width, required this.height});

  final double width;
  final double height;

  @override
  State<_SkeletonBar> createState() => _SkeletonBarState();
}

class _SkeletonBarState extends State<_SkeletonBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = reduceMotion ? 0.6 : (0.45 + _c.value * 0.35);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: t * 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
