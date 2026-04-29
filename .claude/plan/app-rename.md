# Implementation Plan: Rename in-app branding "AIScroll" → "60 Second AI"

## Task Type
- [x] Frontend (Flutter / Dart string + class identifier rename)
- [ ] Backend
- [ ] Fullstack

## Scope (locked with user)

**In scope (Layers 1 + 2):**
- Layer 1 — User-visible display strings showing "AIScroll" inside the app
- Layer 2 — Dart class identifiers `AIScrollApp` / `_AIScrollAppState` and doc-comment mentions

**Out of scope (locked OFF):**
- Layer 3 — Dart package name in `pubspec.yaml` (`name: aiscroll`) — kept; tests rely on `import 'package:aiscroll/...'`
- Layer 4 — Native identifiers (Android `applicationId` `com.kj.aiscroll`, iOS bundle ID, Kotlin package directory, `google-services.json`) — **kept** because the app is already published to the Play Store under `com.kj.aiscroll`; changing the package ID would force a brand new Play listing and re-do all of yesterday's keystore + Firebase + App Check + Google Sign-In configuration.

## Technical Solution

Mechanical, two-pass text rename inside `lib/`. No native files, no test files, no `pubspec.yaml`, no `AndroidManifest.xml`, no iOS plist.

**Pass A — display strings:** Replace literal `'AIScroll'` and "AIScroll" appearing in Flutter widget trees, push fallback titles, and notification copy with `'60 Second AI'`.

**Pass B — Dart identifiers + doc comments:** Rename class `AIScrollApp` → `SixtySecondAIApp` (Dart class names cannot start with a digit; `AI` kept upper-case to match existing acronym style in the project). Update the single call site in `lib/main.dart`. Update doc comments (`/// …AIScroll…`) to say "60 Second AI".

After both passes, run `flutter analyze` + `flutter test` to confirm no broken references.

## Implementation Steps

1. **Pre-flight: capture current diff baseline** — `git status -sb` (or take a manual snapshot if no git). Deliverable: clean working tree confirmation.
2. **Pass A — rename display strings** (6 edits):
   - `lib/app.dart:130` — `title: 'AIScroll'` → `title: '60 Second AI'`
   - `lib/features/onboarding/screens/splash_screen.dart:52` — `'AIScroll'` → `'60 Second AI'`
   - `lib/features/onboarding/screens/welcome_screen.dart:102` — `'Welcome to AIScroll'` → `'Welcome to 60 Second AI'`
   - `lib/data/remote/news_push_service.dart:155` — fallback title `'AIScroll'` → `'60 Second AI'`
   - `lib/core/notifications/notification_service.dart:34` — `'Random AI news drops from the AIScroll team.'` → `'Random AI news drops from the 60 Second AI team.'`
   - `lib/features/profile/screens/profile_screen.dart:1069` — `'Breaking AI news from the AIScroll team.'` → `'Breaking AI news from the 60 Second AI team.'`
   - Deliverable: 6 files modified, all visible strings now read "60 Second AI".
3. **Pass B — rename Dart class** (in `lib/app.dart`, 4 line touches):
   - L16: `class AIScrollApp extends ConsumerStatefulWidget {` → `class SixtySecondAIApp extends ConsumerStatefulWidget {`
   - L17: `const AIScrollApp({super.key});` → `const SixtySecondAIApp({super.key});`
   - L20: `ConsumerState<AIScrollApp> createState() => _AIScrollAppState();` → `ConsumerState<SixtySecondAIApp> createState() => _SixtySecondAIAppState();`
   - L23: `class _AIScrollAppState extends ConsumerState<AIScrollApp>` → `class _SixtySecondAIAppState extends ConsumerState<SixtySecondAIApp>`
   - Deliverable: class renamed; file still compiles in isolation.
4. **Update class call site:**
   - `lib/main.dart:35` — `runApp(const ProviderScope(child: AIScrollApp()));` → `runApp(const ProviderScope(child: SixtySecondAIApp()));`
   - Deliverable: `flutter analyze` passes (no "undefined name `AIScrollApp`").
5. **Update doc comments** (cosmetic, non-functional, 5 edits):
   - `lib/main.dart:40` — comment "AIScroll client JWT in [AuthService]" → "60 Second AI client JWT in [AuthService]"
   - `lib/core/theme/app_theme.dart:7` — `/// Editorial theme for AIScroll.` → `/// Editorial theme for 60 Second AI.`
   - `lib/data/models/srs_model.dart:3` — "mapped to AIScroll interaction events" → "mapped to 60 Second AI interaction events"
   - `lib/data/remote/ads_service.dart:8` — "for the AIScroll project" → "for the 60 Second AI project"
   - `lib/data/remote/auth_service.dart:36` — "signed AIScroll client JWT" → "signed 60 Second AI client JWT"
   - Deliverable: no `AIScroll` (case-sensitive) hits left under `lib/` other than tooling-generated files.
6. **Verify:**
   - `flutter analyze` — must finish with 0 issues attributable to this change.
   - `flutter test` — all existing tests must still pass (they do not reference `AIScrollApp` and import the unchanged `package:aiscroll`).
   - Manual smoke: cold-launch app, confirm splash shows "60 Second AI", welcome screen shows "Welcome to 60 Second AI", AppBar title and push notification fallback read "60 Second AI".
   - Sanity grep: ``grep -rn "AIScroll" lib/`` should return zero hits. Hits under `android/`, `ios/`, `pubspec.yaml`, `test/`, `.idea/`, `.gradle/` are expected and intentional (out-of-scope identifiers).

## Key Files

| File | Operation | Description |
|------|-----------|-------------|
| `lib/app.dart:16,17,20,23,130` | Modify | Rename class `AIScrollApp`→`SixtySecondAIApp`, state `_AIScrollAppState`→`_SixtySecondAIAppState`, MaterialApp `title`. |
| `lib/main.dart:35,40` | Modify | Update `AIScrollApp()` call site + doc comment. |
| `lib/features/onboarding/screens/splash_screen.dart:52` | Modify | Splash big-text. |
| `lib/features/onboarding/screens/welcome_screen.dart:102` | Modify | Welcome heading. |
| `lib/data/remote/news_push_service.dart:155` | Modify | FCM push fallback title. |
| `lib/core/notifications/notification_service.dart:34` | Modify | Local notification description string. |
| `lib/features/profile/screens/profile_screen.dart:1069` | Modify | Profile screen subtitle. |
| `lib/core/theme/app_theme.dart:7` | Modify | Doc comment. |
| `lib/data/models/srs_model.dart:3` | Modify | Doc comment. |
| `lib/data/remote/ads_service.dart:8` | Modify | Doc comment. |
| `lib/data/remote/auth_service.dart:36` | Modify | Doc comment. |
| `pubspec.yaml` | **No change** | `name: aiscroll` retained — test imports depend on it. |
| `android/app/src/main/AndroidManifest.xml` | **No change** | `android:label` is already `"60 Second AI - AI News"`. Optionally change to plain `"60 Second AI"` — see Open Question below. |
| `android/app/build.gradle.kts`, `android/app/google-services.json`, `android/app/src/main/kotlin/com/kj/aiscroll/MainActivity.kt`, iOS `Runner.xcodeproj`, etc. | **No change** | `com.kj.aiscroll` package ID is locked by Play Store publication. |

## Risks and Mitigation

| Risk | Mitigation |
|------|------------|
| Missed call site of `AIScrollApp` causes `Undefined name` after rename. | Step 6 runs `flutter analyze` and final `grep -rn AIScroll lib/` to catch any straggler. Only one known call site (`main.dart:35`). |
| Tests break because they reference the renamed class. | Verified: no test file under `test/` references `AIScrollApp` — they only import `package:aiscroll/...` which is the unchanged Dart package name. |
| Push notification displayed name ("60 Second AI") inconsistent with launcher label ("60 Second AI - AI News"). | Flagged as Open Question below. Default behaviour: keep launcher label as-is; in-app name becomes "60 Second AI". |
| Future rebuild regenerates an `AIScroll` reference (e.g., `flutter create` re-derives display name from project dir name `aiscroll`). | Project dir name is unchanged so this won't trigger. The Flutter tool will not re-emit display strings — they were authored by the user. |
| Reviewers grep `AIScroll` and panic over hits in `android/`, `ios/`, tests, `pubspec.yaml`. | Plan explicitly documents which hits are intentionally retained and why. |

## Open Question (non-blocking — user can decide before /ccg:execute)

The Android launcher label is currently `"60 Second AI - AI News"` (set in `android/app/src/main/AndroidManifest.xml`). The new in-app name is `"60 Second AI"`. Two options:
- **(i) Leave launcher label as-is** — users see "60 Second AI - AI News" on the home screen and "60 Second AI" inside the app. Slightly inconsistent but Play Store listing already references the longer name.
- **(ii) Change launcher label to `"60 Second AI"`** — perfect consistency. Single-line change in AndroidManifest. This DOES change what users see on their home screen but does NOT change the Play Store app title or the package ID.

If user prefers (ii), add one extra step before Step 6: edit `android/app/src/main/AndroidManifest.xml` `android:label="60 Second AI - AI News"` → `android:label="60 Second AI"`, plus the iOS `CFBundleDisplayName` in `ios/Runner/Info.plist` if it currently says "AIScroll" (to be confirmed).

Default in this plan: **(i)** — minimal surface area.

## Out-of-Scope Hits (intentionally left untouched)

These will still match a recursive `grep aiscroll` after the rename — that is **expected and correct**:

- `pubspec.yaml: name: aiscroll`
- `android/app/build.gradle.kts` — `applicationId = "com.kj.aiscroll"`, `namespace = "com.kj.aiscroll"`
- `android/app/google-services.json` — `package_name: "com.kj.aiscroll"`
- `android/app/src/main/kotlin/com/kj/aiscroll/MainActivity.kt` — directory + package
- `ios/Runner.xcodeproj/project.pbxproj` — bundle identifier
- `ios/Flutter/flutter_export_environment.sh`, `ios/Flutter/Generated.xcconfig` — generated, mirror pubspec
- `test/*.dart` — `import 'package:aiscroll/...'` (refers to Dart package, not branding)
- `.idea/`, `.gradle/`, `build/` — IDE/build artefacts

## SESSION_ID (for /ccg:execute use)

- CODEX_SESSION: _none_ (codeagent-wrapper not installed on this host; Phase 2.1/2.3 model calls skipped — fall back was Claude direct synthesis with full context retrieved in Phase 1)
- GEMINI_SESSION: _none_ (same reason)

When you run `/ccg:execute .claude/plan/app-rename.md`, the executor should treat this as a Claude-only plan and proceed without resuming external sessions.
