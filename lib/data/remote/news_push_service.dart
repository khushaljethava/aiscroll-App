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

  Future<void> init() async {
    if (_initialized) return;
    try {
      // 1. Permission. iOS prompts here; Android 13+ also requires it.
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // 2. iOS only: deliver alert/badge/sound while in the foreground.
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 3. Subscribe. Idempotent — safe on every cold start.
      await _messaging.subscribeToTopic(topic);

      // 4. Background / terminated. Re-registering here is harmless
      //    (the FCM plugin dedupes); the authoritative call is in
      //    `main.dart` before `runApp`.
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 5. Foreground messages — render via the shared NotificationService.
      //    FCM does not auto-display a banner when the app is in the
      //    foreground on Android, so this is the only path that does.
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // 6. User tapped a notification while the app was backgrounded.
      FirebaseMessaging.onMessageOpenedApp.listen((m) {
        final id = m.data['articleId'];
        if (id is String && id.isNotEmpty) goToNewsArticle(id);
      });

      // 7. App launched from a terminated state by tapping a notification.
      //    `goToNewsArticle` queues the id if the router isn't ready yet.
      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        final id = initial.data['articleId'];
        if (id is String && id.isNotEmpty) goToNewsArticle(id);
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

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final notif = message.notification;
    if (notif == null) return;
    final id = message.data['articleId'] as String?;
    if (id == null || id.isEmpty) return;
    await NotificationService.instance.showNewsBanner(
      title: notif.title ?? 'AIScroll',
      body: notif.body ?? '',
      articleId: id,
    );
  }
}

final newsPushServiceProvider = Provider<NewsPushService>((ref) {
  return NewsPushService();
});
