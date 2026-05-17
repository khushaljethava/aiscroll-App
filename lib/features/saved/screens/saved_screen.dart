import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/card_model.dart';
import '../../../data/models/news_model.dart';
import '../../../data/providers/cards_provider.dart';
import '../../../data/providers/news_provider.dart';
import '../../../data/providers/user_provider.dart';
import '../../../features/feed/widgets/difficulty_badge.dart';
import '../../../features/news/widgets/news_list_tile.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/search_field.dart';

// ---------------------------------------------------------------------------
// SavedScreen — two-tab layout: Cards / News.
// ---------------------------------------------------------------------------

class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _cardsQuery = '';
  String _newsQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final allCards = ref.watch(allCardsProvider);
    final newsState = ref.watch(newsProvider);

    final bookmarkedCards = allCards
        .where((c) => user.bookmarkedCardIds.contains(c.id))
        .toList();
    final bookmarkedNews = newsState.articles
        .where((a) => user.bookmarkedNewsIds.contains(a.id))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Cards (${bookmarkedCards.length})'),
            Tab(text: 'News (${bookmarkedNews.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _CardsTab(
            cards: bookmarkedCards,
            query: _cardsQuery,
            onQueryChanged: (v) => setState(() => _cardsQuery = v),
            onRemove: (id) =>
                ref.read(userProvider.notifier).toggleBookmark(id),
          ),
          _NewsTab(
            articles: bookmarkedNews,
            categories: newsState.categories,
            query: _newsQuery,
            onQueryChanged: (v) => setState(() => _newsQuery = v),
            onRemove: (id) =>
                ref.read(userProvider.notifier).toggleNewsBookmark(id),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cards tab
// ---------------------------------------------------------------------------

class _CardsTab extends ConsumerWidget {
  const _CardsTab({
    required this.cards,
    required this.query,
    required this.onQueryChanged,
    required this.onRemove,
  });

  final List<LearningCard> cards;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onRemove;

  bool _matches(LearningCard c, String q) {
    final needle = q.toLowerCase();
    return c.title.toLowerCase().contains(needle) ||
        c.takeaway.toLowerCase().contains(needle) ||
        c.topicTag.toLowerCase().contains(needle);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cards.isEmpty) {
      return const AppEmptyState(
        icon: Icons.menu_book_outlined,
        title: 'No saved cards yet',
        message: 'Long press any card to save it for later.',
      );
    }
    final filtered = query.isEmpty
        ? cards
        : cards.where((c) => _matches(c, query)).toList();
    final allTracks = ref.watch(allTracksProvider);
    final trackNameById = {for (final t in allTracks) t.id: t.name};

    final grouped = <String, List<LearningCard>>{};
    for (final card in filtered) {
      final name = trackNameById[card.trackId] ?? card.trackId;
      grouped.putIfAbsent(name, () => []).add(card);
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SearchField(
              hintText: 'Search saved cards',
              onChanged: onQueryChanged,
            ),
          ),
        ),
        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No matches for "$query"',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          )
        else
          for (final entry in grouped.entries) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(
                  entry.key,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary,
                        letterSpacing: 0.8,
                      ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final card = entry.value[index];
                  return _SavedCardItem(
                    card: card,
                    onDismiss: () => onRemove(card.id),
                  );
                },
                childCount: entry.value.length,
              ),
            ),
          ],
        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }
}

class _SavedCardItem extends StatelessWidget {
  const _SavedCardItem({required this.card, required this.onDismiss});

  final LearningCard card;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('card_${card.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error.withValues(alpha: 0.15),
        child:
            const Icon(Icons.bookmark_remove_rounded, color: AppColors.error),
      ),
      onDismissed: (_) => onDismiss(),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Text(card.emoji, style: const TextStyle(fontSize: 28)),
        title: Text(
          card.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              card.takeaway,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            DifficultyBadge(difficulty: card.difficulty),
          ],
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.textSecondary,
        ),
        onTap: () => context.push(AppRoutes.learnCard(card.id), extra: card),
        isThreeLine: true,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// News tab
// ---------------------------------------------------------------------------

class _NewsTab extends ConsumerWidget {
  const _NewsTab({
    required this.articles,
    required this.categories,
    required this.query,
    required this.onQueryChanged,
    required this.onRemove,
  });

  final List<NewsArticle> articles;
  final List<NewsCategory> categories;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onRemove;

  bool _matches(NewsArticle a, String q) {
    final needle = q.toLowerCase();
    return a.headline.toLowerCase().contains(needle) ||
        a.summary.toLowerCase().contains(needle) ||
        a.sourceName.toLowerCase().contains(needle);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (articles.isEmpty) {
      return const AppEmptyState(
        icon: Icons.bookmark_outline_rounded,
        title: 'No saved news yet',
        message: 'Tap "Save" on an article to bookmark it.',
      );
    }
    final filtered = query.isEmpty
        ? articles
        : articles.where((a) => _matches(a, query)).toList();
    final categoryByKey = {for (final c in categories) c.key: c};
    final user = ref.watch(userProvider);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SearchField(
              hintText: 'Search saved news',
              onChanged: onQueryChanged,
            ),
          ),
        ),
        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No matches for "$query"',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          )
        else
          SliverList.separated(
            itemCount: filtered.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              color: AppColors.textSecondary.withValues(alpha: 0.12),
            ),
            itemBuilder: (context, index) {
              final article = filtered[index];
              return Dismissible(
                key: ValueKey('news_${article.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: AppColors.error.withValues(alpha: 0.15),
                  child: const Icon(Icons.bookmark_remove_rounded,
                      color: AppColors.error),
                ),
                onDismissed: (_) => onRemove(article.id),
                child: NewsListTile(
                  article: article,
                  category: categoryByKey[article.categoryKey],
                  isRead: user.readNewsIds.contains(article.id),
                  onTap: () => context.push(
                    AppRoutes.newsDetail(article.id),
                    extra: article,
                  ),
                ),
              );
            },
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }
}

