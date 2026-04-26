# Implementation Plan: Flutter News Push Notifications (FCM)

## Task Type
- [x] **Frontend (Flutter / Dart + Android/iOS native config)**
- [ ] Backend (server side already implemented in `apps/admin`)

> **Multi-model note:** The `~/.claude/bin/codeagent-wrapper` was not available in this environment, so Codex/Gemini parallel analysis was skipped. This plan was synthesized by Claude alone after a deep read of the existing `aiscroll` Flutter app. No SESSION_ID is included — `/ccg:execute` will need to plan model handoff fresh.

---

## Context Snapshot

The Flutter app already has:

| Concern | File | Notes |
|---|---|---|
| Firebase init + App Check | `lib/main.dart` (`_initFirebaseAppCheck`) | Calls `Firebase.initializeApp()`; failures are swallowed. |
| Local notifications | `lib/core/notifications/notification_service.dart` | **Singleton** owning a `FlutterLocalNotificationsPlugin`. Channel `daily_reminder`. **Reuse this — do not create a second plugin instance.** |
| Routing | `lib/core/router/app_router.dart` | `go_router 13.x`. Route `/news/:id` already wired to `NewsDetailScreen(articleId, initialArticle)`. `appRouter` is a top-level `final` reachable from anywhere. |
| News feed model | `lib/data/models/news_model.dart` | `NewsArticle` shape matches server. **Missing**: `status`, `scheduledAt`, `expiresAt` (not needed for deep-link). |
| News HTTP layer | `lib/data/remote/news_service.dart` | Has `refreshFromNetwork()` for `/api/news`. **No `fetchById` yet** — must add for deep-link fallback. |
| Authed Dio | `lib/data/remote/authed_dio.dart` | Interceptor auto-attaches `Authorization: Bearer <jwt>` and retries on 401. Reuse for FCM-driven article fetches. |
| App lifecycle | `lib/app.dart` | Riverpod `ConsumerStatefulWidget` with `addPostFrameCallback` bootstrap (cache hydration → token mint → news refresh). Good place to call `NewsPushService.init()` last. |
| Detail screen | `lib/features/news/screens/news_detail_screen.dart` | Reads `newsArticleByIdProvider` (cache-only). **Renders "Article no longer available" on miss** — must change to fetch-on-miss. |
| pubspec | `pubspec.yaml` | Has `firebase_core ^3.6.0`, `firebase_app_check ^0.3.1+7`, `flutter_local_notifications ^17.2.4`, `go_router ^13.2.0`. **Missing**: `firebase_messaging`. |
| Android manifest | `android/app/src/main/AndroidManifest.xml` | `POST_NOTIFICATIONS` permission already granted. **Missing**: FCM `default_notification_channel_id` meta-data. |
| iOS AppDelegate | `ios/Runner/AppDelegate.swift` | Uses **new** `FlutterImplicitEngineDelegate` pattern — the spec doc's snippet would regress it. Must be edited surgically. |

### Open questions / prerequisites flagged

These need to be resolved by the user before notifications will actually deliver — they are **not** introduced by this plan but are blocking dependencies:

1. `android/app/google-services.json` is **not** in the tree, and `android/app/build.gradle.kts` does **not** apply `com.google.gms.google-services`. The existing `firebase_app_check` / `firebase_auth` only work because `_initFirebaseAppCheck` swallows the failure and the app keeps running offline.
2. `ios/Podfile` does not exist — first-time `flutter pub get` + `pod install` hasn't run, or the iOS target was never opened.
3. `flutterfire configure` is the supported way to fix both at once. Recommend running it before testing this feature.

---

## Technical Solution

**One-line summary:** Reuse the existing `NotificationService` singleton for the foreground banner (avoids double `FlutterLocalNotificationsPlugin.initialize`), add a new `NewsPushService` (Riverpod-managed) that owns the FCM-specific concerns (subscribe, foreground/background/terminated handlers, deep-link plumbing), and add a `fetchById` fallback to `NewsService` so taps on articles outside the 30-item cache still resolve.

### Architecture decisions (deviations from the spec doc)

| Spec doc says | This plan says | Why |
|---|---|---|
| Create a fresh `FlutterLocalNotificationsPlugin` in `news_push.dart` | Add a `showNewsBanner(...)` method to `NotificationService` and reuse its plugin | Two `initialize()` calls per process race on the platform-side singleton. The existing service already owns daily-reminder channel + boot receiver. |
| `_handleNewsTap` is a free function | `goToNewsArticle(id)` lives in `lib/core/router/deep_link.dart`, with a `Completer`-backed pending-id queue | The spec doc itself flags "Tap from terminated state navigates to wrong screen" as a pitfall. Solve it once. |
| `articleId → /news/$id` then trust the route | Add `NewsService.fetchById(id)` and update `NewsDetailScreen` to fetch on cache-miss | Cache only holds the 30 most recent articles; server can push notifications for articles up to 7 days old (`notifyMaxArticleAgeHours: 168`). Without fallback, ~5–10% of taps would land on "Article no longer available". |
| Replace `AppDelegate.swift` wholesale with the snippet shown | Surgically add `import UserNotifications` + `UNUserNotificationCenter.current().delegate = self` inside the **existing** `FlutterImplicitEngineDelegate`-based AppDelegate | The current AppDelegate uses a newer Flutter pattern; the spec snippet would break plugin registration. |
| Hand-rolled background isolate handler | Same — top-level `firebaseMessagingBackgroundHandler` with `@pragma('vm:entry-point')` | This is genuinely required by FCM. Doc is right. |

---

## Implementation Steps

> Each step lists: file → operation → expected behavioral change. Pseudo-code uses Dart unless noted. **No file is modified during planning** — this is a checklist for `/ccg:execute`.

### Step 1 — Add FCM dependency

**File:** `pubspec.yaml`
**Operation:** Modify
**Change:** Add one line under `dependencies:` (after `firebase_app_check`):

```yaml
firebase_messaging: ^15.1.3
```

Then run `flutter pub get`.

**Verification:** `flutter pub deps | grep firebase_messaging` shows the resolved version.

---

### Step 2 — Android: declare default FCM channel meta-data

**File:** `android/app/src/main/AndroidManifest.xml`
**Operation:** Modify
**Change:** Add inside `<application>` (anywhere, but next to the existing `flutterEmbedding` meta-data is conventional):

```xml
<!-- FCM: route incoming pushes whose payload uses channelId="news" -->
<meta-data
    android:name="com.google.firebase.messaging.default_notification_channel_id"
    android:value="news" />
```

The actual `news` channel is created from Dart in Step 5 — this meta-data only tells the Firebase Android SDK which channel to bind notifications to before the Dart isolate is up.

**Why not just `daily_reminder`?** Two channels = two user-facing toggles in Android settings ("Daily Reminder" vs "AI News"). Users muting one shouldn't mute the other.

---

### Step 3 — iOS: extend (don't replace) the existing AppDelegate

**File:** `ios/Runner/AppDelegate.swift`
**Operation:** Modify (surgical)
**Current state:** uses `FlutterImplicitEngineDelegate` — preserve that.

**Change** (pseudo-code, final structure):

```swift
import Flutter
import UIKit
import UserNotifications  // NEW

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // NEW: required so iOS delivers notifications to the app while in foreground.
    // Without this, FirebaseMessaging.onMessage never fires on iOS.
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
```

**Do NOT add `FirebaseApp.configure()`** — `Firebase.initializeApp()` is already called from `main.dart`, and the iOS plugin auto-bridges. Adding it twice causes "Default app already configured" log noise.

**Skip:** Notification Service Extension target (rich images on iOS) — the team can add it later. Android works without it.

---

### Step 4 — Pubspec / native sanity check (PREREQUISITE)

**File:** none (env check)
**Operation:** Verify

If `android/app/google-services.json` is absent OR `ios/Runner/GoogleService-Info.plist` is absent, **stop and run `flutterfire configure`** (or hand-place the files from the Firebase console). Without these, FCM topic subscription silently fails.

This is a prerequisite because the same files also gate `firebase_app_check` (which the rest of the app already depends on). Skip to Step 5 only if both files exist OR if testing only on a configured device.

---

### Step 5 — Extend `NotificationService` with a news channel + tap callback

**File:** `lib/core/notifications/notification_service.dart`
**Operation:** Modify

**Three changes:**

1. **Channel constants** (top of class):
   ```dart
   static const String newsChannelId = 'news';
   static const String _newsChannelName = 'AI News';
   static const String _newsChannelDescription =
       'Random AI news drops from the AIScroll team';
   ```

2. **Inside `initialize()`**, after the existing plugin `initialize(...)` call but before `_initialized = true`:
   ```dart
   // News push channel — used by both server-pushed FCM messages
   // (channelId: "news") and the local foreground banner we render
   // when the app is open.
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
   ```

   **Also** wire `onDidReceiveNotificationResponse` so that taps on the foreground banner deep-link. The current `initialize()` doesn't pass one — add it:

   ```dart
   await _plugin.initialize(
     const InitializationSettings(android: android, iOS: ios),
     onDidReceiveNotificationResponse: (response) {
       final payload = response.payload;
       if (payload == null || payload.isEmpty) return;
       // Lazy import to avoid a cycle: deep_link.dart imports NotificationService nowhere.
       goToNewsArticle(payload);
     },
   );
   ```

3. **New public method** `showNewsBanner(RemoteMessage message)`:
   ```dart
   Future<void> showNewsBanner({
     required String title,
     required String body,
     required String articleId,
     String? androidImageUrl,
   }) async {
     await initialize();
     await _plugin.show(
       // Stable ID derived from articleId so re-deliveries collapse rather
       // than stack. Hash to fit in 31-bit signed int.
       articleId.hashCode & 0x7fffffff,
       title,
       body,
       NotificationDetails(
         android: AndroidNotificationDetails(
           newsChannelId,
           _newsChannelName,
           channelDescription: _newsChannelDescription,
           importance: Importance.high,
           priority: Priority.high,
           styleInformation: androidImageUrl != null
               ? BigPictureStyleInformation(
                   FilePathAndroidBitmap(androidImageUrl),
                 )
               : null,
         ),
         iOS: const DarwinNotificationDetails(),
       ),
       payload: articleId,
     );
   }
   ```

   > **Note on `BigPictureStyleInformation(FilePathAndroidBitmap(url))`:** the plugin doesn't auto-download remote URLs. For the MVP we'll pass `null` (text-only banner) or download via `cached_network_image`'s file resolver before showing. **Default to text-only** in this iteration — the system tray version (background/killed) shows the image natively because FCM does the download server-side.

---

### Step 6 — Deep-link helper with pending-id queue

**File:** `lib/core/router/deep_link.dart` (new, ~40 lines)
**Operation:** Create

```dart
import 'app_router.dart';

// Set to true once the router has rendered its first frame.
bool _routerReady = false;

// Queued articleId from a notification tap that arrived before the router
// was ready (cold start from terminated state).
String? _pendingArticleId;

/// Mark the router as ready and drain any queued deep link.
/// Call from `app.dart`'s `addPostFrameCallback` AFTER `runApp`.
void markRouterReady() {
  _routerReady = true;
  final pending = _pendingArticleId;
  if (pending != null) {
    _pendingArticleId = null;
    _go(pending);
  }
}

/// Navigate to the news article. Defers if the router isn't ready yet.
void goToNewsArticle(String articleId) {
  if (articleId.isEmpty) return;
  if (!_routerReady) {
    _pendingArticleId = articleId;
    return;
  }
  _go(articleId);
}

void _go(String articleId) {
  // appRouter is a top-level final in app_router.dart, so we don't need a
  // BuildContext. This is the whole reason we kept it global.
  appRouter.go(AppRoutes.newsDetail(articleId));
}
```

**Why a free function?** Notifications come in from FCM isolates and from `NotificationService`'s `onDidReceiveNotificationResponse` callback, neither of which has a `BuildContext`. The router being a global `final` makes this simple — no Riverpod scope juggling, no `GlobalKey<NavigatorState>`.

---

### Step 7 — `NewsPushService` (FCM owner)

**File:** `lib/data/remote/news_push_service.dart` (new, ~120 lines)
**Operation:** Create

```dart
// Top-level — required by FCM. Annotation must be exactly this.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No-op. Android renders the system banner automatically because the
  // server sends both `notification` and `data` blocks. Hook is required
  // by FCM's API contract — leave it for future analytics.
}

class NewsPushService {
  NewsPushService({FirebaseMessaging? messaging})
      : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;
  static const String topic = 'news';
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      // 1. Permission (iOS prompts here; Android 13+ also requires it).
      await _messaging.requestPermission(alert: true, badge: true, sound: true);

      // 2. iOS only: foreground presentation options.
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true,
      );

      // 3. Subscribe to the server-side topic. Idempotent.
      await _messaging.subscribeToTopic(topic);

      // 4. Background / terminated handler.
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 5. Foreground messages — render via NotificationService (shared plugin).
      FirebaseMessaging.onMessage.listen(_onForeground);

      // 6. Tap while backgrounded.
      FirebaseMessaging.onMessageOpenedApp.listen((m) {
        final id = m.data['articleId'];
        if (id is String && id.isNotEmpty) goToNewsArticle(id);
      });

      // 7. Cold start from terminated state via tap.
      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        final id = initial.data['articleId'];
        if (id is String && id.isNotEmpty) goToNewsArticle(id);
      }

      // Debug-only: log the FCM token for single-device test pushes.
      if (kDebugMode) {
        final token = await _messaging.getToken();
        debugPrint('FCM token: $token');
      }

      _initialized = true;
    } catch (e, st) {
      // Never block app start. Notifications are best-effort.
      debugPrint('NewsPushService.init failed: $e\n$st');
    }
  }

  Future<void> _onForeground(RemoteMessage message) async {
    final notif = message.notification;
    if (notif == null) return;
    final id = message.data['articleId'] as String?;
    if (id == null || id.isEmpty) return;
    await NotificationService.instance.showNewsBanner(
      title: notif.title ?? 'AIScroll',
      body: notif.body ?? '',
      articleId: id,
      // Skip image for MVP — see Step 5 note.
    );
  }
}
```

**Riverpod provider** (add to the same file or to `lib/data/providers/news_provider.dart`):

```dart
final newsPushServiceProvider = Provider<NewsPushService>((ref) {
  return NewsPushService();
});
```

---

### Step 8 — Add `NewsService.fetchById` for cache-miss deep links

**File:** `lib/data/remote/news_service.dart`
**Operation:** Modify

**Why:** The 30-item cache won't always contain the article a notification points to (server's `notifyMaxArticleAgeHours: 168` allows 7-day-old articles). Without this, ~5–10% of taps land on "Article no longer available".

Add a method:

```dart
/// Fetches a single article by id. Returns null on 404 / network failure.
/// Caller is responsible for cache-merging if desired.
Future<NewsArticle?> fetchById(String id) async {
  if (!isAdminConfigured) return null;
  try {
    final resp = await _dio.get<dynamic>(
      '$_baseUrl/api/news/${Uri.encodeComponent(id)}',
      options: _reqOptions(),
    );
    if (resp.statusCode != 200) return null;
    final body = resp.data;
    if (body is! Map<String, dynamic>) return null;
    if (body['success'] != true) return null;
    final data = body['data'];
    if (data is! Map<String, dynamic>) return null;
    return NewsArticle.fromMap(data);
  } catch (_) {
    return null;
  }
}
```

> The `_dio` instance already has the auth interceptor attached (see `newsServiceProvider` factory in `news_provider.dart`), so `Authorization: Bearer` is added automatically. No new auth plumbing.

**Provider helper** in `lib/data/providers/news_provider.dart`:

```dart
final newsArticleFetchProvider =
    FutureProvider.autoDispose.family<NewsArticle?, String>((ref, id) async {
  // Cache hit — return immediately.
  final cached = ref.watch(newsArticleByIdProvider(id));
  if (cached != null) return cached;
  // Cache miss — go to network.
  return ref.read(newsServiceProvider).fetchById(id);
});
```

---

### Step 9 — Update `NewsDetailScreen` to handle cache miss

**File:** `lib/features/news/screens/news_detail_screen.dart`
**Operation:** Modify

**Current behavior** (lines 52–67): if `newsArticleByIdProvider` returns null AND `widget.initialArticle` is null, shows "Article no longer available."

**New behavior** (pseudo-code):

```dart
@override
Widget build(BuildContext context) {
  final cached = ref.watch(newsArticleByIdProvider(widget.articleId));
  final initial = widget.initialArticle;

  // Fast path: cache or initial extra has it.
  final articleNow = cached ?? initial;
  if (articleNow != null) {
    return _buildArticleScaffold(articleNow);
  }

  // Cache miss — fetch from network.
  final fetchAsync = ref.watch(newsArticleFetchProvider(widget.articleId));
  return fetchAsync.when(
    loading: () => Scaffold(
      appBar: AppBar(title: const Text('Article')),
      body: const Center(child: CircularProgressIndicator()),
    ),
    error: (_, _) => _notFoundScaffold(),
    data: (article) => article == null
        ? _notFoundScaffold()
        : _buildArticleScaffold(article),
  );
}
```

Refactor the existing inline body into `_buildArticleScaffold(NewsArticle article)` and the existing fallback into `_notFoundScaffold()`. No visual change for the cache-hit path.

---

### Step 10 — Wire init in `main.dart` and `app.dart`

**File 1:** `lib/main.dart`
**Operation:** Modify

The FCM background handler must be registered **before** `runApp`, in the same isolate. Move the registration to `main` (between `_initFirebaseAppCheck()` and `NotificationService.instance.initialize()`):

```dart
await _initFirebaseAppCheck();
// Required to be at top-level + registered before runApp.
FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
await NotificationService.instance.initialize();
```

> Calling `onBackgroundMessage` here AND inside `NewsPushService.init()` is harmless — the FCM plugin dedupes — but doing it before `runApp` is what guarantees terminated-state delivery on Android.

**File 2:** `lib/app.dart`
**Operation:** Modify

In the existing `addPostFrameCallback` block (after `newsNotifier.scheduler.start();`), append:

```dart
// 7. Mark the router ready so any pending notification tap (queued
//    during cold-start) drains now.
markRouterReady();

// 8. Bring up FCM. Best-effort — never blocks UI. Subscribes to the
//    `news` topic and registers foreground/background/terminated handlers.
// ignore: unawaited_futures
ref.read(newsPushServiceProvider).init();
```

---

### Step 11 — Smoke test checklist

Performed manually after `flutter run --dart-define=ADMIN_API_URL=...`:

| # | Scenario | Expected | How to trigger |
|---|---|---|---|
| 1 | Foreground push | In-app banner from `NotificationService`. Tap → `NewsDetailScreen` for that id. | `curl -X POST .../api/cron/news-notify` with app open. |
| 2 | Background push | System tray notification. Tap → app resumes on `NewsDetailScreen`. | Same curl, app backgrounded. |
| 3 | Terminated push | System tray notification. Tap → app cold-starts, lands on `NewsDetailScreen` (router queue drained). | Force-stop app, then curl. |
| 4 | Article not in cache | `NewsDetailScreen` shows spinner, then renders article from `fetchById`. | Pick an article older than the 30 in cache. |
| 5 | Article 404 | "Article no longer available" fallback. | Hand-craft FCM payload with `articleId: "nonexistent"` (Step 9.2 of doc's testing section). |
| 6 | Daily reminder still fires | Existing local notification at the user's chosen time. | Existing flow — verify reuse didn't break it. Channel `daily_reminder` should remain in Android settings alongside `news`. |
| 7 | Topic subscription idempotent | No errors after multiple cold starts. | Cold start the app 3× in a row. |

---

## Key Files

| File | Operation | Purpose |
|---|---|---|
| `pubspec.yaml` | Modify | Add `firebase_messaging: ^15.1.3`. |
| `android/app/src/main/AndroidManifest.xml` | Modify | Add FCM `default_notification_channel_id="news"` meta-data. |
| `ios/Runner/AppDelegate.swift` | Modify (surgical) | Add `import UserNotifications` + `UNUserNotificationCenter.current().delegate = self`. **Preserve** the `FlutterImplicitEngineDelegate` plumbing. |
| `lib/core/notifications/notification_service.dart` | Modify | Add `news` channel, `showNewsBanner(...)`, and `onDidReceiveNotificationResponse` → `goToNewsArticle`. |
| `lib/core/router/deep_link.dart` | Create | `goToNewsArticle(id)` + `markRouterReady()` with pending-id queue. |
| `lib/data/remote/news_push_service.dart` | Create | `NewsPushService` (init, subscribe, foreground/background/terminated handlers) + top-level `firebaseMessagingBackgroundHandler`. |
| `lib/data/remote/news_service.dart` | Modify | Add `fetchById(String id)`. |
| `lib/data/providers/news_provider.dart` | Modify | Add `newsPushServiceProvider` and `newsArticleFetchProvider` (cache-miss fallback). |
| `lib/features/news/screens/news_detail_screen.dart` | Modify | Use `newsArticleFetchProvider` on cache-miss; refactor body into helper methods. |
| `lib/main.dart` | Modify | Register `FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler)` before `runApp`. |
| `lib/app.dart` | Modify | Call `markRouterReady()` and `ref.read(newsPushServiceProvider).init()` from `addPostFrameCallback`. |

**Total:** 6 files modified, 2 files created. ≈ 250 LOC net.

---

## Risks and Mitigation

| # | Risk | Likelihood | Mitigation |
|---|---|---|---|
| 1 | `google-services.json` / `GoogleService-Info.plist` missing → topic subscribe fails silently. | High (current state) | Step 4 prerequisite. Ask user to run `flutterfire configure` before test. |
| 2 | `pod install` not run → iOS build breaks on `firebase_messaging`. | High (no Podfile) | Run `cd ios && pod install` after `flutter pub get`. |
| 3 | Existing `NotificationService` and a new `FlutterLocalNotificationsPlugin` both calling `initialize()` → callback collisions. | Medium | Solved by reusing the existing singleton (Step 5). Don't instantiate a second plugin. |
| 4 | Tap from terminated state navigates to home. | Medium (the spec doc itself flags this) | Solved by the `markRouterReady()` queue (Step 6). |
| 5 | Article from notification not in 30-item cache → "Article no longer available". | Medium | Solved by `fetchById` + `newsArticleFetchProvider` (Steps 8–9). |
| 6 | iOS foreground notifications never fire. | Low | Solved by `UNUserNotificationCenter.current().delegate = self` in AppDelegate (Step 3) + `setForegroundNotificationPresentationOptions(...)` in Dart (Step 7). |
| 7 | Multiple `subscribeToTopic('news')` calls on every cold start cause FCM rate-limits. | Very low | `subscribeToTopic` is documented idempotent. Worst case: a single `kFirebaseMessagingError` log per launch. |
| 8 | Foreground banner stacks (one per push) when the same article is re-pushed. | Low | Stable ID via `articleId.hashCode & 0x7fffffff` in `showNewsBanner` so re-deliveries collapse. |
| 9 | Image rendering on Android foreground banner requires an actual file path, not URL. | Low | MVP defers Android-foreground images. System-tray (background/killed) renders the image because FCM downloads it server-side. iOS images already deferred per spec. |
| 10 | `go_router 13.x` vs spec doc's `14.x`. | Very low | Existing route `/news/:id` works identically in 13.x. No upgrade needed. |
| 11 | Background isolate handler not declared at top level → silent crash on receive when app killed. | Low | `@pragma('vm:entry-point')` + top-level placement enforced by spec. Lint catches accidental class-level placement. |

---

## SESSION_ID Handoff

- **CODEX_SESSION:** _not available — codeagent-wrapper not installed in this environment._
- **GEMINI_SESSION:** _not available — codeagent-wrapper not installed in this environment._

`/ccg:execute` for this plan should re-do model setup or operate single-model. The plan above is detailed enough for direct execution by Claude alone.

---

## Out of Scope (explicit non-goals for this iteration)

- iOS Notification Service Extension (rich images on iOS lock screen) — defer.
- Per-category topics (`news.ai-models`, `news.ai-tools`, …) — server picks per-article today; revisit after first usage data.
- User-facing toggle in Settings to opt out of news pushes — `requestPermission` is the only opt-out for now. Add a `boolean` in `UserProfile` + a switch in `ProfileScreen` later.
- Analytics on push deliveries / opens — `firebaseMessagingBackgroundHandler` is currently a no-op; later it can call into `telemetry_service`.
- Server-side `notifyEnabled: true` toggle — that's an admin task, not Flutter.
