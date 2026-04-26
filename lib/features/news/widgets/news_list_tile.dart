import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/news_model.dart';

/// Compact editorial list row for news articles. Used on the Saved tab and
/// anywhere else we render a list of articles outside the vertical feed.
class NewsListTile extends StatelessWidget {
  const NewsListTile({
    super.key,
    required this.article,
    required this.category,
    required this.isRead,
    required this.onTap,
  });

  final NewsArticle article;
  final NewsCategory? category;
  final bool isRead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final accent = AppColors.categoryAccent(article.categoryKey);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category accent bar — editorial rule line.
              Container(
                width: 3,
                height: 64,
                margin: const EdgeInsets.only(top: 2, right: AppSpacing.md),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (category != null)
                          _CategoryLabel(label: category!.label, accent: accent),
                        if (category != null) const SizedBox(width: AppSpacing.sm),
                        if (article.isPinned)
                          Icon(
                            Icons.push_pin_rounded,
                            size: 12,
                            color: cs.onSurfaceVariant,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      article.headline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleMedium?.copyWith(
                        height: 1.25,
                        color: isRead ? cs.onSurfaceVariant : cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      article.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${article.sourceName} - ${_relativeTime(article.publishedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        letterSpacing: 0.2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              _Thumbnail(
                url: article.coverImageUrl,
                accent: accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryLabel extends StatelessWidget {
  const _CategoryLabel({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        color: accent,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );
  }
}

String _relativeTime(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat.yMMMd().format(t);
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url, required this.accent});

  final String? url;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    const size = 72.0;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.45),
            accent.withValues(alpha: 0.15),
          ],
        ),
      ),
      child: const Icon(
        Icons.article_outlined,
        color: Colors.white,
        size: 24,
      ),
    );
    if (url == null || url!.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (_, _) => Container(
          width: size,
          height: size,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}
