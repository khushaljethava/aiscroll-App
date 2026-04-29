import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'app.dart';
import 'core/notifications/notification_service.dart';
import 'data/local/preferences_service.dart';
import 'data/remote/news_push_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PreferencesService.init();
  await _initFirebaseAppCheck();
  // FCM background / terminated handler must be registered before runApp
  // so the OS can dispatch to it on cold starts from a notification tap.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  // Notifications init is best-effort; failures never block app start.
  await NotificationService.instance.initialize();
  // AdMob — fire-and-forget. We don't await because initialization can
  // take a few seconds and we don't want to block the splash. Ad widgets
  // call `MobileAds.instance.initialize()` themselves on first load if
  // this hasn't completed yet (it's idempotent).
  // ignore: discarded_futures
  MobileAds.instance.initialize();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const ProviderScope(child: SixtySecondAIApp()));
}

/// Initialise Firebase + App Check. Both are required for the admin API
/// auth flow (the Flutter client exchanges an App Check token for an
/// 60 Second AI client JWT in [AuthService]).
///
/// Failures here are logged and swallowed — the app keeps running in
/// offline-first mode with whatever is already in the cache. That's
/// intentional: device-attestation is a hardening layer, not a
/// precondition for the user to see content.
Future<void> _initFirebaseAppCheck() async {
  try {
    // Pass explicit options so initialization doesn't depend solely on
    // the Gradle plugin parsing `google-services.json` at build time.
    // iOS isn't configured in `firebase_options.dart` yet, so guard.
    if (defaultTargetPlatform == TargetPlatform.android) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      await Firebase.initializeApp();
    }
    await FirebaseAppCheck.instance.activate(
      // Debug builds: let Firebase print a debug token on first launch so
      // developers can register it in the console.
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode
          ? AppleProvider.debug
          : AppleProvider.appAttestWithDeviceCheckFallback,
    );
  } catch (e, st) {
    debugPrint('Firebase App Check init failed (continuing offline): $e\n$st');
  }
}
