import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../local/preferences_service.dart';

/// Firebase Analytics wrapper. Fire-and-forget, never throws, never blocks UI.
///
/// Behavior:
///   - All log calls short-circuit when Firebase isn't initialised (e.g. iOS
///     without `GoogleService-Info.plist`) or the user opted out.
///   - The opt-out preference is persisted in [PreferencesService] under
///     `analytics.enabled`. Default = `!kDebugMode` so debug builds don't
///     pollute prod data unless DebugView is intentionally turned on.
///   - Param keys are kept ≤ 40 chars and string values ≤ 100 chars to
///     respect Firebase's reserved-event-name and length constraints.
class AnalyticsService {
  AnalyticsService({FirebaseAnalytics? analytics, PreferencesService? prefs})
      : _analytics = analytics ?? FirebaseAnalytics.instance,
        _prefs = prefs ?? PreferencesService.instance;

  final FirebaseAnalytics _analytics;
  final PreferencesService _prefs;
  final bool _firebaseAvailable = Firebase.apps.isNotEmpty;

  static const _kEnabledPref = 'analytics.enabled';

  /// Mirrors the `analytics.enabled` SharedPreference. Read once on [init];
  /// updated by [setEnabled] thereafter.
  bool _enabled = true;

  bool get isEnabled => _enabled;
  bool get isFirebaseAvailable => _firebaseAvailable;

  /// NavigatorObserver that auto-logs `screen_view` for every PageRoute push.
  /// Plug into `GoRouter(observers: [...])`.
  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  /// Reads the persisted opt-out and applies it to the SDK. Safe to call from
  /// app boot before `runApp`; failures degrade to "analytics off".
  Future<void> init() async {
    _enabled = _prefs.getBool(_kEnabledPref) ?? !kDebugMode;
    if (!_firebaseAvailable) return;
    try {
      await _analytics.setAnalyticsCollectionEnabled(_enabled);
    } catch (e) {
      debugPrint('AnalyticsService.init failed: $e');
    }
  }

  /// Toggles collection. Persisted across launches.
  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    await _prefs.setBool(_kEnabledPref, enabled);
    if (!_firebaseAvailable) return;
    try {
      await _analytics.setAnalyticsCollectionEnabled(enabled);
    } catch (e) {
      debugPrint('AnalyticsService.setEnabled failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Identity
  // ---------------------------------------------------------------------------

  /// Stamps the active user id. Pass null on sign-out / guest mode.
  Future<void> setUserId(String? id) =>
      _safe(() => _analytics.setUserId(id: id));

  /// Sets a Firebase user property. Values must be ≤ 36 chars.
  Future<void> setUserProperty(String name, String? value) {
    final clipped = value == null || value.length <= 36
        ? value
        : value.substring(0, 36);
    return _safe(() => _analytics.setUserProperty(name: name, value: clipped));
  }

  // ---------------------------------------------------------------------------
  // Generic event API
  // ---------------------------------------------------------------------------

  /// Logs a custom event. Param values are coerced to Firebase-supported
  /// types (`String`, `num`); booleans become 0/1.
  Future<void> logEvent(
    String name, {
    Map<String, Object?> params = const {},
  }) async {
    if (!_enabled || !_firebaseAvailable) return;
    try {
      await _analytics.logEvent(
        name: name,
        parameters: _sanitize(params),
      );
    } catch (e) {
      debugPrint('AnalyticsService.logEvent($name) failed: $e');
    }
  }

  /// Manually records a screen view. The router observer handles route
  /// pushes automatically — call this only from screens that don't push a
  /// new route (e.g. tab switches inside a shell).
  Future<void> logScreenView({required String name, String? screenClass}) =>
      _safe(() => _analytics.logScreenView(
            screenName: name,
            screenClass: screenClass,
          ));

  // ---------------------------------------------------------------------------
  // Named wrappers — mirror TelemetryService so call-sites stay terse.
  // ---------------------------------------------------------------------------

  Future<void> logSignUp({required String method}) =>
      _safe(() => _analytics.logSignUp(signUpMethod: method));

  Future<void> logLogin({required String method}) =>
      _safe(() => _analytics.logLogin(loginMethod: method));

  Future<void> logSessionStart() => logEvent('session_start');

  Future<void> logTutorialBegin() => _safe(_analytics.logTutorialBegin);

  Future<void> logTutorialComplete() => _safe(_analytics.logTutorialComplete);

  Future<void> logCardViewed(
    String cardId, {
    int dwellMs = 0,
    bool wasDue = false,
  }) =>
      logEvent('card_viewed', params: {
        'card_id': cardId,
        'dwell_ms': dwellMs,
        'was_due': wasDue,
      });

  Future<void> logCardLearned(String cardId) =>
      logEvent('card_learned', params: {'card_id': cardId});

  Future<void> logQuizAnswered({
    required String quizId,
    required String cardId,
    required bool correct,
    required int selected,
  }) =>
      logEvent('quiz_answered', params: {
        'quiz_id': quizId,
        'card_id': cardId,
        'correct': correct,
        'selected': selected,
      });

  Future<void> logXp(int amount, String source) =>
      logEvent('xp_awarded', params: {'amount': amount, 'source': source});

  Future<void> logStreakDay(int streak) =>
      logEvent('streak_day', params: {'streak': streak});

  Future<void> logTrackStarted(String trackId) =>
      logEvent('track_started', params: {'track_id': trackId});

  Future<void> logTrackCompleted(String trackId) =>
      logEvent('track_completed', params: {'track_id': trackId});

  Future<void> logNewsOpened(String articleId, {String source = 'list'}) =>
      logEvent('news_opened',
          params: {'article_id': articleId, 'source': source});

  Future<void> logNewsRead(String articleId) =>
      logEvent('news_read', params: {'article_id': articleId});

  Future<void> logNewsBookmark(String articleId, {required bool saved}) =>
      logEvent(saved ? 'news_bookmark_add' : 'news_bookmark_remove',
          params: {'article_id': articleId});

  Future<void> logNewsShare(String articleId) => _safe(
        () => _analytics.logShare(
          contentType: 'news_article',
          itemId: articleId,
          method: 'system_sheet',
        ),
      );

  Future<void> logNewsSourceOpen(String articleId) =>
      logEvent('news_source_open', params: {'article_id': articleId});

  Future<void> logNotificationOpen({String? articleId, String topic = 'news'}) =>
      logEvent('notification_open', params: {
        'topic': topic,
        if (articleId != null && articleId.isNotEmpty) 'article_id': articleId,
      });

  Future<void> logRewardedAdRedeemed(String reward) =>
      logEvent('rewarded_ad_redeemed', params: {'reward': reward});

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<void> _safe(Future<void> Function() op) async {
    if (!_enabled || !_firebaseAvailable) return;
    try {
      await op();
    } catch (e) {
      debugPrint('AnalyticsService op failed: $e');
    }
  }

  /// Firebase only accepts `String` and `num` param values. Booleans become
  /// `0`/`1` and other types fall through to `toString()`.
  Map<String, Object> _sanitize(Map<String, Object?> raw) {
    final out = <String, Object>{};
    raw.forEach((key, value) {
      if (value == null) return;
      if (value is num) {
        out[key] = value;
      } else if (value is bool) {
        out[key] = value ? 1 : 0;
      } else if (value is String) {
        out[key] = value.length <= 100 ? value : value.substring(0, 100);
      } else {
        final s = value.toString();
        out[key] = s.length <= 100 ? s : s.substring(0, 100);
      }
    });
    return out;
  }
}
