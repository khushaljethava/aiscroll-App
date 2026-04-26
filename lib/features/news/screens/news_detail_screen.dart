import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/feedback/feedback_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/news_model.dart';
import '../../../data/providers/news_provider.dart';
import '../../../data/providers/user_provider.dart';
import '../widgets/news_action_bar.dart';

/// Editorial article reader.
///
/// Layout (top to bottom):
///  - Hero cover image (parallax) with glass back/share buttons overlaid
///  - Category overline + large serif headline
///  - Byline row (source, date, reading time)
///  - Optional tag chips
///  - Lead paragraph (summary) styled as a pull quote
///  - Article body in comfortable reading typography
class NewsDetailScreen extends ConsumerStatefulWidget {
  const NewsDetailScreen({
    super.key,
    required this.articleId,
    this.initialArticle,
  });

  final String articleId;
  final NewsArticle? initialArticle;

  @override
  ConsumerState<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends ConsumerState<NewsDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // ignore: discarded_futures
      ref.read(userProvider.notifier).markNewsRead(widget.articleId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cached = ref.watch(newsArticleByIdProvider(widget.articleId));
    final fastPath = cached ?? widget.initialArticle;
    if (fastPath != null) return _buildArticleScaffold(context, fastPath);

    // Cache miss — most often a deep-link from a notification pointing to
    // an article older than the 30-item home-feed cache. Fetch it.
    final fetchAsync = ref.watch(newsArticleFetchProvider(widget.articleId));
    return fetchAsync.when(
      loading: _loadingScaffold,
      error: (_, _) => _notFoundScaffold(),
      data: (article) => article == null
          ? _notFoundScaffold()
          : _buildArticleScaffold(context, article),
    );
  }

  Widget _loadingScaffold() => Scaffold(
        appBar: AppBar(title: const Text('Article')),
        body: const Center(child: CircularProgressIndicator()),
      );

  Widget _notFoundScaffold() => Scaffold(
        appBar: AppBar(title: const Text('Article')),
        body: const Center(
          child: Text('Article no longer available.'),
        ),
      );

  Widget _buildArticleScaffold(BuildContext context, NewsArticle article) {
    final category =
        ref.watch(newsCategoryByKeyProvider(article.categoryKey));
    final user = ref.watch(userProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final accent = AppColors.categoryAccent(article.categoryKey);
    final isBookmarked = user.bookmarkedNewsIds.contains(article.id);
    final hasCover =
        article.coverImageUrl != null && article.coverImageUrl!.isNotEmpty;
    final readingMinutes = _estimateReadingMinutes(article.body);

    return Scaffold(
      extendBodyBehindAppBar: hasCover,
      body: CustomScrollView(
        slivers: [
          if (hasCover)
            SliverAppBar(
              expandedHeight: 260,
              pinned: true,
              stretch: true,
              backgroundColor: cs.surface,
              surfaceTintColor: Colors.transparent,
              leading: const _GlassBack(),
              actions: [
                _GlassIconButton(
                  icon: Icons.ios_share_rounded,
                  tooltip: 'Share',
                  onTap: () async {
                    FeedbackService.light(ref);
                    ref.read(userProvider.notifier).logNewsShare(article.id);
                    await SharePlus.instance.share(
                      ShareParams(
                        text: '${article.headline}\n\n${article.sourceUrl}',
                        subject: article.headline,
                      ),
                    );
                  },
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [
                  StretchMode.zoomBackground,
                  StretchMode.blurBackground,
                ],
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: article.coverImageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(color: cs.surfaceContainerHighest),
                      errorWidget: (_, _, _) => Container(
                        color: cs.surfaceContainerHighest,
                      ),
                    ),
                    // Bottom scrim so the top of the headline reads over the
                    // image even before it scrolls out.
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.45),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.35),
                          ],
                          stops: const [0.0, 0.4, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverAppBar(
              pinned: true,
              backgroundColor: cs.surface,
              surfaceTintColor: Colors.transparent,
              title: Text(category?.label ?? 'Article',
                  style: tt.titleMedium),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.editorialGutter,
              AppSpacing.xxl,
              AppSpacing.editorialGutter,
              120, // leave breathing room above bottom action bar
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  Row(
                    children: [
                      _Overline(
                        label: (category?.label ?? article.categoryKey)
                            .toUpperCase(),
                        accent: accent,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        _relativeTime(article.publishedAt),
                        style: tt.labelMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    article.headline,
                    style: tt.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                      height: 1.08,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _Byline(
                    sourceName: article.sourceName,
                    publishedAt: article.publishedAt,
                    readingMinutes: readingMinutes,
                    accent: accent,
                  ),
                  if (article.tags.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children:
                          article.tags.map((t) => _TagChip(label: t)).toList(),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                  _PullQuote(text: article.summary, accent: accent),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    article.body,
                    style: tt.bodyLarge?.copyWith(
                      fontSize: 17,
                      height: 1.7,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NewsActionBar(
        isBookmarked: isBookmarked,
        onBookmark: () async {
          FeedbackService.light(ref);
          final messenger = ScaffoldMessenger.of(context);
          final nowBookmarked = await ref
              .read(userProvider.notifier)
              .toggleNewsBookmark(article.id);
          messenger
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                duration: const Duration(milliseconds: 1600),
                content: Text(
                  nowBookmarked
                      ? 'Saved to your bookmarks'
                      : 'Removed from bookmarks',
                ),
              ),
            );
        },
        onShare: () async {
          FeedbackService.light(ref);
          ref.read(userProvider.notifier).logNewsShare(article.id);
          await SharePlus.instance.share(
            ShareParams(
              text: '${article.headline}\n\n${article.sourceUrl}',
              subject: article.headline,
            ),
          );
        },
        onOpenSource: () async {
          FeedbackService.light(ref);
          ref.read(userProvider.notifier).logNewsSourceOpen(article.id);
          final uri = Uri.tryParse(article.sourceUrl);
          if (uri == null) return;
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Sub-widgets
// -----------------------------------------------------------------------------

class _Overline extends StatelessWidget {
  const _Overline({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 2,
          color: accent,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: accent,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}

class _Byline extends StatelessWidget {
  const _Byline({
    required this.sourceName,
    required this.publishedAt,
    required this.readingMinutes,
    required this.accent,
  });

  final String sourceName;
  final DateTime publishedAt;
  final int readingMinutes;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final initial = sourceName.isNotEmpty ? sourceName[0].toUpperCase() : 'N';
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.15),
            border: Border.all(color: accent.withValues(alpha: 0.6)),
          ),
          child: Text(
            initial,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                sourceName,
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${DateFormat.yMMMd().format(publishedAt)} · $readingMinutes min read',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 5),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        '#$label',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _PullQuote extends StatelessWidget {
  const _PullQuote({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.only(left: AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: accent, width: 3),
        ),
      ),
      child: Text(
        text,
        style: tt.titleLarge?.copyWith(
          fontSize: 19,
          height: 1.5,
          fontWeight: FontWeight.w500,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _GlassBack extends StatelessWidget {
  const _GlassBack();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.sm),
      child: _GlassIconButton(
        icon: Icons.arrow_back_rounded,
        tooltip: 'Back',
        onTap: () => Navigator.of(context).maybePop().then(
          (handled) {
            if (!handled && context.mounted) {
              // Fallback when there's nothing to pop (e.g. deep link entry).
              GoRouter.of(context).go('/news');
            }
          },
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Material(
        color: Colors.black.withValues(alpha: 0.35),
        shape: const CircleBorder(
          side: BorderSide(color: AppColors.glassOverlay),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

/// Rough reading-time estimate using the common 225 wpm baseline. Clamped to
/// at least one minute — anything shorter reads as noise.
int _estimateReadingMinutes(String body) {
  if (body.trim().isEmpty) return 1;
  final words = body.trim().split(RegExp(r'\s+')).length;
  final minutes = (words / 225).ceil();
  return minutes < 1 ? 1 : minutes;
}

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat.yMMMd().format(time);
}
