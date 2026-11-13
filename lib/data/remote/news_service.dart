import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../local/preferences_service.dart';
import '../models/news_model.dart';

/// Raw payload returned from [NewsService.fetchLatest].
class NewsFetchResult {
  final List<NewsArticle> items;
  final String? nextCursor;
  final DateTime serverTime;

  const NewsFetchResult({
    required this.items,
    required this.nextCursor,
    required this.serverTime,
  });
}

/// Outcome of [NewsService.fetchById]. Lets the UI distinguish a genuine
/// 404 ("article gone") from transient failures ("auth expired",
/// "network down") so the screen can offer the right recovery — Retry
/// for transient, "no longer available" only for genuine misses.
sealed class FetchByIdResult {
  const FetchByIdResult();
}

class FetchByIdSuccess extends FetchByIdResult {
  const FetchByIdSuccess(this.article);
  final NewsArticle article;
}

class FetchByIdNotFound extends FetchByIdResult {
  const FetchByIdNotFound();
}

class FetchByIdAuthError extends FetchByIdResult {
  const FetchByIdAuthError(this.statusCode);
  final int statusCode;
}

class FetchByIdNetworkError extends FetchByIdResult {
  const FetchByIdNetworkError(this.message);
  final String message;
}

/// Pulls news from the admin's public `/api/news` endpoint and caches the
/// latest page in SharedPreferences so the feed renders instantly on launch.
///
/// Configure the admin URL via:
///   flutter run --dart-define=ADMIN_API_URL=http://10.0.2.2:3000
///
/// When unset, the service is a no-op — cache data surfaces if present,
/// otherwise the feed is empty.
class NewsService {
  NewsService({Dio? dio, PreferencesService? prefs})
      : _dio = dio ?? Dio(),
        _prefs = prefs ?? PreferencesService.instance;

  final Dio _dio;
  final PreferencesService _prefs;

  // Raw env value as supplied at build time (`--dart-define=ADMIN_API_URL=…`).
  // Trailing slashes are stripped by [_baseUrl] so a value like
  // `https://host/` doesn't compose into `https://host//api/news` (which
  // Vercel and other hosting layers rewrite into a 308/404).
  static const _rawBaseUrl = String.fromEnvironment('ADMIN_API_URL');
  static const _defaultLimit = 30;

  static String get _baseUrl => _rawBaseUrl.endsWith('/')
      ? _rawBaseUrl.substring(0, _rawBaseUrl.length - 1)
      : _rawBaseUrl;

  List<NewsArticle> _articles = const [];
  List<NewsCategory> _categories = const [];
  DateTime? _lastSyncedAt;
  String? _lastError;

  bool get isAdminConfigured => _rawBaseUrl.isNotEmpty;
  List<NewsArticle> get articles => _articles;
  List<NewsCategory> get categories => _categories;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  String? get lastError => _lastError;

  /// Synchronously hydrates in-memory state from SharedPreferences. Call once
  /// at boot before anything reads news providers.
  Future<void> hydrateFromCache() async {
    final articlesJson = _prefs.loadNewsArticlesJsonSync();
    if (articlesJson != null) {
      try {
        final list = jsonDecode(articlesJson) as List;
        _articles = list
            .whereType<Map>()
            .map((m) => NewsArticle.fromMap(Map<String, dynamic>.from(m)))
            .toList();
      } catch (e) {
        debugPrint('NewsService: cached articles corrupt ($e); dropping.');
        await _prefs.clearNewsArticles();
      }
    }
    final categoriesJson = _prefs.loadNewsCategoriesJsonSync();
    if (categoriesJson != null) {
      try {
        final list = jsonDecode(categoriesJson) as List;
        _categories = list
            .whereType<Map>()
            .map((m) => NewsCategory.fromMap(Map<String, dynamic>.from(m)))
            .toList();
      } catch (e) {
        debugPrint('NewsService: cached categories corrupt ($e); dropping.');
        await _prefs.clearNewsCategories();
      }
    }
    _lastSyncedAt = _prefs.loadNewsLastSyncedAtSync();
  }

  /// Fetches the latest page of news + the current category taxonomy. On
  /// success, replaces the in-memory lists and persists to cache.
  /// Never throws — errors surface via [lastError].
  Future<bool> refreshFromNetwork() async {
    if (!isAdminConfigured) {
      _lastError =
          'ADMIN_API_URL not configured; staying on cached data.';
      // Diagnostic: explicit log so a forgotten `--dart-define=ADMIN_API_URL=…`
      // is obvious in logcat. Without this, the only signal is `_lastError`
      // which the UI gates behind a 24-h staleness check.
      debugPrint('NewsService: ADMIN_API_URL is empty — '
          'rebuild with --dart-define=ADMIN_API_URL=<host>');
      return false;
    }
    // Diagnostic: surface the composed URL to logcat. Cheap and easy to
    // strip later — but invaluable when a misconfigured `--dart-define`
    // sends requests to the wrong host and the only visible symptom is
    // a 404 banner.
    debugPrint('NewsService: fetching $_baseUrl/api/news?limit=$_defaultLimit');
    try {
      final futures = await Future.wait([
        _dio.get<dynamic>(
          '$_baseUrl/api/news',
          queryParameters: {'limit': _defaultLimit},
          options: _reqOptions(),
        ),
        _dio.get<dynamic>(
          '$_baseUrl/api/news/categories',
          options: _reqOptions(),
        ),
      ]);

      final articlesResp = futures[0];
      final categoriesResp = futures[1];

      if (articlesResp.statusCode != 200) {
        // Include the URI in the error so a future stale dart-define is
        // self-diagnosing — the banner shows `…from https://wrong-host/api/news`.
        _lastError = 'News fetch failed: HTTP ${articlesResp.statusCode} '
            'from ${articlesResp.requestOptions.uri}';
        return false;
      }
      if (categoriesResp.statusCode != 200) {
        _lastError =
            'Category fetch failed: HTTP ${categoriesResp.statusCode} '
            'from ${categoriesResp.requestOptions.uri}';
        return false;
      }

      final articlesBody = articlesResp.data;
      final categoriesBody = categoriesResp.data;
      if (articlesBody is! Map<String, dynamic> ||
          categoriesBody is! Map<String, dynamic>) {
        _lastError = 'News response was not a JSON object';
        return false;
      }

      final articlesData = articlesBody['data'];
      final categoriesData = categoriesBody['data'];
      if (articlesData is! List || categoriesData is! List) {
        _lastError = 'News response missing data array';
        return false;
      }

      final decodedArticles = articlesData
          .whereType<Map>()
          .map((m) => NewsArticle.fromMap(Map<String, dynamic>.from(m)))
          .toList();
      final decodedCategories = categoriesData
          .whereType<Map>()
          .map((m) => NewsCategory.fromMap(Map<String, dynamic>.from(m)))
          .toList();

      _articles = decodedArticles;
      _categories = decodedCategories;
      _lastSyncedAt = DateTime.now();
      _lastError = null;

      // Diagnostic fingerprint: lets you tell from logcat whether the
      // server is producing new content vs. echoing the same payload
      // every poll.
      debugPrint('NewsService: refreshed ${decodedArticles.length} articles, '
          'top id=${decodedArticles.isEmpty ? "<empty>" : decodedArticles.first.id} '
          'top published=${decodedArticles.isEmpty ? "" : decodedArticles.first.publishedAt.toIso8601String()}');

      await _prefs.saveNewsArticlesJson(
        jsonEncode(decodedArticles.map((a) => a.toMap()).toList()),
      );
      await _prefs.saveNewsCategoriesJson(
        jsonEncode(decodedCategories.map((c) => c.toMap()).toList()),
      );
      await _prefs.saveNewsLastSyncedAt(_lastSyncedAt!);
      return true;
    } on DioException catch (e) {
      _lastError = 'Network error: ${e.message ?? e.type.name}';
      return false;
    } catch (e) {
      _lastError = 'Unexpected error: $e';
      return false;
    }
  }

  /// Fetches a single article by id. Used by the deep-link path when the
  /// article isn't in the 30-item home-feed cache. Returns a typed result
  /// so the UI can offer Retry for transient failures and only show
  /// "no longer available" for genuine 404s.
  Future<FetchByIdResult> fetchById(String id) async {
    if (!isAdminConfigured || id.isEmpty) {
      return const FetchByIdNotFound();
    }
    try {
      final resp = await _dio.get<dynamic>(
        '$_baseUrl/api/news/${Uri.encodeComponent(id)}',
        options: _reqOptions(),
      );
      final code = resp.statusCode ?? 0;
      if (code == 404) return const FetchByIdNotFound();
      if (code == 401 || code == 403) return FetchByIdAuthError(code);
      if (code != 200) {
        return FetchByIdNetworkError('HTTP $code');
      }
      final body = resp.data;
      if (body is! Map<String, dynamic>) {
        return const FetchByIdNetworkError('Bad response shape');
      }
      if (body['success'] != true) {
        return const FetchByIdNotFound();
      }
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        return const FetchByIdNotFound();
      }
      return FetchByIdSuccess(NewsArticle.fromMap(data));
    } on DioException catch (e) {
      debugPrint('NewsService.fetchById($id) DioException: ${e.message}');
      // 401s now throw (so the interceptor can refresh + retry); one that
      // survives the retry is still an auth failure, not a network one.
      final code = e.response?.statusCode;
      if (code == 401) return FetchByIdAuthError(code!);
      return FetchByIdNetworkError(e.message ?? e.type.name);
    } catch (e) {
      debugPrint('NewsService.fetchById($id) failed: $e');
      return FetchByIdNetworkError('$e');
    }
  }

  Options _reqOptions() => Options(
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        // 401 must surface as a DioException so the auth interceptor
          // refreshes the token and retries.
          validateStatus: (s) => s != null && s < 500 && s != 401,
      );
}
