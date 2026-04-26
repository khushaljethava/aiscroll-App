# Implementation Plan: Fix AIScroll App Issues

> **Scope**: Find and fix correctness, state-management, security, and UX bugs across the AIScroll Flutter app.
> **Audit basis**: Read of all 39 dart files in `lib/` + `flutter analyze` (16 deprecation warnings) + independent architect cross-check.

---

## Task Type
- [x] Frontend (Flutter widgets, navigation)
- [x] Backend (state, persistence, providers)
- [x] Fullstack (cross-cutting refactor)

---

## Issues Inventory (severity-ranked)

### CRITICAL

| # | File:line | Bug |
|---|-----------|-----|
| C1 | `features/profile/screens/profile_screen.dart:620-627` | **Sign-out is broken** — clears `isGuest` but not `_kOnboardingComplete`. Router `redirect` (`app_router.dart:111`) bounces `/onboarding/splash` straight back to `/home`. |
| C2 | `features/ai_chat/screens/ai_chat_sheet.dart:44-115` | **Anthropic API key shipped in client binary** via `String.fromEnvironment`. Trivially extractable from APK/IPA → uncapped billing risk. |
| C3 | `app.dart:13-15` | **`addPostFrameCallback` inside `build()`** schedules `userProvider.notifier.load()` on every rebuild. Each `load()` overwrites in-memory state with disk state → races silently revert XP/bookmarks. |

### HIGH

| # | File:line | Bug |
|---|-----------|-----|
| H1 | `features/challenges/screens/challenges_screen.dart:12-13` | **Daily quests are inert** — `dailyQuestsProvider` is a `StateProvider<List<DailyQuest>>` initialized once with defaults and never mutated anywhere. Quest progress always shows 0/N. |
| H2 | `data/providers/user_provider.dart:75-113` | **`updateStreak()` is dead code** — declared but zero callsites. Streak shown on Home/Profile never increments. |
| H3 | `data/providers/user_provider.dart:163-171` | **`resetDailyCounters()` is dead code** — never called. `cardsReadToday` and `aiQuestionsToday` accumulate forever, never reset at midnight. |
| H4 | `data/providers/user_provider.dart:8-9` | **Guest UUID regenerates on every cold start** — `UserNotifier()` ctor calls `Uuid().v4()` synchronously; if `loadUserProfile()` returns null (first run / corrupted JSON) a fresh ID is created each launch. |
| H5 | `features/feed/screens/feed_screen.dart:71-77` | **XP farming via re-scroll** — `_awardReadXP` only blocks XP if card is in `learnedCardIds`. Re-scrolling the same "read but not learned" card grants infinite XP and inflates `cardsReadToday`. |
| H6 | `data/providers/user_provider.dart:40-49` + `feed_screen.dart:46-77` | **Daily-goal counter inflates on revisits** — `markCardRead` increments unconditionally; combined with H5, scrolling a single card up/down repeatedly hits the daily goal artificially. |
| H7 | `core/router/app_router.dart:103-113` | **GoRouter has no `refreshListenable`** — redirect reads prefs synchronously; flag changes (sign-out, account switch) don't re-trigger. Compounds C1. |
| H8 | `data/local/preferences_service.dart` (whole file) | **Phantom writes** — `saveTotalXP`, `saveStreak`, `saveDailyCardCount`, `saveLearnedCards`, `saveBookmarks`, `saveAIQuestionsToday`, `saveTrackProgress`, `saveLastActiveDate` are all called on every state mutation but **never read back**. `loadUserProfile()` is the sole reader → divergence risk + wasted I/O. |

### MEDIUM

| # | File:line | Bug |
|---|-----------|-----|
| M1 | `features/feed/screens/feed_screen.dart:106-117` | Overlay race — `_showSwipeOverlay` does `_swipeOverlay?.remove()` then assigns a new entry, but the 1200ms `Future.delayed` callback may try to `.remove()` an already-replaced entry, throwing "Overlay was already removed". |
| M2 | `features/feed/screens/feed_screen.dart:36-40` | `dispose()` does not remove `_swipeOverlay` — leak if screen disposed mid-animation. |
| M3 | `features/onboarding/screens/auth_screen.dart:23,79,120,152` | "Continue with Google", "Continue with Apple", and "Start without account" all call the same `_finishOnboarding`. Skip should keep `isGuest: true`; social buttons are placeholders without real auth. |
| M4 | `features/feed/widgets/quiz_card_widget.dart:38-43` | Skipped quizzes don't notify `onAnswer(false)`, so quest progress / streak logic can't track skips. |
| M5 | `features/feed/widgets/quiz_card_widget.dart:294` | Hardcoded "+30 XP" text in feedback row — should use `widget.question.xpReward`. |
| M6 | `data/models/card_model.dart:34-46` | `LearningCard.toMap()` drops `relatedCardIds` — round-trip serialization loses related cards. |
| M7 | `features/saved/screens/saved_screen.dart:43-65` | Group key is raw `card.trackId` ('ai101'), shown as-is in `_TrackHeader`. Should resolve to `LearningTrack.name` via `trackByIdProvider`. |
| M8 | `features/tracks/screens/track_detail_screen.dart:257-259` | Card tap shows `SnackBar('Opening card: ...')` — dead navigation, should jump into feed at that card. |
| M9 | `features/onboarding/screens/splash_screen.dart:17-25` | Splash hardcodes `context.go(onboardingPersona)`. If user already onboarded, the global redirect bounces to `/home` — visible flash. Splash should branch based on `isOnboardingCompleteSync()`. |
| M10 | `features/feed/widgets/learning_card_widget.dart:73-77` | `onTap` only does something when `expandedContent != null` — silent no-op for most cards. |
| M11 | `features/feed/widgets/learning_card_widget.dart:78-95` | `Container(height: screenHeight)` + outer 8px vertical margin overflows the PageView page → inner `SingleChildScrollView` scroll competes with PageView vertical paging. |
| M12 | `app.dart:22` | `themeMode: ThemeMode.dark` hardcoded; `lightTheme` is built but unreachable. Profile "Dark Mode" toggle is a no-op (`profile_screen.dart:584-589`). |
| M13 | `features/ai_chat/screens/ai_chat_sheet.dart:90` | AI question counter is incremented even when the API call fails. |
| M14 | `features/ai_chat/screens/ai_chat_sheet.dart:115` | Unsafe JSON parse: `response.data['content'][0]['text'] as String` — crashes on unexpected schema. |
| M15 | `features/ai_chat/screens/ai_chat_sheet.dart:370-385` | `_TypingIndicator` `_Dot` widget accepts `delay` param but renders static dots — no animation. |
| M16 | `features/onboarding/screens/splash_screen.dart:107-124` | `_LoadingDots` calls `repeat()` twice per controller (init + delayed) — animation jitter. |

### LOW (16 analyzer warnings — already enumerated by `flutter analyze`)

All are `withOpacity → withValues(alpha:)` deprecations across:
- `features/gamification/widgets/xp_popup_widget.dart` (3 hits)
- `features/onboarding/screens/auth_screen.dart` (1)
- `features/onboarding/screens/daily_goal_screen.dart` (6)
- `features/onboarding/screens/knowledge_level_screen.dart` (1)
- `features/onboarding/screens/persona_screen.dart` (2)
- `features/onboarding/screens/splash_screen.dart` (1)
- `features/onboarding/screens/topic_picker_screen.dart` (2)

### Other

- `pubspec.yaml:17` — `sqflite` and `path_provider` declared but **not imported anywhere** in `lib/`. Dead dependencies.
- `test/widget_test.dart` — Placeholder test only; no real coverage.

---

## Implementation Steps

### Phase 1 — Critical fixes (correctness blockers)

**Step 1.1: Fix sign-out flow (C1, H7, M9)**
- In `lib/data/local/preferences_service.dart`:
  - Add `static final ValueNotifier<int> revision = ValueNotifier(0);` (bump on every `saveOnboardingComplete` / `clearAll` / `saveUserProfile`).
- In `lib/core/router/app_router.dart`:
  - Pass `refreshListenable: PreferencesService.revision` to `GoRouter(...)`.
- In `lib/features/profile/screens/profile_screen.dart` `_signOut`:
  ```
  await PreferencesService.instance.clearAll();   // wipe everything
  await ref.read(userProvider.notifier).reset();  // new method
  if (context.mounted) context.go(AppRoutes.splash);
  ```
- Add `UserNotifier.reset()` that creates a fresh guest profile and saves it.
- In `lib/features/onboarding/screens/splash_screen.dart`:
  - On post-frame, branch: `final onboarded = PreferencesService.instance.isOnboardingCompleteSync(); context.go(onboarded ? home : onboardingPersona);` after the 2.5s splash animation.

**Step 1.2: Move AI key off the device (C2)**
- Short-term mitigation in `lib/features/ai_chat/screens/ai_chat_sheet.dart`:
  - Replace direct Anthropic call with a placeholder that always returns `_mockResponse` and add a `// SECURITY: never embed Anthropic keys client-side` block comment.
  - Remove the `_apiKey`/`_sendToDio` codepath entirely.
- Add a `lib/data/remote/ai_service.dart` stub with a `Future<String> ask(String userMsg, LearningCard ctx)` interface (calls a TODO backend URL) so the UI can be wired to a proxy later.
- Document in `README.md`: "AI chat requires a server-side proxy. See `lib/data/remote/ai_service.dart`."

**Step 1.3: Fix the `app.dart` reload loop (C3)**
- Convert `lib/app.dart` `AIScrollApp` from `ConsumerWidget` to `ConsumerStatefulWidget`.
- Move `ref.read(userProvider.notifier).load()` into `initState` (post-frame, once).
- Alternative: load before `runApp()` in `lib/main.dart`:
  ```
  await PreferencesService.init();
  final container = ProviderContainer();
  await container.read(userProvider.notifier).load();
  runApp(UncontrolledProviderScope(container: container, child: const AIScrollApp()));
  ```

### Phase 2 — High severity (state correctness)

**Step 2.1: Wire up daily quest progress (H1)**
- Refactor `lib/features/challenges/screens/challenges_screen.dart`:
  - Replace `dailyQuestsProvider = StateProvider<List<DailyQuest>>(...)` with a `StateNotifierProvider<QuestsNotifier, List<DailyQuest>>` exposing `recordEvent(QuestType, int delta)`.
- Add hooks from `UserNotifier`:
  - `markCardRead` → `recordEvent(readCards, 1)`
  - `markCardLearned` → `recordEvent(learnNew, 1)`
  - `recordQuizPass` → `recordEvent(passQuiz, 1)`
  - `LearningCardWidget._handleShare` → `recordEvent(shareCard, 1)`
- On quest completion (canComplete), award `xpReward` and mark `isCompleted: true`.
- Persist quest state in `PreferencesService` (`saveDailyQuests` / `loadDailyQuests` keyed by date so they reset at midnight).

**Step 2.2: Bring streak + daily reset to life (H2, H3)**
- In `UserNotifier.load()`:
  - After loading, compare stored `lastActiveDate` to today. If different calendar day → call `resetDailyCounters()` and `updateStreak()` (which already implements 0/+1/reset semantics).
- In `markCardRead`:
  - Call `updateStreak()` so the streak ticks on first activity each day.
- Confirm `_StreakWidget` in feed and `_StreakCalendar` in profile re-render correctly afterward.

**Step 2.3: Persist guest UUID stably (H4)**
- In `PreferencesService`: add `_kGuestId` key, plus `saveGuestId(String)` / `loadGuestId()`.
- In `UserNotifier` constructor: change `super(UserProfile(id: const Uuid().v4(), isGuest: true));` to read from prefs synchronously (or load lazily). Concrete fix:
  ```
  factory UserNotifier.create() {
    final id = PreferencesService.instance.loadGuestIdSync()
            ?? (() { final id = Uuid().v4(); PreferencesService.instance.saveGuestId(id); return id; })();
    return UserNotifier._(id);
  }
  ```
- Update the provider to use the factory.

**Step 2.4: Stop XP farming + daily-goal inflation (H5, H6)**
- In `lib/features/feed/screens/feed_screen.dart` `_awardReadXP`:
  - Maintain a per-session `Set<String> _readThisSession` in `_FeedScreenState`.
  - Short-circuit if `_readThisSession.contains(card.id)` OR `user.learnedCardIds.contains(card.id)` OR (preferred) check a new `UserProfile.readCardIdsToday` set.
- Add `readCardIdsToday: Set<String>` to `UserProfile` (and serialize). `markCardRead` becomes idempotent per card per day.
- `_awardReadXP` only triggers when the card transitions to "newly read today".

**Step 2.5: Collapse phantom writes (H8)**
- Delete from `PreferencesService`: `saveTotalXP`, `loadTotalXP`, `saveStreak`, `loadStreak`, `saveDailyCardCount`, `loadDailyCardCount`, `saveLearnedCards`, `loadLearnedCards`, `saveBookmarks`, `loadBookmarks`, `saveAIQuestionsToday`, `loadAIQuestionsToday`, `saveTrackProgress`, `loadTrackProgress`, `saveLastActiveDate`, `loadLastActiveDate`.
- Keep only: `saveOnboardingComplete`/`isOnboardingCompleteSync`, `saveUserProfile`/`loadUserProfile`, `saveGuestId`/`loadGuestId`, `saveDailyQuests`/`loadDailyQuests`, `clearAll`.
- Strip the 8 redundant calls inside `UserNotifier` (every `save…` call after `saveUserProfile`).

### Phase 3 — Medium severity (UX + safety polish)

**Step 3.1: Fix overlay lifecycle (M1, M2)**
- In `lib/features/feed/screens/feed_screen.dart`:
  - Track overlay with a `Timer? _overlayTimer` and an explicit `_dismissOverlay()` helper that nulls before remove and cancels the timer.
  - In `dispose()`: `_overlayTimer?.cancel(); _swipeOverlay?.remove(); _swipeOverlay = null;`.

**Step 3.2: Onboarding semantics (M3)**
- "Continue with Google" / "Continue with Apple" → keep `_finishOnboarding` but rename to `_continueWithSocial(String provider)`. Set `isGuest: false` and persist a placeholder `name: 'Guest (Google)'` until real auth is wired.
- "Start without account" → call a new `_continueAsGuest` that sets `isGuest: true` but still saves `_kOnboardingComplete = true`.
- Document at top of file: `// TODO: replace with Firebase Auth (or Sign in with Apple) integration`.

**Step 3.3: Quiz polish (M4, M5)**
- `quiz_card_widget.dart:_skip()` → call `widget.onAnswer(false)` before `widget.onNext()`.
- `_AnswerFeedback` "+30 XP" string → take `xpReward` parameter from the question.

**Step 3.4: Model fixes (M6)**
- `LearningCard.toMap()` → include `'relatedCardIds': relatedCardIds`.
- `LearningCard.fromMap()` → read it back with `List<String>.from(m['relatedCardIds'] ?? const [])`.

**Step 3.5: Saved screen track names (M7)**
- In `_groupByTrack`, group by `LearningTrack.name` resolved via `ref.watch(trackByIdProvider(card.trackId))?.name ?? card.trackId`.

**Step 3.6: Track detail card tap (M8)**
- Replace `SnackBar` with a navigation that pushes `/home` and seeds the feed `currentFeedIndexProvider` to the matching card index. Or open `AIChatSheet`/expanded card preview as a quick-look.

**Step 3.7: AI chat hardening (M13, M14, M15)**
- Wrap the future in try/catch; only `incrementAIQuestions` on success.
- Validate response shape: `final content = (response.data is Map) ? response.data['content'] : null; final text = (content is List && content.isNotEmpty) ? content[0]['text'] : null;` with fallback string.
- Replace `_Dot` with `AnimatedOpacity`/`flutter_animate` so the typing indicator actually pulses.

**Step 3.8: Card height + tap UX (M10, M11)**
- Remove `height: screenHeight` from `LearningCardWidget`; let PageView's full-page constraint drive height.
- If card has no `expandedContent`, `onTap` should call `widget.onLike()` (or no-op silently with a haptic so the user gets feedback).

**Step 3.9: Theme + dark mode toggle (M12)**
- Add a `themeModeProvider = StateProvider<ThemeMode>((_) => ThemeMode.dark);` (persisted).
- Wire `app.dart` → `themeMode: ref.watch(themeModeProvider)`.
- Wire `profile_screen.dart` `SwitchListTile` → `onChanged: (v) => ref.read(themeModeProvider.notifier).state = v ? ThemeMode.dark : ThemeMode.light;`

**Step 3.10: Splash dot animation (M16)**
- Remove the second `repeat()` call; rely solely on the constructor-set period. Or remove the per-controller `Future.delayed` and use a single `AnimationController` driving 3 `Tween`s with phase offsets.

### Phase 4 — Low severity (analyzer cleanup)

**Step 4.1: Replace all `withOpacity` (16 sites)**
- `withOpacity(x)` → `withValues(alpha: x)` in:
  - `xp_popup_widget.dart` lines 45, 48, 53
  - `auth_screen.dart` line 169
  - `daily_goal_screen.dart` lines 156, 162, 173, 174, 207, 208
  - `knowledge_level_screen.dart` line 169
  - `persona_screen.dart` lines 128, 134
  - `splash_screen.dart` line 149
  - `topic_picker_screen.dart` lines 113, 169
- Re-run `flutter analyze` to confirm 0 issues.

### Phase 5 — Cleanup + safety net

**Step 5.1: Remove dead dependencies**
- Remove `sqflite: ^2.3.3+1` and `path_provider: ^2.1.3` from `pubspec.yaml` (unused).
- Run `flutter pub get`.

**Step 5.2: Add minimal regression tests** (`test/`)
- `test/data/preferences_service_test.dart` — round-trip save/load profile.
- `test/data/user_provider_test.dart` — `markCardRead` idempotency, `updateStreak` 0/+1/reset transitions.
- `test/features/challenges/quests_notifier_test.dart` — quest progress + completion.
- `test/features/onboarding/onboarding_provider_test.dart` — toggleTopic, completeOnboarding writes profile.
- Replace `test/widget_test.dart` placeholder with a smoke test that boots `AIScrollApp` and asserts splash renders.

**Step 5.3: Verify**
- `flutter analyze` → 0 issues.
- `flutter test` → all green.
- Manual: complete onboarding → read 5 cards → verify daily quest progresses → sign out from profile → verify routed back to splash → re-onboard.

---

## Key Files

| File | Operation | Description |
|------|-----------|-------------|
| `lib/data/local/preferences_service.dart` | **Refactor** | Add `revision` ValueNotifier + `saveGuestId` + `saveDailyQuests`; remove 8 phantom save/load pairs |
| `lib/data/providers/user_provider.dart` | **Refactor** | Use guest-ID factory; wire `updateStreak` + `resetDailyCounters` into `load`/`markCardRead`; collapse redundant writes; add `reset()` and `readCardIdsToday` |
| `lib/data/models/user_model.dart` | **Modify** | Add `Set<String> readCardIdsToday` field with serialization |
| `lib/data/models/card_model.dart` | **Modify** | Include `relatedCardIds` in `toMap`/`fromMap` |
| `lib/core/router/app_router.dart` | **Modify** | Add `refreshListenable: PreferencesService.revision` |
| `lib/app.dart` | **Refactor** | `ConsumerStatefulWidget`; `load` once in `initState`; subscribe `themeModeProvider` |
| `lib/main.dart` | **Modify** | Optionally pre-load profile before `runApp` |
| `lib/features/profile/screens/profile_screen.dart` | **Modify** | `_signOut` → `clearAll` + `reset` + go-splash; wire dark-mode switch |
| `lib/features/onboarding/screens/splash_screen.dart` | **Modify** | Branch on `isOnboardingCompleteSync` after delay; remove duplicate animation `repeat` |
| `lib/features/onboarding/screens/auth_screen.dart` | **Modify** | Split skip vs social paths; preserve `isGuest` for skip |
| `lib/features/feed/screens/feed_screen.dart` | **Refactor** | `_readThisSession` set; safer overlay lifecycle; dispose cleans overlay |
| `lib/features/feed/widgets/learning_card_widget.dart` | **Modify** | Remove `height: screenHeight`; better `onTap` UX |
| `lib/features/feed/widgets/quiz_card_widget.dart` | **Modify** | `_skip` calls `onAnswer(false)`; XP text uses `xpReward` |
| `lib/features/challenges/screens/challenges_screen.dart` | **Refactor** | New `QuestsNotifier`; persisted; bump on user actions |
| `lib/features/saved/screens/saved_screen.dart` | **Modify** | Group by track name, not raw ID |
| `lib/features/tracks/screens/track_detail_screen.dart` | **Modify** | Real navigation for card tap |
| `lib/features/ai_chat/screens/ai_chat_sheet.dart` | **Refactor** | Remove client-side Anthropic key path; defensive JSON parse; only count successful AI questions; animate typing dots |
| `lib/features/gamification/widgets/xp_popup_widget.dart` | **Modify** | `withOpacity` → `withValues(alpha:)` |
| `lib/features/onboarding/screens/*.dart` | **Modify** | `withOpacity` → `withValues(alpha:)` (8 files) |
| `pubspec.yaml` | **Modify** | Remove `sqflite`, `path_provider` |
| `test/*` | **Add** | New unit tests |

---

## Risks and Mitigation

| Risk | Mitigation |
|------|------------|
| Removing phantom save calls accidentally drops user data on existing installs that have only the scalar keys but no `_kUserProfile` JSON | Add a one-time migration in `PreferencesService.init()`: if `_kUserProfile` is missing but `_kTotalXP` exists, reconstruct a `UserProfile` from scalars then save full JSON |
| Quest persistence keyed by date may produce unbounded keys | Store `{date: ISO, quests: [...]}` under a single key; on load, if date != today, regenerate |
| `refreshListenable` re-running redirect on every prefs change could cause redirect storms | Increment `revision` only on the four meaningful flag changes (onboarding complete, sign out, account switch, theme change is not relevant) |
| Collapsing all writes into `saveUserProfile` increases JSON size on every action | Acceptable — `UserProfile` JSON is ~1KB; SharedPreferences handles this trivially. If hot-path becomes an issue, debounce with `Timer` in `UserNotifier` |
| Removing `sqflite`/`path_provider` may break a planned offline feature | Confirmed unused via grep; safe to remove. Reintroduce in the future when offline mode lands |
| Moving AI calls to a backend proxy is out of scope for this plan | Plan only stubs the interface and disables the unsafe path. Backend implementation tracked as follow-up |

---

## Acceptance Criteria

- [ ] `flutter analyze` reports **0 issues**.
- [ ] `flutter test` passes (with new tests added in Step 5.2).
- [ ] Sign-out from Profile lands on Splash and shows onboarding flow on next launch.
- [ ] Streak shows "1 day" after first card read of the day; stays at 1 for repeated reads same day; jumps to 2 on next consecutive day.
- [ ] Daily quest "Read 5 AI cards today" shows `n/5` that increments per unique card read and resets at midnight.
- [ ] Re-scrolling the same card up/down yields XP exactly once per day.
- [ ] No Anthropic API key string is present in `flutter build apk --release` output (`strings build/app/outputs/.../*.so | grep sk-ant` returns nothing).
- [ ] Cold-start guest UUID is preserved across launches (verify via dev print or save_id persistence test).

---

## SESSION_ID (for /ccg:execute use)

- CODEX_SESSION: _(not used — codeagent-wrapper not installed in this environment)_
- GEMINI_SESSION: _(not used — codeagent-wrapper not installed in this environment)_
- ARCHITECT_AGENT_ID: `ac92e69d366b7a739` (independent cross-check confirmed all critical findings)
