import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../router/deep_link.dart';

/// Wraps `flutter_local_notifications` so the rest of the app can toggle
/// reminders without touching platform-specific init/permission plumbing.
///
/// The service is a singleton because the plugin holds process-level state
/// (channels, registered handlers). Architect's call: keep the provider as
/// state-of-record and have this service own the OS contract — profile is
/// the source of truth, we react to mutations from `UserNotifier`.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const int _dailyReminderId = 1001;
  static const String _channelId = 'daily_reminder';
  static const String _channelName = 'Daily Reminder';
  static const String _channelDescription =
      'Nudge to keep your learning streak alive.';

  // News push channel — server-pushed FCM messages reference this id via
  // `channelId: "news"`, and we render the foreground banner here too.
  static const String newsChannelId = 'news';
  static const String _newsChannelName = 'AI News';
  static const String _newsChannelDescription =
      'Random AI news drops from the AIScroll team.';

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      tz_data.initializeTimeZones();
      // Best-effort local tz detection. For production, add flutter_native_timezone.
      // Falls back to UTC if the platform name doesn't match an IANA zone.
      final localName = DateTime.now().timeZoneName;
      try {
        tz.setLocalLocation(tz.getLocation(localName));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('UTC'));
      }

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        // Permissions requested explicitly on toggle, not at init.
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: (response) {
          // Foreground-banner tap → deep-link to the article. The payload
          // is the news article id (set in `showNewsBanner`). Daily
          // reminders use no payload, so they fall through silently.
          final payload = response.payload;
          if (payload == null || payload.isEmpty) return;
          goToNewsArticle(payload);
        },
      );
      // News channel — must exist before any FCM payload arrives.
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              newsChannelId,
              _newsChannelName,
              description: _newsChannelDescription,
              importance: Importance.high,
              playSound: true,
            ),
          );
      _initialized = true;
    } catch (e, st) {
      debugPrint('NotificationService init failed: $e\n$st');
      // Swallow: notifications are best-effort. App continues to work.
    }
  }

  /// Prompts for permission. Returns true if granted.
  Future<bool> requestPermission() async {
    await initialize();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? true;
    }
    return true;
  }

  /// Schedules a daily repeating notification at [minutesSinceMidnight].
  /// Cancels any previously scheduled daily reminder first.
  Future<void> scheduleDaily(int minutesSinceMidnight) async {
    await initialize();
    await cancel();

    try {
      final now = tz.TZDateTime.now(tz.local);
      var firstFire = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        minutesSinceMidnight ~/ 60,
        minutesSinceMidnight % 60,
      );
      if (!firstFire.isAfter(now)) {
        firstFire = firstFire.add(const Duration(days: 1));
      }

      await _plugin.zonedSchedule(
        _dailyReminderId,
        'Time to learn 🤖',
        _randomTagline(),
        firstFire,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e, st) {
      debugPrint('NotificationService.scheduleDaily failed: $e\n$st');
    }
  }

  Future<void> cancel() async {
    await initialize();
    try {
      await _plugin.cancel(_dailyReminderId);
    } catch (e) {
      debugPrint('NotificationService.cancel failed: $e');
    }
  }

  /// Renders a foreground banner for a news push. FCM does not auto-display
  /// a banner when the app is in the foreground on Android, so we mirror
  /// the system-tray notification via the local-notifications plugin.
  ///
  /// [articleId] is stored as the payload so taps deep-link via
  /// `onDidReceiveNotificationResponse`.
  Future<void> showNewsBanner({
    required String title,
    required String body,
    required String articleId,
  }) async {
    await initialize();
    try {
      await _plugin.show(
        // Stable id so re-deliveries collapse rather than stack.
        articleId.hashCode & 0x7fffffff,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            newsChannelId,
            _newsChannelName,
            channelDescription: _newsChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: articleId,
      );
    } catch (e, st) {
      debugPrint('NotificationService.showNewsBanner failed: $e\n$st');
    }
  }

  static const List<String> _taglines = [
    "Don't break your streak — one card today.",
    'Two minutes is all it takes.',
    "Your daily AI dose is ready.",
    'Knowledge compounds. Today\'s the day.',
    'A quick card keeps your streak alive.',
  ];

  String _randomTagline() {
    final idx = DateTime.now().millisecondsSinceEpoch % _taglines.length;
    return _taglines[idx];
  }
}
