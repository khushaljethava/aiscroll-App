# Implementation Plan: Notification Not Working — Diagnose & Fix

> **Multi-model note:** `~/.claude/bin/codeagent-wrapper` and the codex/gemini analyzer prompts are not installed in this environment. Codex + Gemini parallel analysis was skipped. This plan was synthesized by Claude alone after a deep read of the notification-related code (`lib/main.dart`, `lib/app.dart`, `lib/core/notifications/notification_service.dart`, `lib/data/remote/news_push_service.dart`, `lib/data/providers/user_provider.dart`, `lib/data/models/user_model.dart`, `android/app/src/main/AndroidManifest.xml`, `android/app/proguard-rules.pro`, `android/app/build.gradle.kts`, `android/app/google-services.json`, `firebase.json`, `lib/firebase_options.dart`, `pubspec.yaml`). No SESSION_ID is included.

## Task Type
- [x] **Frontend (Flutter / Dart + Android native config)**
- [ ] Backend
- [ ] Fullstack

The user reports: **"Notification is not working, not receiving any notifications"**. This covers two distinct subsystems that share zero runtime state but feel like one feature to the user:

| Subsystem | Trigger | Code path |
|---|---|---|
| **Daily local reminder** | Profile → toggle "Daily reminder" ON | `UserNotifier.setNotificationsEnabled(true)` → `NotificationService.scheduleDaily(...)` (uses `flutter_local_notifications`, channel `daily_reminder`) |
| **News push (FCM)** | Server posts to `news` topic | `NewsPushService.init()` (subscribes) + foreground/background/terminated handlers in same file; foreground re-rendered via `NotificationService.showNewsBanner(...)` (channel `news`) |

The bug could be in either subsystem (or both). Phase 1 of this plan is **diagnosis** to localize the failure; Phase 2 applies targeted fixes for the most likely root causes; Phase 3 is hardening so the next regression is harder.

---

## Root-Cause Hypotheses (ranked by likelihood)

Drawn directly from the code under inspection. Each cell labels a hypothesis, the file/line that sources it, and the test that confirms or refutes it.

### H1 (HIGH) — Server is sending data-only payload, so background/terminated state shows nothing
**File:** `lib/data/remote/news_push_service.dart:18`
**Why:** `firebaseMessagingBackgroundHandler` is a **no-op**. The comment on line 16-18 admits this works only "because the server sends both `notification` and `data` blocks". If the server changed to data-only (or never actually sent the `notification` block), Android will not auto-display anything in background/terminated state. Foreground would also fail because `_onForegroundMessage` (line 100-110) early-returns when `message.notification == null`.
**Test:** Send a test message via FCM console with **only a `data` block** vs **`notification + data` block**. The latter should appear; the former will not. Also run the app in foreground and watch `flutter logs`: a missing `notification` block surfaces as `_onForegroundMessage` exiting at line 102.

### H2 (HIGH) — POST_NOTIFICATIONS runtime permission denied (Android 13+) and never re-prompted
**Files:** `lib/data/remote/news_push_service.dart:42-46`, `lib/core/notifications/notification_service.dart:88-107`
**Why:** Android 13+ requires runtime grant of `POST_NOTIFICATIONS`. `NewsPushService.init()` calls `_messaging.requestPermission(alert, badge, sound)` once at app start. If the user dismisses or denies, **no further prompt is ever issued** by either `NewsPushService` or `NotificationService`. The toggle in profile only requests permission for the daily reminder via `requestNotificationsPermission()` — and even that returns the cached "denied" without re-prompting on Android 13+ if the user already denied once.
**Test:** Run `adb shell dumpsys notification --noredact | grep -A3 com.kj.aiscroll` (look for `Disabled effects: ALERT`) or `adb shell cmd notification get_perms <user_id> com.kj.aiscroll`. Or in Android Settings → Apps → 60 Second AI → Notifications, verify "Allow notifications" is ON.

### H3 (MEDIUM) — Missing notification small-icon resource → Android silently drops the notification on some OEMs
**Files:** `android/app/src/main/AndroidManifest.xml` (no `default_notification_icon` meta-data), `android/app/src/main/res/drawable/` (only `launch_background.xml` — no `ic_stat_*` or notification icon)
**Why:** FCM payloads with a `notification` block need a small icon. When `default_notification_icon` meta-data is missing, FCM falls back to the app launcher icon (`@mipmap/ic_launcher`). That works on stock Android but **fails silently on some OEMs** (Xiaomi MIUI, Huawei EMUI, OnePlus OxygenOS) — no notification appears, no error logged. Even when it works, it shows as a white square / grey blob because launcher icons are not Android-spec notification icons (which must be monochrome silhouettes per Android 5+).
**Test:** `adb logcat | grep -i "Notification\|FCM\|NotificationManager"` while triggering a push. Look for `Bad notification posted from package … Couldn't expand RemoteViews` or icon-related warnings.

### H4 (MEDIUM) — `Firebase.initializeApp()` called without `DefaultFirebaseOptions.currentPlatform`, fragile on Android, broken on iOS
**File:** `lib/main.dart:50`
**Why:** `await Firebase.initializeApp();` (no options arg) relies on Gradle's `com.google.gms.google-services` plugin generating values from `google-services.json`. The plugin **is** applied (`android/app/build.gradle.kts:7`) and the JSON exists, so this *should* work on Android — but if `_initFirebaseAppCheck()` ever fails (e.g., transient Play Services error), the catch block swallows it and the app continues with no Firebase. `FirebaseMessaging.onBackgroundMessage` on `main.dart:20` then has no Firebase to register against. **On iOS, `firebase_options.dart` throws `UnsupportedError` for iOS** — so iOS users get zero notifications regardless.
**Test:** Look at `flutter logs` on cold start for `Firebase App Check init failed (continuing offline)`. If present, push will not work for that session.

### H5 (MEDIUM) — Daily reminder uses `inexactAllowWhileIdle` + `matchDateTimeComponents.time` → Doze mode swallows the alarm
**File:** `lib/core/notifications/notification_service.dart:144`
**Why:** On Android 12+, doze mode can defer inexact alarms by hours; with `matchDateTimeComponents.time` (daily-repeating), a missed fire often slides into "tomorrow's slot". Manifest declares `SCHEDULE_EXACT_ALARM` and `USE_EXACT_ALARM` but the code uses `AndroidScheduleMode.inexactAllowWhileIdle`, so neither permission is consumed. Aggressive OEM battery optimizers (MIUI, Samsung Game Mode, etc.) compound this.
**Test:** Toggle daily reminder ON, set the time to "5 minutes from now". Wait 10 minutes with the screen off. If nothing fires but a foreground refresh shows the schedule, this is the cause. `adb shell dumpsys alarm | grep -A3 com.kj.aiscroll` will list the next-fire time.

### H6 (LOW) — FCM token / topic subscription failing silently
**File:** `lib/data/remote/news_push_service.dart:56`, `:84-92`
**Why:** `subscribeToTopic('news')` is awaited but its result is never inspected; failures land in the outer catch and are debug-printed only. `getToken()` is wrapped in a `kDebugMode` block — the production app never logs the token, so there is no way to verify the device is actually addressable from the FCM Console.
**Test:** Run debug build, watch `flutter logs` for `FCM token: ...` and `Subscribed to topic: news`. If the token line is missing or token is empty, the device is not registered.

### H7 (LOW) — `NewsPushService.init()` is called in `addPostFrameCallback` step 8 but only via `Provider`; if no widget reads it, the provider is built lazily
**File:** `lib/app.dart:118`
**Why:** `ref.read(newsPushServiceProvider).init();` does run, but the unawaited future swallows exceptions. If `init()` throws *before* registering the foreground listener (e.g., `requestPermission` throws on a virtual device without Play Services), no listener is ever attached.
**Test:** Add a `debugPrint('FCM init complete')` at the end of `init()` and confirm it prints on every cold start.

### H8 (LOW) — News channel created on every cold start, but ProGuard might be stripping `flutter_local_notifications` boot receiver
**File:** `android/app/proguard-rules.pro` (no `flutter_local_notifications` keep rule), `android/app/src/main/AndroidManifest.xml:50-57` (boot receiver declared)
**Why:** R8 with `isMinifyEnabled = true` (release builds) can strip `com.dexterous.flutterlocalnotifications.*` classes if no keep rule covers them. The boot receiver would then crash on `BOOT_COMPLETED` and the daily reminder wouldn't survive a reboot.
**Test:** Build release, install via `flutter install --release`, schedule a reminder, reboot the device, check whether the next fire occurs.

---

## Phase 1 — Diagnosis (run before changing any code)

These are observations the user must perform; results dictate which Phase 2 steps apply.

### D1. Capture the user's environment
Ask for / observe:
- Android version (Settings → About phone)
- OEM (Samsung, Xiaomi, OnePlus, Pixel, etc.)
- App version + build mode (debug or release; via `flutter --version` + how it was installed)
- Whether **either** subsystem fails or only one (daily reminder vs FCM news push)

### D2. Read the device's notification permission state
```bash
adb shell dumpsys notification --noredact | grep -B1 -A8 com.kj.aiscroll
```
Look for `Disabled effects: ALERT` or `importance=NONE`. If present → **H2 is the cause**.

### D3. Verify FCM token + subscription
Run a debug build with `flutter run` and capture the logcat:
```bash
flutter logs | grep -iE "FCM|Notification|Firebase"
```
Expected lines (from `news_push_service.dart:84-91`):
```
flutter: FCM token: <long base64-ish string>
flutter: Subscribed to topic: news
```
If the token line is **missing** → H6 or H7. If it appears but a test push never arrives → H1 or H3.

### D4. Send a controlled test push
Use Firebase Console → Cloud Messaging → New Notification:
- **Test 1:** "Notification" block ONLY (no `data`) → expect a system tray entry (validates the channel + icon)
- **Test 2:** "Notification + data" block with `data.articleId = "<a real article id from the cache>"` → expect a foreground banner if the app is open, system tray if backgrounded, and tapping deep-links to the article
- **Test 3:** Data-only payload → expect **nothing** in background; foreground also nothing because `_onForegroundMessage` early-returns. This confirms the contract: server **must** send `notification` block.

### D5. Verify the daily reminder
1. Toggle "Daily reminder" ON in profile (force a permission prompt on first try).
2. Set time 3 minutes ahead.
3. Background the app, screen off.
4. Wait 10 minutes.
5. Check `adb shell dumpsys alarm | grep -A3 com.kj.aiscroll`.
6. If alarm is present but never fires → H5 (doze).

---

## Phase 2 — Fix Steps

> Apply the steps that match the diagnosis. Many are independent and can be done in parallel; sequence shown is dependency order.

### Step 1 — Add notification small-icon (fixes H3)
**Files:**
- New: `android/app/src/main/res/drawable-mdpi/ic_stat_notification.png` (24x24, white silhouette + transparent background)
- New: `android/app/src/main/res/drawable-hdpi/ic_stat_notification.png` (36x36)
- New: `android/app/src/main/res/drawable-xhdpi/ic_stat_notification.png` (48x48)
- New: `android/app/src/main/res/drawable-xxhdpi/ic_stat_notification.png` (72x72)
- New: `android/app/src/main/res/drawable-xxxhdpi/ic_stat_notification.png` (96x96)
- Modify: `android/app/src/main/AndroidManifest.xml`

**Pseudo-change to manifest** (add inside `<application>`, near the existing FCM meta-data on lines 41-43):
```xml
<meta-data
    android:name="com.google.firebase.messaging.default_notification_icon"
    android:resource="@drawable/ic_stat_notification" />
<meta-data
    android:name="com.google.firebase.messaging.default_notification_color"
    android:resource="@color/notification_color" />
```
And add `<color name="notification_color">#5B21B6</color>` to `android/app/src/main/res/values/colors.xml`.

**Pseudo-change to local-notifications side** (`lib/core/notifications/notification_service.dart:49`):
```dart
const android = AndroidInitializationSettings('ic_stat_notification');
```
…and same `icon:` parameter inside both `AndroidNotificationDetails(...)` instances (`scheduleDaily` and `showNewsBanner`).

**How to generate icons:** Use Android Studio → right-click `res/drawable` → New → Image Asset → Notification Icons → use `logo.png` as source. Or run `flutter pub run flutter_launcher_icons` after adding a `notification_icon:` block — but `flutter_launcher_icons` does not generate stat icons, so manual generation is the cleaner route.

**Verification:** Send a test FCM push from the console; the icon should appear as a sharp monochrome silhouette in the status bar.

---

### Step 2 — Re-prompt for POST_NOTIFICATIONS when toggle is flipped after a denial (fixes H2)
**File:** `lib/core/notifications/notification_service.dart:88-107`
**Operation:** Modify `requestPermission()` to detect the "permanently denied" state on Android and surface a hint that the user must enable in system settings.

**Pseudo-code:**
```dart
Future<bool> requestPermission() async {
  await initialize();
  // iOS path unchanged
  final ios = _plugin.resolvePlatformSpecificImplementation<
      IOSFlutterLocalNotificationsPlugin>();
  if (ios != null) {
    final granted = await ios.requestPermissions(alert: true, badge: true, sound: true);
    return granted ?? false;
  }
  final android = _plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  if (android != null) {
    // Check first — on Android 13+ this returns false if denied permanently.
    final alreadyEnabled = await android.areNotificationsEnabled() ?? false;
    if (alreadyEnabled) return true;
    final granted = await android.requestNotificationsPermission();
    return granted ?? false;
  }
  return true;
}

/// Returns the current OS-level state without re-prompting. Use this for
/// UI badges that nudge the user to system settings.
Future<bool> areEnabled() async {
  await initialize();
  final android = _plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  if (android != null) {
    return await android.areNotificationsEnabled() ?? true;
  }
  return true;
}
```

**File:** `lib/features/profile/screens/profile_screen.dart` (around `_ReminderSwitchTile` at line 1059)
**Operation:** Modify — when `setNotificationsEnabled(true)` returns `false`, show a `SnackBar` or `AlertDialog` directing the user to system settings (open via `openAppSettings()` from `permission_handler` package or a manual `Intent` via `app_settings` package). Decide whether to add one of those packages — the cheaper option is just a SnackBar with text:

```dart
onChanged: (v) async {
  final ok = await ref.read(userProvider.notifier).setNotificationsEnabled(v);
  if (v && !ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Notifications blocked. Enable in Settings → Apps → 60 Second AI → Notifications.'),
      duration: Duration(seconds: 6),
    ));
  }
},
```

**Verification:** Manually deny the system permission, toggle the switch back ON, observe the SnackBar.

---

### Step 3 — Move FCM permission request to a user-initiated action (fixes H2 root cause)
**File:** `lib/data/remote/news_push_service.dart:38-98`
**Operation:** Split `init()` into `init()` (registers handlers + topic subscription, no permission prompt) and `requestPermissionAndSubscribe()` (prompts + subscribes). Call `init()` at boot as today; call `requestPermissionAndSubscribe()` from a user-visible "Push notifications: ON/OFF" toggle (new tile in profile, mirroring `_ReminderSwitchTile`).

**Pseudo-code:**
```dart
Future<void> init() async {
  if (_initialized) return;
  try {
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true);
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      final id = m.data['articleId'];
      if (id is String && id.isNotEmpty) goToNewsArticle(id);
    });
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      final id = initial.data['articleId'];
      if (id is String && id.isNotEmpty) goToNewsArticle(id);
    }
    // Re-subscribe if a previous session granted permission.
    final settings = await _messaging.getNotificationSettings();
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      await _messaging.subscribeToTopic(topic);
    }
    _initialized = true;
  } catch (e, st) {
    debugPrint('NewsPushService.init failed: $e\n$st');
  }
}

Future<bool> requestPermissionAndSubscribe() async {
  final settings = await _messaging.requestPermission(
    alert: true, badge: true, sound: true);
  final granted = settings.authorizationStatus == AuthorizationStatus.authorized
                || settings.authorizationStatus == AuthorizationStatus.provisional;
  if (granted) {
    await _messaging.subscribeToTopic(topic);
  }
  return granted;
}

Future<void> unsubscribe() => _messaging.unsubscribeFromTopic(topic);
```

**Storage:** Add `pushNotificationsEnabled` (bool) to `UserProfile` (`lib/data/models/user_model.dart`) so the toggle persists. Wire `UserNotifier.setPushEnabled(bool)` to call `requestPermissionAndSubscribe()` / `unsubscribe()` and persist.

**UI:** Add a second tile to the Notifications group in profile screen mirroring the daily-reminder pattern.

**Verification:** Fresh install; observe **no** permission dialog at startup. Open profile → toggle "News push notifications" ON; observe permission dialog. Send test push from FCM console.

---

### Step 4 — Make foreground handler tolerate FCM notification-only payloads (fixes part of H1)
**File:** `lib/data/remote/news_push_service.dart:100-110`
**Operation:** Modify `_onForegroundMessage` so it shows a banner even when `data.articleId` is absent — currently it returns silently in that case (line 104). Also fall back to using `notification.title/body` directly so server-side changes don't silently break delivery.

**Pseudo-code:**
```dart
Future<void> _onForegroundMessage(RemoteMessage message) async {
  final notif = message.notification;
  final id = message.data['articleId'] as String?;
  // Prefer notif.title/body; allow data-only fallback for future flexibility.
  final title = notif?.title ?? message.data['title'] as String? ?? 'AIScroll';
  final body = notif?.body ?? message.data['body'] as String? ?? '';
  if (title.isEmpty && body.isEmpty) return; // genuinely empty → skip
  await NotificationService.instance.showNewsBanner(
    title: title,
    body: body,
    articleId: id ?? '',  // empty payload is fine; tap = no deep-link
  );
}
```

`NotificationService.showNewsBanner` should already handle empty-string `articleId` (re-check the deep-link guard in `deep_link.dart:20` — it already returns early on empty).

**Verification:** Send Test 3 from D4 (data-only) — should now appear in foreground.

---

### Step 5 — Pass `DefaultFirebaseOptions.currentPlatform` to Firebase init (fixes H4)
**File:** `lib/main.dart:50`
**Operation:** Modify
```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```
…and `import 'firebase_options.dart';` at top of file (already imported transitively, verify).

**Caveat:** This will throw on iOS until `flutterfire configure` is re-run for iOS. If iOS isn't a target, leave it but add a `if (defaultTargetPlatform == TargetPlatform.android)` guard around the call, or accept the throw and rely on the existing catch in `_initFirebaseAppCheck`.

**Verification:** No regression on Android cold start; debug log shows Firebase initialized once with explicit project id.

---

### Step 6 — Switch daily reminder to exact alarms (fixes H5)
**File:** `lib/core/notifications/notification_service.dart:144`
**Operation:** Change
```dart
androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
```
to
```dart
androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
```

**Pre-check (Android 12+):** Add a runtime check via `AndroidFlutterLocalNotificationsPlugin.canScheduleExactNotifications()`. If false, fall back to inexact and surface a SnackBar telling the user to enable "Alarms & reminders" in system settings (the OS does not show a runtime dialog for `SCHEDULE_EXACT_ALARM`; user must navigate manually).

**Pseudo-code:**
```dart
Future<void> scheduleDaily(int minutesSinceMidnight) async {
  await initialize();
  await cancel();
  try {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final canExact = await android?.canScheduleExactNotifications() ?? true;
    final mode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    // ... rest of existing code, replace androidScheduleMode arg with `mode`.
  } catch (...)
}
```

**Verification:** D5 from Phase 1.

---

### Step 7 — Make FCM token visible in non-debug builds for support (fixes H6 visibility, not the bug)
**File:** `lib/data/remote/news_push_service.dart:84-92`
**Operation:** Add a method `Future<String?> debugToken()` that callers can invoke from a hidden "About" screen long-press. Don't change the `kDebugMode` gate for the auto-print — log spam in production isn't useful — but expose the token on demand.

```dart
Future<String?> currentToken() async {
  try { return await _messaging.getToken(); }
  catch (_) { return null; }
}
```

Wire a "Copy FCM token" `IconButton` into the profile screen's developer-info area (already exists per `my_debug_token.md` reference at repo root).

**Verification:** Tap the button, confirm the clipboard contains a valid FCM token starting with `c…:APA91…`.

---

### Step 8 — Add ProGuard keep rule for `flutter_local_notifications` (fixes H8)
**File:** `android/app/proguard-rules.pro`
**Operation:** Append
```
# flutter_local_notifications — boot receiver + scheduled-notification action
# receiver are referenced by name from the AndroidManifest, R8 doesn't see them.
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**
```

**Verification:** `flutter build apk --release` then `unzip -l build/app/outputs/flutter-apk/app-release.apk` and confirm `classes*.dex` still contains `ScheduledNotificationBootReceiver` (use `dexdump | grep` if needed).

---

## Phase 3 — Hardening (optional but recommended)

### H1. Server-side observability
Have the admin's news pipeline log every FCM send result (`messageId` + topic). When a user reports "no notifications", correlate device timestamp with server logs. (Out of scope for this Flutter PR but worth a follow-up ticket for `apps/admin`.)

### H2. Add a "Send test notification" developer button
In profile → settings (or via long-press on the daily reminder tile in debug builds), a button that calls `NotificationService.instance.showNewsBanner(title: 'Test', body: 'Test', articleId: '')`. Lets QA verify channel + icon + permission state in one action without a backend round-trip.

### H3. Add an integration test for the foreground handler
File: `test/notification_service_test.dart` (new). Stub `NotificationService` and verify `_onForegroundMessage` calls `showNewsBanner` with the expected arguments for both `notification`-bearing and data-only payloads.

---

## Key Files

| File | Operation | Description |
|------|-----------|-------------|
| `android/app/src/main/AndroidManifest.xml` | Modify | Add `default_notification_icon` + `default_notification_color` meta-data |
| `android/app/src/main/res/drawable-*/ic_stat_notification.png` | Add | Generate 5 PNG densities |
| `android/app/src/main/res/values/colors.xml` | Modify | Add `notification_color` resource |
| `android/app/proguard-rules.pro` | Modify | Add `flutter_local_notifications` keep rule |
| `lib/main.dart` | Modify | Pass `DefaultFirebaseOptions.currentPlatform` to `Firebase.initializeApp` |
| `lib/core/notifications/notification_service.dart` | Modify | New small-icon ref; `areEnabled()` helper; runtime exact-alarm check; switch to `exactAllowWhileIdle` with fallback |
| `lib/data/remote/news_push_service.dart` | Modify | Split `init()` from `requestPermissionAndSubscribe()`; tolerate notification-only and data-only payloads in foreground; add `currentToken()` helper |
| `lib/data/models/user_model.dart` | Modify | Add `pushNotificationsEnabled` field + serialization |
| `lib/data/providers/user_provider.dart` | Modify | Add `setPushEnabled(bool)` calling `requestPermissionAndSubscribe`/`unsubscribe` |
| `lib/features/profile/screens/profile_screen.dart` | Modify | Add "News push notifications" tile; SnackBar on permission denial for daily reminder |

---

## Risks and Mitigation

| Risk | Mitigation |
|------|------------|
| Step 5 (`DefaultFirebaseOptions.currentPlatform`) throws on iOS | Wrap in `defaultTargetPlatform == TargetPlatform.android` guard; iOS already unsupported per `firebase_options.dart` |
| Step 6 exact-alarm switch silently downgrades to inexact on Android 12+ if user hasn't granted "Alarms & reminders" | Detect via `canScheduleExactNotifications()` and surface in-app hint; never break scheduling |
| Step 1 icon files committed without proper monochrome treatment look like grey blobs | Use Android Studio's Image Asset Studio which auto-generates correct alpha-only icons |
| Step 3 changes the boot UX (no auto-prompt) — users on existing installs who previously denied won't be re-prompted, but won't get pushes either | Acceptable trade-off; the new toggle gives them an explicit way to opt in. Consider a one-time migration that calls `requestPermissionAndSubscribe()` on first launch after the update for users who already had the daily reminder enabled |
| ProGuard rule (Step 8) too broad → bloats release APK | Keep only the namespaces that crash without it; the listed wildcard adds <50 KB |

---

## SESSION_ID (for /ccg:execute use)
- CODEX_SESSION: _(none — codex was unavailable in this environment)_
- GEMINI_SESSION: _(none — gemini was unavailable in this environment)_
