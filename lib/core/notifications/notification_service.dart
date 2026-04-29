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
      'Random AI news drops from the 60 Second AI team.';

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

      // Use the dedicated stat icon (white silhouette on transparent
      // background). The launcher icon is not a valid notification icon
      // on Android 5+ and is silently rejected by some OEMs.
      const android = AndroidInitializationSettings('ic_stat_notification');
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
  ///
  /// On Android 13+ the OS only shows the runtime dialog once. If the user
  /// has already denied (or selected "Don't ask again"), this returns false
  /// without re-prompting — callers should surface a hint pointing the
  /// user to system settings.
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
      // If the user previously granted, skip the dialog entirely.
      final alreadyEnabled = await android.areNotificationsEnabled() ?? false;
      if (alreadyEnabled) return true;
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  /// Returns the current OS-level "notifications enabled" state without
  /// re-prompting. Use for UI badges that nudge the user to system
  /// settings when permission was permanently denied.
  Future<bool> areEnabled() async {
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? true;
    }
    // iOS doesn't expose a check without prompting; assume enabled.
    return true;
  }

  /// Schedules a daily repeating notification at [minutesSinceMidnight].
  /// Cancels any previously scheduled daily reminder first.
  ///
  /// Prefers `exactAllowWhileIdle` so doze mode doesn't push the fire
  /// hours past the user's chosen time. Falls back to inexact when the
  /// OS denies the SCHEDULE_EXACT_ALARM permission (Android 12+ users
  /// must enable "Alarms & reminders" manually in system settings).
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

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final canExact =
          await android?.canScheduleExactNotifications() ?? true;
      final mode = canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

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
        androidScheduleMode: mode,
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
