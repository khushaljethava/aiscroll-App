import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/news_model.dart';
import '../remote/news_service.dart';
import '../remote/periodic_sync_scheduler.dart';
import 'auth_provider.dart';

/// Immutable snapshot of the news the app should render right now.
class NewsState {
  final List<NewsArticle> articles;
  final List<NewsCategory> categories;
  final String? selectedCategoryKey; // null → "All"
  final DateTime? lastSyncedAt;
  final String? lastError;
  final bool refreshing;

  const NewsState({
    this.articles = const [],
    this.categories = const [],
    this.selectedCategoryKey,
    this.lastSyncedAt,
    this.lastError,
    this.refreshing = false,
  });

  /// Articles filtered by [selectedCategoryKey]; pinned items stay on top in
  /// the order the server sent them (server already orders by isPinned desc
  /// then publishedAt desc).
  List<NewsArticle> get visibleArticles {
    if (selectedCategoryKey == null) return articles;
    return articles
        .where((a) => a.categoryKey == selectedCategoryKey)
        .toList(growable: false);
  }

  NewsState copyWith({
    List<NewsArticle>? articles,
    List<NewsCategory>? categories,
    Object? selectedCategoryKey = _sentinel,
    DateTime? lastSyncedAt,
    Object? lastError = _sentinel,
    bool? refreshing,
  }) =>
      NewsState(
        articles: articles ?? this.articles,
        categories: categories ?? this.categories,
        selectedCategoryKey: identical(selectedCategoryKey, _sentinel)
            ? this.selectedCategoryKey
            : selectedCategoryKey as String?,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        lastError: identical(lastError, _sentinel)
            ? this.lastError
            : lastError as String?,
        refreshing: refreshing ?? this.refreshing,
      );

  static const _sentinel = Object();
}

class NewsNotifier extends StateNotifier<NewsState> {
  NewsNotifier(this._service) : super(const NewsState()) {
    _scheduler = PeriodicSyncScheduler(
      label: 'news',
      refresh: () async {
        await refresh();
        return state.lastError == null;
      },
      lastSyncedAt: () => state.lastSyncedAt,
      // News is fast-moving — pull every 2 minutes while foregrounded.
      interval: const Duration(minutes: 2),
      // Resume always refreshes anything older than 30 s. Tighter than that
      // races the periodic timer (resume fires, then periodic fires ~0 s
      // later); the in-flight guard absorbs the race but it's cleaner to
      // just let one win.
      staleThreshold: const Duration(seconds: 30),
    );
  }

  final NewsService _service;
  late final PeriodicSyncScheduler _scheduler;

  PeriodicSyncScheduler get scheduler => _scheduler;

  /// Reads cached JSON from SharedPreferences into in-memory state. Call
  /// once at boot before anything watches [newsProvider].
  Future<void> hydrateFromCache() async {
    await _service.hydrateFromCache();
    state = state.copyWith(
      articles: _service.articles,
      categories: _service.categories,
      lastSyncedAt: _service.lastSyncedAt,
    );
  }

  /// Network refresh. Never throws — on failure, keeps existing state and
  /// surfaces [lastError].
  Future<void> refresh() async {
    state = state.copyWith(refreshing: true);
    await _service.refreshFromNetwork();
    state = state.copyWith(
      articles: _service.articles,
      categories: _service.categories,
      lastSyncedAt: _service.lastSyncedAt,
      lastError: _service.lastError,
      refreshing: false,
    );
  }

  void selectCategory(String? key) {
    if (state.selectedCategoryKey == key) return;
    state = state.copyWith(selectedCategoryKey: key);
  }

  @override
  void dispose() {
    _scheduler.stop();
    super.dispose();
  }
}

final newsServiceProvider = Provider<NewsService>((ref) {
  final dio = ref.watch(authedDioFactoryProvider).attach(Dio());
  return NewsService(dio: dio);
});

final newsProvider =
    StateNotifierProvider<NewsNotifier, NewsState>((ref) {
  return NewsNotifier(ref.watch(newsServiceProvider));
});

/// Convenience: look up an article by id, returns null if not in cache.
final newsArticleByIdProvider =
    Provider.family<NewsArticle?, String>((ref, id) {
  final list = ref.watch(newsProvider.select((s) => s.articles));
  try {
    return list.firstWhere((a) => a.id == id);
  } catch (_) {
    return null;
  }
});

/// Convenience: resolve a category by key.
final newsCategoryByKeyProvider =
    Provider.family<NewsCategory?, String>((ref, key) {
  final list = ref.watch(newsProvider.select((s) => s.categories));
  try {
    return list.firstWhere((c) => c.key == key);
  } catch (_) {
    return null;
  }
});

/// Resolve a single article by id, falling back to the network when the
/// item isn't in the home-feed cache (notifications can deep-link to
/// articles older than the 30 most-recent the cache holds).
final newsArticleFetchProvider =
    FutureProvider.autoDispose.family<NewsArticle?, String>((ref, id) async {
  final cached = ref.watch(newsArticleByIdProvider(id));
  if (cached != null) return cached;
  return ref.read(newsServiceProvider).fetchById(id);
});
