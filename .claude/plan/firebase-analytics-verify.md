# Implementation Plan: Verify Firebase Analytics Is Working

## 1. Restated Requirement

Firebase Analytics has been integrated (`firebase_analytics ^11.3.3`,
`AnalyticsService`, `FirebaseAnalyticsObserver` on the GoRouter). We need to
**verify it is actually emitting events** that reach the Firebase Console for
project `second-ai-bd78a`.

This is a **verification / QA** plan, not a feature plan. It does not add
product features — it adds the diagnostics and runs the smoke tests required
to prove the pipeline end-to-end.

---

## 2. Task Type

- [ ] Frontend (UI/UX)
- [ ] Backend
- [x] **Mobile + tooling / verification** (Android-only at the moment — iOS
      is unconfigured in `firebase_options.dart`)
- [ ] Fullstack

---

## 3. Existing State (verified by reading the code)

| Area | Current state | Source |
|------|---------------|--------|
| SDK | `firebase_analytics: ^11.3.3` installed | `pubspec.yaml:38` |
| Wrapper | `AnalyticsService` — fire-and-forget, swallows all errors via `debugPrint` | `lib/data/remote/analytics_service.dart` |
| **Default-off in debug** | `_enabled = _prefs.getBool('analytics.enabled') ?? !kDebugMode` — debug builds default to **disabled** | `analytics_service.dart:43` |
| **Firebase availability captured at construction** | `final bool _firebaseAvailable = Firebase.apps.isNotEmpty;` — must be read **after** `Firebase.initializeApp()` | `analytics_service.dart:24` |
| Provider | Lazy singleton via Riverpod | `lib/data/providers/analytics_provider.dart` |
| Init order | `Firebase.initializeApp()` runs in `main()` before `runApp`. `AnalyticsService.init()` runs in the post-frame callback in `app.dart`, after Firebase exists. | `lib/main.dart:46-71`, `lib/app.dart:67` |
| Auto screen views | `FirebaseAnalyticsObserver` on `GoRouter.observers` with `nameExtractor: (s) => s.name ?? 'unnamed'`. Falls back to empty list when `Firebase.apps.isEmpty`. | `lib/core/router/app_router.dart:149-159, 165` |
| User properties stamped on boot | `persona`, `knowledge_level`, `daily_goal`, `is_guest`, `is_premium` + `setUserId` | `lib/app.dart:87-94` |
| Telemetry fan-out | `TelemetryService.log()` mirrors every named event to `AnalyticsService.logEvent` first, **even when admin URL is unconfigured** | `lib/data/remote/telemetry_service.dart:81-87` |
| Android Gradle wiring | `com.google.gms.google-services` plugin applied, `google-services.json` present | `android/app/build.gradle.kts:6-8`, `android/app/google-services.json` |
| iOS | **Not configured** — `DefaultFirebaseOptions.iOS` throws `UnsupportedError` | `lib/firebase_options.dart:29` |
| App Check debug token | `e774623b-1a63-4715-8500-d8094701a491` (already registered?) | `my_debug_token.md` |

**Critical implications for verification:**

1. **A normal `flutter run` (debug) will NOT send events** — analytics is
   disabled by default in `kDebugMode`. You must either flip the opt-out via
   the Profile screen, or run in profile/release mode, or temporarily change
   the default in `analytics_service.dart` for testing.
2. **Errors are swallowed.** A misconfigured plugin, missing
   `google-services.json`, or App Check rejection will produce **silent
   failures** — only a `debugPrint`. We cannot rely on absence-of-crash as
   evidence of success.
3. **DebugView requires an explicit adb command** to mark the device as a
   debug device — it is not automatic, even if the app is a debug build.
4. **iOS analytics will throw** the moment we test on iOS, because
   `DefaultFirebaseOptions.currentPlatform` raises before `Firebase.initializeApp`
   can succeed. iOS is out of scope for this verification.

---

## 4. Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Verification appears to succeed in DebugView but real users don't show up because `_enabled = false` in release for first launch (it isn't — `!kDebugMode` is `true` in release; verified). | Add a release-build smoke test on a non-debug device; check Realtime / StreamView in console. |
| Console shows nothing because Firebase project / API key in `firebase_options.dart` was rotated or doesn't match the Console project. | Confirm `projectId: 'second-ai-bd78a'` matches the project the user has open in console; confirm `appId` matches the Android app entry. |
| `google-services.json` in repo is stale (different SHA / different project than `firebase_options.dart`). | `diff` the `project_info.project_id` in `google-services.json` against `firebase_options.dart`'s `projectId`. |
| App Check blocks Analytics requests because the device's debug token isn't registered. | Analytics doesn't require App Check enforcement — it uses a separate transport. But check the Firebase Console → App Check → Analytics enforcement: should be **unenforced** during verification. |
| Events are dispatched but bucketed in the wrong app instance because `setUserId` was called with a stale guest UUID. | Use the `app_instance_id` shown in `adb logcat` `FA` output, not the user id, to correlate to DebugView. |
| `kDebugMode` is true on a profile build too (it isn't — `kDebugMode` is `false` in profile/release). | Verified: profile/release have `_enabled = true` by default. |
| Engineer runs Firebase Console → Realtime and waits 30 seconds — Realtime panel actually has a several-minute delay; only DebugView is sub-minute. | Use **DebugView** as the source of truth; treat Realtime / Events / StreamView as eventual confirmation (up to 24h for the Events report). |
| The Riverpod `analyticsServiceProvider` is constructed before Firebase init for some early reader. | Verified read order in `app.dart:67` is post-frame, after `_initFirebaseAppCheck()` in `main.dart`. But add a defensive log in `init()` printing `_firebaseAvailable` to confirm. |

---

## 5. Verification Pipeline (end-to-end)

```
┌──────────────────────────────────────────────────────────────────┐
│  Step A. Static checks (zero device needed)                      │
│   1. Project IDs match across firebase_options.dart and          │
│      google-services.json                                         │
│   2. Gradle plugin applied (already verified)                    │
│   3. AnalyticsService init order is post-Firebase (verified)     │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│  Step B. Add temporary diagnostics (one-line debugPrint)         │
│   - Print `_firebaseAvailable` on init()                         │
│   - Print event name on every successful logEvent                │
│   - Print user id / app_instance_id once at boot                 │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│  Step C. DebugView smoke test (Android, debug build)             │
│   1. `adb shell setprop debug.firebase.analytics.app             │
│       com.kj.aiscroll`                                           │
│   2. Toggle "Help improve the app" ON in Profile (or temporarily │
│      flip the default in analytics_service.dart:43)              │
│   3. `flutter run` and exercise the smoke matrix (§6)            │
│   4. Watch Firebase Console → Analytics → DebugView in real time │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│  Step D. logcat correlation                                      │
│   - `adb logcat -s FA FA-SVC` — confirm "Logging event" lines    │
│     and "Connection established" / "Bundles uploaded" lines      │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│  Step E. Release-build sanity (optional but recommended)          │
│   - `flutter build apk --release` → install → exercise           │
│   - Verify Realtime panel in Firebase Console (5–10 min lag)     │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│  Step F. Cleanup                                                 │
│   - Revert temporary debugPrint diagnostics                      │
│   - Restore default for `_enabled` if temporarily flipped        │
└──────────────────────────────────────────────────────────────────┘
```

---

## 6. Smoke-Test Matrix (the events you should see in DebugView)

Run these after Step C is in place. Each should produce one or more
identified events in DebugView within ~10 seconds.

| User action | Expected event(s) | Source |
|-------------|-------------------|--------|
| Cold start app | `app_open` (Firebase auto) + `session_start` | auto + `analytics_service.dart:120` |
| Tap through onboarding screens | `screen_view` per route | router observer |
| Complete onboarding | `tutorial_complete` | `logTutorialComplete()` |
| Email/password signup | `sign_up` (method=`password`) | `analytics_service.dart:114` via onboarding/register_screen |
| Google sign-in | `login` (method=`google`) | `analytics_service.dart:117` via login_screen |
| Open a news article | `news_opened` + `screen_view` (news_detail) | telemetry fan-out + observer |
| Mark article as read (scroll to bottom) | `news_read` | telemetry fan-out |
| Bookmark / unbookmark article | `news_bookmark_add` / `news_bookmark_remove` | telemetry fan-out |
| Share article | `share` (Firebase predefined) | `analytics_service.dart:177` |
| View a learning card | `card_viewed` (card_id, dwell_ms, was_due) | telemetry fan-out |
| Mark card learned | `card_learned` | telemetry fan-out |
| Answer quiz | `quiz_answered` (quiz_id, card_id, correct, selected) | telemetry fan-out |
| Earn XP | `xp_awarded` | telemetry fan-out |
| Maintain a streak | `streak_day` | telemetry fan-out |
| Toggle profile analytics opt-out | (subsequent events stop appearing) | `setAnalyticsCollectionEnabled` |

User-property panel in DebugView should show: `persona`,
`knowledge_level`, `daily_goal`, `is_guest`, `is_premium`.

---

## 7. Implementation Steps

### Step 1 — Static parity check (no code changes)

1. Open `lib/firebase_options.dart` — note `projectId: 'second-ai-bd78a'`,
   `appId: '1:491758021602:android:fa232ae2d5ef414569a7bb'`.
2. Open `android/app/google-services.json` — confirm
   `project_info.project_id` is `second-ai-bd78a` and the matching
   `client_info.mobilesdk_app_id` equals the Dart `appId`.
3. Confirm in Firebase Console that **Google Analytics** is **enabled**
   on the `second-ai-bd78a` project (Project Settings → Integrations →
   Google Analytics — must be linked to a GA4 property; otherwise events
   silently disappear).

   **Deliverable:** confirmed config parity, GA4 link verified, OR a list
   of mismatches to fix before proceeding.

### Step 2 — Add a one-shot diagnostic in `AnalyticsService`

Edit `lib/data/remote/analytics_service.dart` (temporary, reverted in
Step 7):

```dart
// In init():
debugPrint('[Analytics] init: firebaseAvailable=$_firebaseAvailable '
           'enabled=$_enabled kDebugMode=$kDebugMode');
if (_firebaseAvailable) {
  // Print app_instance_id so we can match logs to DebugView.
  // ignore: discarded_futures
  _analytics.appInstanceId.then(
    (id) => debugPrint('[Analytics] app_instance_id=$id'),
  );
}

// In logEvent(), AFTER the await succeeds:
debugPrint('[Analytics] sent event=$name params=$params');
```

   **Deliverable:** boot-time line proving Firebase is available, and a
   per-event line proving each call passed sanitisation and was handed to
   the SDK.

### Step 3 — Force-enable analytics for testing

Two safe options — pick one:

1. **Runtime path (preferred, no code change):** in the Profile screen,
   toggle "Help improve the app" ON. This calls
   `analytics.setEnabled(true)` and persists `analytics.enabled = true`,
   overriding the `!kDebugMode` default.
2. **Code path (temporary):** flip the default at
   `lib/data/remote/analytics_service.dart:43` to:

   ```dart
   _enabled = _prefs.getBool(_kEnabledPref) ?? true;
   ```

   Revert in Step 7. Use this only if option 1 is awkward (e.g. on a
   blank user with no Profile screen reachable).

   **Deliverable:** boot log line shows `enabled=true`.

### Step 4 — Mark the device as a DebugView device

```bash
adb shell setprop debug.firebase.analytics.app com.kj.aiscroll
```

To clear later: `adb shell setprop debug.firebase.analytics.app .none.`

The applicationId is from `android/app/build.gradle.kts:42`
(`applicationId = "com.kj.aiscroll"`).

   **Deliverable:** within ~30 seconds of the next app launch, the
   device shows up in **Firebase Console → Analytics → DebugView**.

### Step 5 — Run the smoke matrix from §6

1. `flutter run -d <android-device>` (debug is fine — diagnostics are
   already in place).
2. Run through every row in §6. Mark pass/fail per row, screenshot the
   DebugView stream as evidence.
3. In a second terminal, watch:

   ```bash
   adb logcat -v time -s FA FA-SVC flutter
   ```

   - `[Analytics] sent event=...` is our diagnostic — proves the call
     reached `logEvent`.
   - `FA: Logging event ...` proves the SDK accepted it.
   - `FA-SVC: Bundles uploaded` proves the device flushed to GA.

   **Deliverable:** filled-in smoke matrix with screenshots; any failing
   rows become bugs to fix.

### Step 6 — Release-build confirmation

1. `flutter build apk --release` and install on a non-debug device (or
   the same device with the debug-prop cleared).
2. Open the app, sign in, browse a couple of articles, share one.
3. Wait 10–15 minutes, then open **Realtime** in the Firebase Console.
   Expect at least 1 active user and the events you exercised.

   **Deliverable:** Realtime panel screenshot showing the active session
   and at least one of: `news_opened`, `card_viewed`, `share`.

### Step 7 — Revert diagnostics

1. Remove the three `debugPrint` lines added in Step 2.
2. If Step 3 used the code path, restore
   `_enabled = _prefs.getBool(_kEnabledPref) ?? !kDebugMode;`.
3. `flutter analyze` to confirm clean.

   **Deliverable:** clean diff that reverts to the checked-in
   `analytics_service.dart` modulo any genuine bugs found in Step 5.

### Step 8 (only if any §6 row failed) — Triage

Read the diagnostic logs to localise:

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `[Analytics] init: firebaseAvailable=false` | `Firebase.initializeApp()` failed (App Check error swallowed in `main.dart:68-70`). | Run with App Check init failures surfaced; check `google-services.json` parity; check device clock skew. |
| `[Analytics] init: enabled=false` even after Step 3 | `analytics.enabled` pref not persisted, or Profile toggle didn't call `setEnabled(true)`. | Inspect `PreferencesService` storage; confirm Profile toggle handler. |
| `[Analytics] sent event=...` lines appear but DebugView is empty | Device not flagged as debug device, or wrong applicationId in `setprop`. | Re-run `adb shell setprop debug.firebase.analytics.app com.kj.aiscroll`. |
| DebugView still empty in release Realtime | GA4 property not linked, or app's `appId` in `firebase_options.dart` doesn't match the Console's Android app. | Re-run FlutterFire CLI: `flutterfire configure --project=second-ai-bd78a`. |
| `FA: Discarding event because no Google App Id` in logcat | `google-services.json` not picked up by Gradle (clean build needed). | `flutter clean && flutter pub get && flutter run`. |
| Events fire on Android but iOS crashes | Expected — iOS isn't configured. | Out of scope for this plan; tracked as the FlutterFire-iOS follow-up. |

---

## 8. Key Files

| File | Operation | Description |
|------|-----------|-------------|
| `lib/data/remote/analytics_service.dart:42-50, 86-99` | Temporarily edit (Step 2) | Add three `debugPrint` lines: init state, app_instance_id, per-event confirm. Reverted in Step 7. |
| `lib/data/remote/analytics_service.dart:43` | Optionally edit (Step 3, option 2) | Flip default to `?? true` for testing. Revert in Step 7. |
| `android/app/google-services.json` | Read only (Step 1) | Confirm `project_info.project_id == "second-ai-bd78a"` and the `mobilesdk_app_id` matches `firebase_options.dart`. |
| `lib/firebase_options.dart:55-61` | Read only | Source of truth for Dart-side Firebase config. |
| `android/app/build.gradle.kts:6-8, 42` | Read only | Confirm Gradle plugin + `applicationId = "com.kj.aiscroll"`. |
| `lib/main.dart:46-71` | Read only | Confirm Firebase init runs before `runApp`. |
| `lib/app.dart:67-94` | Read only | Confirm `analyticsServiceProvider.init()` and `setUserId/setUserProperty` ordering. |
| `lib/core/router/app_router.dart:149-159, 165` | Read only | Confirm `FirebaseAnalyticsObserver` is wired. |

**No production-logic changes are required for verification** — only
temporary diagnostics that get reverted at the end.

---

## 9. Done Criteria

- [ ] §6 smoke matrix is green (every row produces the expected event in
      DebugView within ~10 seconds of the action).
- [ ] User properties (`persona`, `knowledge_level`, `daily_goal`,
      `is_guest`, `is_premium`) are visible in the DebugView right-hand
      panel.
- [ ] At least one release-build session shows up in Realtime within 15
      minutes (Step 6).
- [ ] Diagnostic `debugPrint` lines from Step 2 are reverted.
- [ ] Any failures from §6 are either fixed or tracked as separate
      tickets.

---

## 10. Out of Scope

- iOS analytics (no `firebase_options` for iOS yet, and no
  `GoogleService-Info.plist`).
- BigQuery export, audience configuration, conversions, attribution
  setup — those are Console-side configuration, not app-side
  verification.
- Web / desktop platforms.

---

## 11. SESSION_ID (for /ccg:execute use)

- CODEX_SESSION: _(not invoked — `~/.claude/bin/codeagent-wrapper` not
  installed in this environment; falling back to Claude-only synthesis.)_
- GEMINI_SESSION: _(not invoked — same reason.)_

If multi-model planning is desired before execution, install
`codeagent-wrapper` and re-run `/everything-claude-code:multi-plan` with
the same prompt.
