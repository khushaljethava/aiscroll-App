import 'app_router.dart';

bool _routerReady = false;
String? _pendingArticleId;

/// Marks the router as ready and drains any deep-link queued during cold
/// start. Called from `app.dart` once the first frame has rendered.
void markRouterReady() {
  _routerReady = true;
  final pending = _pendingArticleId;
  if (pending != null) {
    _pendingArticleId = null;
    _go(pending);
  }
}

/// Navigates to the news article. Defers when the router isn't ready yet
/// (cold-start tap from a terminated-state notification).
void goToNewsArticle(String articleId) {
  if (articleId.isEmpty) return;
  if (!_routerReady) {
    _pendingArticleId = articleId;
    return;
  }
  _go(articleId);
}

void _go(String articleId) {
  appRouter.go(AppRoutes.newsDetail(articleId));
}
