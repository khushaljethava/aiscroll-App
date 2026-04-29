import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/router/deep_link.dart';

/// FCM background / terminated isolate entry point.
///
/// MUST be a top-level function (not a closure or instance method) and
/// MUST carry the `vm:entry-point` pragma so the Dart isolate can hand it
/// off to the background handler when the app is killed.
///
/// Currently a no-op: Android shows the system notification automatically
/// because the server sends both `notification` and `data` blocks. Future
/// analytics / cache-priming hooks belong here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Owns the FCM contract: subscribes the device to the `news` topic and
/// wires foreground / background / terminated handlers so notification
/// taps deep-link to the article.
///
/// All initialization is best-effort and never blocks UI. Errors degrade
/// gracefully — the rest of the app continues without push notifications.
class NewsPushService {
  NewsPushService({FirebaseMessaging? messaging})
      : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  /// Server-side FCM topic name. Must match `notifyTopic` in the admin's
  /// `news.pipeline` config (default: `"news"`).
  static const String topic = 'news';

  bool _initialized = false;

  /// Wires foreground / background / terminated handlers and re-subscribes
  /// the device to the `news` topic IFF the OS already considers the app
  /// authorized to post notifications. Does NOT show a permission dialog —
  /// see [requestPermissionAndSubscribe] for that.
  ///
  /// Safe to call on every cold start; idempotent.
  Future<void> init() async {
    if (_initialized) return;
    try {
      // iOS only: deliver alert/badge/sound while in the foreground.
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Background / terminated. Re-registering here is harmless
      // (the FCM plugin dedupes); the authoritative call is in
      // `main.dart` before `runApp`.
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Foreground messages — render via the shared NotificationService.
      // FCM does not auto-display a banner when the app is in the
      // foreground on Android, so this is the only path that does.
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // User tapped a notification while the app was backgrounded.
      FirebaseMessaging.onMessageOpenedApp.listen((m) {
        final id = m.data['articleId'];
        if (id is String && id.isNotEmpty) goToNewsArticle(id);
      });

      // App launched from a terminated state by tapping a notification.
      // `goToNewsArticle` queues the id if the router isn't ready yet.
      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        final id = initial.data['articleId'];
        if (id is String && id.isNotEmpty) goToNewsArticle(id);
      }

      // If a previous session already granted permission, make sure the
      // device is subscribed (FCM tokens rotate; topic state can drift).
      final settings = await _messaging.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        await _messaging.subscribeToTopic(topic);
      }

      // Debug helper: print the device-specific FCM token so a single
      // device can be targeted via the FCM v1 send API for testing.
      if (kDebugMode) {
        try {
          final token = await _messaging.getToken();
          debugPrint('FCM token: $token');
          debugPrint('Subscribed to topic: $topic');
        } catch (_) {
          // Silently ignore — token printing is debug-only convenience.
        }
      }

      _initialized = true;
    } catch (e, st) {
      debugPrint('NewsPushService.init failed (continuing): $e\n$st');
    }
  }

  /// Prompts the user for notification permission and subscribes the device
  /// to the `news` topic on success. Returns true when permission was
  /// granted (or was already granted).
  Future<bool> requestPermissionAndSubscribe() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
      if (granted) {
        await _messaging.subscribeToTopic(topic);
      }
      return granted;
    } catch (e, st) {
      debugPrint('NewsPushService.requestPermissionAndSubscribe failed: $e\n$st');
      return false;
    }
  }

  /// Unsubscribes from the topic. Permission state in the OS is unchanged —
  /// the user must revoke that themselves via system settings.
  Future<void> unsubscribe() async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
    } catch (e) {
      debugPrint('NewsPushService.unsubscribe failed: $e');
    }
  }

  /// Returns the current FCM device token (or null on error). Exposed for
  /// the in-app developer/support tooling — never invoke from production
  /// code paths because it can trigger a network round-trip.
  Future<String?> currentToken() async {
    try {
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    // Server may send notification-only, data-only, or both. Surface
    // anything that has either a title or body so a future server-side
    // payload change doesn't silently drop user-visible alerts.
    final notif = message.notification;
    final id = message.data['articleId'] as String?;
    final title =
        notif?.title ?? message.data['title'] as String? ?? '60 Second AI';
    final body = notif?.body ?? message.data['body'] as String? ?? '';
    if (title.isEmpty && body.isEmpty) return;
    await NotificationService.instance.showNewsBanner(
      title: title,
      body: body,
      articleId: id ?? '',
    );
  }
}

final newsPushServiceProvider = Provider<NewsPushService>((ref) {
  return NewsPushService();
});
