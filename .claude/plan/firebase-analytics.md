# Implementation Plan: Firebase Analytics for User Activity Monitoring

## 1. Restated Requirement

Wire **Firebase Analytics** into the AIScroll Flutter app so we can monitor real
user activity (screens, sessions, learning interactions, news engagement, auth,
ads) in the Firebase console (`second-ai-bd78a` project). Reuse the existing
Firebase plumbing (`firebase_core`, App Check, FCM, Auth) and stay consistent
with the offline-first, fire-and-forget telemetry style already in
`TelemetryService`.

The custom backend telemetry (`/api/events/ingest`) stays — Firebase Analytics
runs *alongside* it. Same source events, two sinks: Firebase for product
analytics (DebugView, retention, funnels, audiences) and our admin for
operational metrics.

---

## 2. Task Type

- [ ] Frontend (UI/UX only)
- [x] Mobile / Cross-cutting (service layer + every screen + auth + lifecycle)
- [ ] Backend
- [ ] Fullstack

---

## 3. Existing State (verified)

| Area | Current state |
|------|---------------|
| Firebase project | `second-ai-bd78a`, configured Android only (`firebase_options.dart`). iOS `firebase_options` throws `UnsupportedError`. |
| Already using | `firebase_core`, `firebase_app_check`, `firebase_messaging`, `firebase_auth`, `cloud_firestore`. |
| State management | `flutter_riverpod` 2.5 — service-as-`Provider` pattern. |
| Routing | `go_router` 13 with `StatefulShellRoute.indexedStack` (4 tabs). |
| Existing telemetry | `lib/data/remote/telemetry_service.dart` — fire-and-forget queue → admin `/api/events/ingest`, with named helpers (`logCardViewed`, `logCardLearned`, `logQuizAnswered`, `logXp`, `logStreakDay`, `logSessionStart`). Wired in `lib/data/providers/user_provider.dart` and `lib/app.dart`. |
| Auth flows | Anonymous guest, Google sign-in, email/password (`lib/data/remote/auth_service.dart`). |
| Android Gradle | `com.google.gms.google-services` plugin already applied; `google-services.json` is being generated to `android/app/`. |

**Key implication**: Firebase Analytics SDK only needs the Dart package + a
service wrapper — Android Gradle wiring and `Firebase.initializeApp()` are
already in place.

---

## 4. Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| iOS not configured in `firebase_options.dart` — Analytics calls would crash on iOS. | Guard `AnalyticsService` activation behind `Firebase.apps.isNotEmpty`; same swallow-and-log pattern as `_initFirebaseAppCheck`. Note iOS configuration as a **separate prerequisite** (FlutterFire CLI + `GoogleService-Info.plist`). |
| PII leakage in custom event params (e.g., article titles, user emails). | Whitelist param keys per event; never pass `email`, `displayName`, raw search queries. Hash `userId` before setting `setUserId`. |
| Reserved event/parameter names colliding with Firebase predefined ones. | Use Firebase predefined events where available (`login`, `sign_up`, `screen_view`, `share`, `select_content`, `tutorial_begin`, `tutorial_complete`); use snake_case custom names for app-specific events; keep param names ≤ 40 chars and values ≤ 100 chars. |
| Double-counting screen views (auto + manual). | Use **one** mechanism: a `FirebaseAnalyticsObserver` plugged into `GoRouter`'s `observers`, with a `routeFilter` so we don't log the splash redirect cycle. |
| Analytics on debug builds polluting prod data. | Set `setAnalyticsCollectionEnabled(!kDebugMode)` by default; expose a profile toggle so QA can opt-in via Firebase **DebugView**. |
| Privacy/consent — Play Store data-safety form must reflect tracking. | Add a "Help improve the app" toggle in Profile → Settings (default ON for now, but easy to flip to opt-in later). Persist via `PreferencesService`. |
| Tests / `flutter test` in CI — `FirebaseAnalytics.instance` not available without a real platform. | `AnalyticsService` accepts an injected `FirebaseAnalytics` (default `FirebaseAnalytics.instance`) so unit tests pass a fake. Same pattern as `AuthService`. |
| Cold-start crash if `Firebase.initializeApp()` isn't called yet. | Move analytics activation into the same `_initFirebaseApp...` block in `main.dart`, after Firebase init succeeds. |

---

## 5. Architecture (Final Synthesis)

```
┌──────────────────────────────────────────────────────────────┐
│  UI (screens, providers)                                     │
│   ├─ navigation events  ──┐                                  │
│   ├─ user actions  ───────┼──┐                               │
│   └─ auth events  ────────┘  │                               │
│                              ▼                               │
│  AnalyticsService (lib/data/remote/analytics_service.dart)  │
│   ├─ logEvent(name, params, userId, guestId)                 │
│   ├─ logScreenView(name, class)                              │
│   ├─ setUserProperty(key, value)                             │
│   ├─ setUserId(idOrNull)                                     │
│   ├─ setEnabled(bool)                                        │
│   └─ named wrappers (logSignUp, logLogin, logCardViewed, …)  │
│                              │                               │
│       ┌──────────────────────┴────────────────────┐          │
│       ▼                                           ▼          │
│  FirebaseAnalytics                       TelemetryService    │
│  (Firebase console)                      (admin /api/events) │
└──────────────────────────────────────────────────────────────┘
```

Both services are invoked from a thin **`Telemetry` facade provider** — current
call-sites (`_telemetry?.logCardViewed(...)` in `user_provider.dart`) keep working
without churn, and one helper fans out to both sinks.

---

## 6. Implementation Steps

### Phase 1 — Setup (Foundation)

1. **Add package** to `pubspec.yaml`:
   ```yaml
   dependencies:
     firebase_analytics: ^11.3.3   # latest 11.x compatible with firebase_core ^3.6
   ```
   Run `flutter pub get`.
   _Deliverable_: `pubspec.lock` updated; build still green.

2. **Verify Android wiring**: confirm `android/app/google-services.json`
   contains `firebase_analytics` config (it does by default with `gms`
   plugin). No Gradle changes needed — `com.google.gms.google-services`
   already applied in `android/app/build.gradle.kts:7`.

3. **(Optional, separate task)** iOS configuration:
   - Run `flutterfire configure --project=second-ai-bd78a --platforms=ios`
   - Drop `GoogleService-Info.plist` into `ios/Runner/`.
   - Re-generate `lib/firebase_options.dart` (the existing file currently
     throws on iOS).
   _Deliverable_: iOS analytics works on TestFlight builds.

### Phase 2 — Service Layer

4. **Create `lib/data/remote/analytics_service.dart`**:
   ```dart
   class AnalyticsService {
     AnalyticsService({FirebaseAnalytics? analytics, PreferencesService? prefs})
       : _analytics = analytics ?? FirebaseAnalytics.instance,
         _prefs    = prefs ?? PreferencesService.instance;

     final FirebaseAnalytics _analytics;
     final PreferencesService _prefs;
     final bool _firebaseAvailable = Firebase.apps.isNotEmpty;

     // Read once at construction; flipped by user via setEnabled.
     bool _enabled = true;

     FirebaseAnalyticsObserver get observer =>
         FirebaseAnalyticsObserver(analytics: _analytics);

     Future<void> init() async {
       _enabled = _prefs.getBool('analytics.enabled') ?? !kDebugMode;
       if (!_firebaseAvailable) return;
       await _analytics.setAnalyticsCollectionEnabled(_enabled);
     }

     // Generic
     Future<void> logEvent(
       String name, {
       Map<String, Object>? params,
     }) async {
       if (!_enabled || !_firebaseAvailable) return;
       try {
         await _analytics.logEvent(
           name: name,
           parameters: params,
         );
       } catch (e) {
         debugPrint('AnalyticsService.logEvent failed: $e');
       }
     }

     // Screen view (called by observer + manual taps)
     Future<void> logScreenView({required String name, String? screenClass}) =>
         _safe(() => _analytics.logScreenView(
           screenName: name, screenClass: screenClass));

     // User identity
     Future<void> setUserId(String? id) =>
         _safe(() => _analytics.setUserId(id: id));
     Future<void> setUserProperty(String key, String? value) =>
         _safe(() => _analytics.setUserProperty(name: key, value: value));

     // Privacy toggle (persisted)
     Future<void> setEnabled(bool enabled) async {
       _enabled = enabled;
       await _prefs.setBool('analytics.enabled', enabled);
       await _safe(() => _analytics.setAnalyticsCollectionEnabled(enabled));
     }

     // ----- Named wrappers (mirror TelemetryService) -----
     Future<void> logSignUp({required String method}) =>
         logEvent('sign_up', params: {'method': method});
     Future<void> logLogin({required String method}) =>
         logEvent('login',   params: {'method': method});
     Future<void> logSessionStart() => logEvent('session_start');
     Future<void> logCardViewed(String cardId,
       {int dwellMs = 0, bool wasDue = false}) =>
       logEvent('card_viewed', params: {
         'card_id': cardId, 'dwell_ms': dwellMs, 'was_due': wasDue ? 1 : 0,
       });
     Future<void> logCardLearned(String cardId) =>
       logEvent('card_learned', params: {'card_id': cardId});
     Future<void> logQuizAnswered({
       required String quizId, required String cardId,
       required bool correct, required int selected,
     }) => logEvent('quiz_answered', params: {
       'quiz_id': quizId, 'card_id': cardId,
       'correct': correct ? 1 : 0, 'selected': selected,
     });
     Future<void> logXp(int amount, String source) =>
       logEvent('xp_awarded', params: {'amount': amount, 'source': source});
     Future<void> logStreakDay(int streak) =>
       logEvent('streak_day', params: {'streak': streak});
     Future<void> logTrackStarted(String trackId) =>
       logEvent('track_started', params: {'track_id': trackId});
     Future<void> logTrackCompleted(String trackId) =>
       logEvent('track_completed', params: {'track_id': trackId});
     Future<void> logNewsOpened(String articleId, {String? source}) =>
       logEvent('news_opened',
                params: {'article_id': articleId, 'source': source ?? 'list'});
     Future<void> logNewsSaved(String articleId, {required bool saved}) =>
       logEvent('news_saved',
                params: {'article_id': articleId, 'saved': saved ? 1 : 0});
     Future<void> logShare(String contentType, String itemId) =>
       _safe(() => _analytics.logShare(
              contentType: contentType, itemId: itemId, method: 'system_sheet'));
     Future<void> logTutorialBegin() => _safe(_analytics.logTutorialBegin);
     Future<void> logTutorialComplete() => _safe(_analytics.logTutorialComplete);
     Future<void> logNotificationOpen(String topic, {String? articleId}) =>
       logEvent('notification_open',
                params: {'topic': topic, if (articleId != null) 'article_id': articleId});

     Future<T?> _safe<T>(Future<T> Function() op) async {
       if (!_enabled || !_firebaseAvailable) return null;
       try { return await op(); }
       catch (e) { debugPrint('AnalyticsService op failed: $e'); return null; }
     }
   }
   ```
   _Deliverable_: thin, fire-and-forget, mock-friendly service. ~200 LOC.

5. **Create `lib/data/providers/analytics_provider.dart`**:
   ```dart
   final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
     final svc = AnalyticsService();
     // ignore: discarded_futures
     svc.init();
     return svc;
   });
   ```

6. **Create a fan-out facade** (keeps call-sites unchanged) in
   `lib/data/providers/telemetry_provider.dart`:
   ```dart
   /// Single entry point — fans out to admin telemetry + Firebase Analytics.
   /// Call-sites that already use telemetryServiceProvider keep working;
   /// new code can also use this facade.
   final telemetryFacadeProvider = Provider<TelemetryFacade>((ref) {
     return TelemetryFacade(
       admin: ref.read(telemetryServiceProvider),
       analytics: ref.read(analyticsServiceProvider),
     );
   });
   ```
   `TelemetryFacade` mirrors named methods and dispatches to both.
   _Deliverable_: one method = one user-visible event in both sinks.

### Phase 3 — Initialization

7. **`lib/main.dart`**: after `_initFirebaseAppCheck()` completes, also call
   `await ProviderContainer().read(analyticsServiceProvider).init();`
   _Or simpler_: do nothing here — `analyticsServiceProvider` is auto-init'd
   on first read in `app.dart`. Pick the auto-init path for less coupling.

8. **`lib/app.dart` initState**:
   - After `userProvider.notifier.load()` completes:
     ```dart
     final user = ref.read(userProvider);
     final a = ref.read(analyticsServiceProvider);
     await a.setUserId(user.isGuest ? null : _hash(user.id));
     await a.setUserProperty('persona',     user.persona ?? 'unset');
     await a.setUserProperty('knowledge_level', user.knowledgeLevel ?? 'unset');
     await a.setUserProperty('daily_goal_min',  '${user.dailyGoalMinutes}');
     await a.setUserProperty('is_guest',        '${user.isGuest}');
     await a.logSessionStart();
     ```
   - On `AppLifecycleState.paused` already flushes admin telemetry; Firebase
     auto-flushes on background. Nothing extra to add.

### Phase 4 — Screen Tracking

9. **`lib/core/router/app_router.dart`**: pass the `FirebaseAnalyticsObserver`
   from `analyticsServiceProvider`:
   ```dart
   final appRouter = GoRouter(
     observers: [ref.read(analyticsServiceProvider).observer],   // ← new
     ...
   );
   ```
   Because `appRouter` is currently a top-level final, refactor it into a
   `Provider<GoRouter>` so it can read other providers. Update `app.dart`'s
   `MaterialApp.router(routerConfig: ref.watch(appRouterProvider))`.

10. **Screen names**: ensure each route's `pageBuilder`/`builder` returns a
    widget whose runtime type is meaningful, OR pass `name:` on each
    `GoRoute` and have the observer pick it up. Verified by inspecting
    Firebase **DebugView**.

### Phase 5 — Event Wiring (per call site)

| Source file | Hook into | Event |
|---|---|---|
| `auth_service.dart` `signInWithGoogle()` (success path) | callers in `register_screen.dart` / `login_screen.dart` | `login` (`method: google`) |
| `auth_service.dart` `signInWithEmailPassword()` | `login_screen.dart` | `login` (`method: password`) |
| `auth_service.dart` `registerWithEmailPassword()` | `register_screen.dart` | `sign_up` (`method: password`) |
| `onboarding_provider.dart` (start) | first screen | `tutorial_begin` |
| `onboarding_provider.dart` (complete) | finish/`completeOnboarding` | `tutorial_complete` + set user properties |
| `user_provider.dart` `awardXp` | already calls `logXp` on admin telem | also `analytics.logXp` via facade |
| `user_provider.dart` `recordCardViewed` | already calls `logCardViewed` | also `analytics.logCardViewed` |
| `user_provider.dart` `markCardLearned` | already calls `logCardLearned` | also `analytics.logCardLearned` |
| `user_provider.dart` `_bumpStreakIfNeeded` | already calls `logStreakDay` | also `analytics.logStreakDay` |
| `boss_quiz_provider.dart` answer handler | (search for `quiz_answered` callsites) | `analytics.logQuizAnswered` |
| `track_learn_screen.dart` open / finish | per track | `track_started` / `track_completed` |
| `news_detail_screen.dart` open | initState | `news_opened` (source: list/push/deeplink) |
| `news_action_bar.dart` save toggle | save handler | `news_saved` |
| `news_action_bar.dart` share | share handler | `share` (predefined) |
| `news_push_service.dart` notification tap | navigation handler | `notification_open` |
| `feedback_service.dart` submit | submit handler | `feedback_submitted` |
| AdMob impressions | `inline_native_ad.dart` `onAdImpression` | `ad_impression` (predefined available via SDK callback) |

_Implementation note_: keep the diff small — change call-sites that already
exist (e.g., `_telemetry?.logCardViewed(...)`) to use the **facade** so that
both sinks fire, instead of editing dozens of files individually.

### Phase 6 — Privacy Toggle UI

11. **Profile screen** (`lib/features/profile/screens/profile_screen.dart`):
    add a `SwitchListTile` "Help improve the app (anonymous analytics)" that
    reads/writes `analyticsServiceProvider`'s `setEnabled()`. Persisted in
    `SharedPreferences`. Default = `!kDebugMode`.

12. **Play Store data safety**: update the form to declare:
    *App activity (interactions, in-app search history)* → **Yes, collected
    and shared, optional, ephemeral, encrypted in transit**. Note in PR.

### Phase 7 — Verification

13. **DebugView**:
    ```bash
    adb shell setprop debug.firebase.analytics.app com.kj.aiscroll
    flutter run
    ```
    Open Firebase Console → Analytics → DebugView. Verify:
    - `session_start` fires once per cold launch.
    - `screen_view` fires on every nav.
    - `card_viewed`, `quiz_answered` show in-stream.
    - User properties (`persona`, `knowledge_level`) attached.

14. **Unit test** `test/analytics_service_test.dart`: pass a `FakeFirebaseAnalytics`
    (or just verify `setEnabled(false)` short-circuits all `logEvent` calls).
    Target: 80% coverage of the service layer.

15. **Manual QA pass**: cold start → onboarding → learn one card → answer one
    quiz → open one news article → share → background → foreground → sign in
    with Google → verify all events appear.

---

## 7. Key Files

| File | Operation | Description |
|------|-----------|-------------|
| `pubspec.yaml` | Modify | Add `firebase_analytics: ^11.3.3` |
| `lib/data/remote/analytics_service.dart` | **Create** | Service wrapper with named helpers, observer getter |
| `lib/data/providers/analytics_provider.dart` | **Create** | Riverpod `Provider<AnalyticsService>` |
| `lib/data/providers/telemetry_provider.dart` | Modify | Add `telemetryFacadeProvider` fanning out to admin + analytics |
| `lib/data/remote/telemetry_facade.dart` | **Create** | Thin class implementing fan-out methods |
| `lib/main.dart` | Modify | (optional) explicit init call after `_initFirebaseAppCheck` |
| `lib/app.dart` | Modify | After user load: `setUserId`, `setUserProperty`, route through facade for `logSessionStart` |
| `lib/core/router/app_router.dart` | Modify | Convert `appRouter` → `appRouterProvider`, attach `FirebaseAnalyticsObserver` |
| `lib/data/providers/user_provider.dart` | Modify | Switch `_telemetry?` calls to `_facade?` (keeps admin telemetry; adds analytics) |
| `lib/data/remote/auth_service.dart` callers | Modify | Log `login` / `sign_up` after successful auth in `login_screen.dart`, `register_screen.dart` |
| `lib/features/onboarding/providers/onboarding_provider.dart` | Modify | Emit `tutorial_begin` / `tutorial_complete`; set persona/level/goal user properties |
| `lib/features/news/screens/news_detail_screen.dart` | Modify | Log `news_opened` in `initState` |
| `lib/features/news/widgets/news_action_bar.dart` | Modify | Log `news_saved` and `share` |
| `lib/features/tracks/screens/tracks_screen.dart` / `track_learn_screen.dart` | Modify | Log `track_started` / `track_completed` |
| `lib/features/tracks/providers/boss_quiz_provider.dart` | Modify | Log `quiz_answered` via facade |
| `lib/data/remote/news_push_service.dart` | Modify | Log `notification_open` on tap-handled deep link |
| `lib/features/profile/screens/profile_screen.dart` | Modify | Add analytics opt-out switch |
| `test/analytics_service_test.dart` | **Create** | Unit test with fake `FirebaseAnalytics` |

---

## 8. Sequencing (recommended commit order)

1. **Foundation** — package + service + provider + facade (no behaviour change yet).
2. **Initialization & screen tracking** — `app.dart` + `app_router.dart` (visible in DebugView already).
3. **Auth + onboarding events** — small, easy to verify.
4. **User-property setters** — funnel/audience-ready.
5. **Learning events** — card / quiz / xp / streak (re-route through facade).
6. **News + share + notification events**.
7. **Privacy toggle UI**.
8. **Tests + Play Store data-safety doc update**.

Each commit independently shippable; revert window is small if anything
regresses analytics in prod.

---

## 9. Out of Scope (not in this plan)

- iOS Firebase configuration (note as separate prerequisite — Phase 1 step 3).
- GA4 → BigQuery export configuration (Firebase console / billing change).
- Crashlytics (separate package, separate plan).
- A/B testing / Remote Config (separate plan).
- Server-side analytics dashboards.

---

## 10. SESSION_ID (for /ccg:execute use)

- CODEX_SESSION: _not used — codeagent-wrapper unavailable in this environment_
- GEMINI_SESSION: _not used — codeagent-wrapper unavailable in this environment_

> Multi-model wrappers (`~/.claude/bin/codeagent-wrapper`) were not installed in
> this environment, so the analysis was synthesized directly. `/ccg:execute`
> will need to be run without `resume <SESSION_ID>`.
