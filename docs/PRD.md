# AIScroll — Product Requirements Document (PRD)

| Field | Value |
|---|---|
| **Product** | AIScroll |
| **Tagline** | Learn AI in Seconds, One Scroll at a Time |
| **Owner** | Product (TBD) |
| **Engineering** | Mobile (Flutter), Backend (Admin API), Firebase |
| **Document version** | 1.0 |
| **Status** | Reverse-engineered from current codebase (v1) |
| **Last updated** | 2026-04-26 |

---

## 1. Overview

AIScroll is a mobile micro-learning app that teaches Artificial Intelligence in short, swipeable cards and serves a daily AI news feed in an Inshorts-style vertical reader. It blends a learning-management system (curated tracks, cards, quizzes, spaced repetition) with a content-consumption surface (news feed) and a gamification layer (XP, streaks, levels, badges, daily quests). The product is offline-first on the client, with cloud sync for signed-in users via Firebase.

The app is built in Flutter, uses Riverpod for state management, GoRouter for navigation, Firebase (Auth, Firestore, App Check, Cloud Messaging) for identity/sync/security/push, AdMob for monetization, and an admin-controlled HTTP API for content and telemetry.

## 2. Vision

> Make AI literacy a daily habit. Replace doom-scrolling with one minute of high-signal AI learning, every day, for everyone — from curious beginners to working professionals.

## 3. Goals & Non-Goals

### 3.1 Goals (v1)
1. Deliver a high-retention daily learning loop: open app → read 5–15 cards → answer quizzes → maintain streak.
2. Provide a fast, low-data AI news feed with bookmarking and sharing.
3. Personalize content via persona, knowledge level, topic preferences, and daily goal.
4. Gamify learning (XP, levels, streaks, badges, daily quests) without being noisy.
5. Reinforce retention with a Spaced Repetition System (SM-2).
6. Support guest-first usage with a frictionless upgrade to a synced account.
7. Monetize free users via native and rewarded ads while protecting reading flow.
8. Operate offline-first with graceful sync when online.

### 3.2 Non-Goals (v1)
- In-app purchases / subscriptions UI.
- Social features (followers, comments, public leaderboards).
- User-generated content authoring inside the app.
- Web/desktop client.
- Multilingual content (English-only at launch).
- Live AI chat with an LLM inside the app.

## 4. Target Users & Personas

| Persona | Knowledge | Persona key | Daily goal |
|---|---|---|---|
| Curious Newcomer | Nothing → A little | `curious` | 5 |
| Student Learner | A little → Quite a bit | `student` | 10 |
| Working Professional | Quite a bit → A lot | `professional` | 10–15 |

These personas drive copy, default daily goal, content suggestions, and difficulty defaults but never gate access.

## 5. Success Metrics

| Theme | Metric | Target (v1, 90-day post-launch) |
|---|---|---|
| Activation | Onboarding completion rate | ≥ 70 % |
| Engagement | DAU / MAU | ≥ 25 % |
| Habit | 7-day streak share of WAU | ≥ 20 % |
| Learning | Cards read per active session | ≥ 6 |
| Retention | D7 retention | ≥ 30 % |
| Quizzes | Quiz pass rate (inline) | ≥ 60 % |
| Ads | Native ad impressions per session (free user) | 1.5–3 |
| Sync reliability | Profile sync success rate | ≥ 99 % |
| Crash-free users | Stability | ≥ 99.5 % |

Telemetry is captured via the in-app `TelemetryService`, batched, and flushed to the admin `/api/events/ingest`.

## 6. Functional Requirements

### 6.1 Onboarding & Authentication
- Splash screen routes to either `/news` (onboarded) or `/onboarding/welcome` (new).
- Welcome offers: *Create account*, *Login*, *Continue with Google*, *Continue without account* (guest).
- Email/password registration: name (≥ 2), valid email, password ≥ 6, confirm match.
- Google Sign-In with native sheet; cancellation is silent.
- Onboarding flow: persona → knowledge level → topics (≥ 3) → daily goal.
- `completeOnboarding` persists to `UserProfile` and flips `isOnboardingComplete`.
- Guest → signed-in **merge**: cloud identity wins, scalar progress is the **max**, collections are the **union**, daily counters come from local.
- Sign-out keeps local progress; hard reset clears everything and re-routes to splash.

### 6.2 News Feed
- Vertical `PageView` of `NewsArticle`s; pinned articles first.
- `_CategoryRail` filter; pull-to-refresh; periodic auto-refresh every 2 minutes while foregrounded.
- Per-article actions: bookmark (`bookmarkedNewsIds`), share, open source URL, read full body in `/news/:id`.
- Read state persists in `readNewsIds` after dwell.
- Native ad slot every `AdConfig.adEvery` items after `adWarmup` warm-up.
- FCM news pushes deep-link to `/news/:id`.

### 6.3 Learn — Tracks
- `tracks_screen.dart` shows a grid of `LearningTrack`s with name, emoji, description, level chip, and per-user progress.
- Search field filters by name/description.
- Difficulty filter chips: All / Beginner / Intermediate / Advanced.
- Tracks come from the admin manifest (current samples in `cards/*.json`: AI Agents Deep Dive, Generative AI & LLMs, ML Foundations, Deep Learning Foundations, Classical ML Algorithms, NLP & Transformers, Feature Engineering, Python for Data — NumPy & Pandas, basic_python, advance_python).
- Free vs Premium track flag exists (`isPremium`); v1 ships with no gating.

### 6.4 Learn — Card Feed (`TrackLearnScreen`)
- Vertical `PageView` interleaving:
  - `LearningCard` rendered as `ZineCard` (emoji, title, explanation, takeaway, difficulty, topic chip, bookmark icon).
  - `QuizQuestion` rendered as `InlineQuizCard` every `_quizCadence` cards, when a quiz exists for the parent card.
  - Native ad slot via `_LearnAdSlot` per `AdConfig`.
- Card detail screen offers Share / Mark as learned / Like (extended actions).
- Dwell-based reading: card is marked read after `_dwellThreshold` ms.
- XP rewards (see §6.7).
- Track end shows `_TrackCompletionPage` with CTA to start the boss quiz.
- `lastCardByTrack[trackId]` enables resume.

### 6.5 Quizzes
- Inline quizzes (mid-track): single-correct multiple choice with explanation; correct = `xpReward` XP + `quizzesPassed++` + SRS update.
- Boss quiz (end-of-track): pulled from `bossQuizPoolProvider`. Pass threshold: 70 %. On pass, `awardBossQuizCompletion` grants `XPConstants.trackComplete` once per track. Each answer updates SRS for the parent card.

### 6.6 Spaced Repetition (SRS)
- Per-card `CardReview` (`reps`, `ease`, `intervalDays`, `nextReview`, `lastReview`) following SM-2.
- `quality` 0–5 derived from quiz correctness/confidence; quality < 3 resets `reps` and forces a 1-day interval.
- `dailyReviewCap` (default editable in settings); rolls over at local-day boundary.
- `srsProvider.dueCardIds()` and `dueCount()` expose review queue.

### 6.7 Gamification
- **XP rewards** (`XPConstants`):
  - `readCard`, `learnedSwipe`, `quizPass`, `dailyQuest`, `dailyStreakBase`, `firstCardBonus`, `trackComplete`.
- **Levels**: derived from `levelThresholds`; titles/emojis from `levelTitles`/`levelEmojis`.
- **Streaks**: increment when daily goal met; freezes consume on missed days; weekly auto-grant + rewarded-ad grant.
- **Badges** (`BadgeDefinitions`): rarities Common / Rare / Epic / Legendary; awarded on milestones; ephemeral celebration via `gamificationProvider`.
- **Daily Quests** (`QuestTemplates.defaultDailyQuests`): regenerated daily; types `readCards`, `passQuiz`, `learnNew`, `shareCard`; completion grants `xpReward`.

### 6.8 Saved (Bookmarks)
- Two tabs: Cards (grouped by track) and News.
- Search field per tab.
- Swipe-to-dismiss + tap-to-toggle unbookmark.

### 6.9 Profile & Settings
- Header: avatar, name, email or "Guest", level title with emoji.
- XP progress card.
- Stats grid: streak, total cards read, quizzes passed, reviews today.
- Streak calendar (last 7 days).
- Badges section (earned + locked) with link to all badges.
- Settings groups:
  - Preferences: edit profile, appearance.
  - Notifications: daily reminder toggle, time picker, daily review cap.
  - Feedback: haptics, sound.
  - Danger zone: sign out (keep progress), erase all data.
- Streak Freeze tile: rewarded-ad grant via `AdsService`.

### 6.10 Notifications
- Daily reminder via `flutter_local_notifications` + `timezone`; reschedules on settings change.
- News push via FCM; foreground banners on `news` channel; deep link to `/news/:id`.
- Background message handler registered in `main.dart`.

### 6.11 Ads (AdMob)
- `AdConfig` defines test/prod unit IDs for native and rewarded.
- Native ads in News and Learn feeds with `adEvery` and `adWarmup` controls.
- Rewarded ads tied to streak freeze grants.
- Future: hide all ads when `isPremium == true`.

### 6.12 Telemetry
- `TelemetryService` logs events with `guestId`, optional `userId`, `sessionId`, timestamp, props.
- Flush every 30 s or batch ≥ 20.
- Persists pending queue across cold starts; force-flush on app background.
- No-op when `ADMIN_API_URL` is unset.

## 7. Information Architecture & Navigation

```
Splash
  └─> /onboarding/welcome
        ├─> /onboarding/login
        ├─> /onboarding/register
        ├─> /onboarding/persona
        │     └─> /onboarding/level
        │           └─> /onboarding/topics
        │                 └─> /onboarding/goal
        │                       └─> Main Shell
        └─> Main Shell (already onboarded)

Main Shell (StatefulShellRoute, bottom nav)
  ├─ /news
  │    └─ /news/:id
  ├─ /learn (tracks grid)
  │    └─ /learn/track/:trackId
  │         ├─ /learn/track/:trackId/card/:cardId
  │         └─ /learn/track/:trackId/quiz (boss quiz)
  ├─ /saved (Cards | News)
  └─ /profile
       └─ /profile/edit  (full screen)
```

## 8. Data Model (high level)

### 8.1 `UserProfile` (server-of-truth in Firestore for signed-in users; mirrored locally)
- Identity: `id`, `name`, `email`, `firebaseUid`, `photoUrl`, `isGuest`, `isPremium`.
- Onboarding: `persona`, `knowledgeLevel`, `selectedTopics`, `dailyGoal`.
- Gamification: `totalXP`, `currentStreak`, `longestStreak`, `cardsReadToday`, `totalCardsRead`, `quizzesPassed`, `earnedBadgeIds`, `freezesAvailable`, `freezesUsedTotal`, `lastFreezeGrantedAt`.
- Content state: `bookmarkedCardIds`, `learnedCardIds`, `readCardIdsToday`, `bookmarkedNewsIds`, `readNewsIds`, `trackProgress`, `lastCardByTrack`.
- SRS: `cardReviews`, `reviewsDoneToday`, `dailyReviewCap`.
- Settings: `hapticsEnabled`, `soundEnabled`, `notificationsEnabled`, `reminderMinutesSinceMidnight`, `lastActiveDate`.

### 8.2 Content
- `LearningTrack`: `id`, `emoji`, `name`, `description`, `cardIds`, `level`, `isPremium`, `totalCards`.
- `LearningCard`: `id`, `trackId`, `topicTag`, `title`, `explanation`, `emoji`, `takeaway`, `difficulty`, `type` (concept/story/analogy/quiz), `xpReward`, `expandedContent`, `relatedCardIds`.
- `QuizQuestion`: `id`, `parentCardId`, `quizType`, `question`, `options`, `correctIndex`, `explanation`, `xpReward`.
- `NewsArticle`: `id`, `headline`, `summary`, `body`, `coverImageUrl`, `sourceName`, `sourceUrl`, `publishedAt`, `categoryKey`, `tags`, `isPinned`.
- `NewsCategory`: `key`, `label`, `emoji`, `sortOrder`.

### 8.3 Learning loop
- `DailyQuest`: `id`, `title`, `description`, `type`, `targetCount`, `currentCount`, `xpReward`, `isCompleted`.
- `CardReview` (SRS / SM-2): `cardId`, `reps`, `ease`, `intervalDays`, `nextReview`, `lastReview`.

### 8.4 Topic taxonomy
- `TopicKeys` defines canonical keys (`aiBasics`, `machineLearning`, `chatgptLlms`, `computerVision`, `generativeAi`, `aiEthics`, `dataScience`, `aiBusiness`, `promptEngineering`, `futureAi`).
- `_tagAliases` normalizes free-form content tags to canonical topic keys.

## 9. Technical Architecture

### 9.1 Mobile (Flutter)
- **State management:** `flutter_riverpod` `StateNotifierProvider`s per feature: `userProvider`, `contentProvider`, `newsProvider`, `gamificationProvider`, `questsProvider`, `feedProvider`, `srsProvider`, `onboardingProvider`, `authProvider`.
- **Navigation:** `go_router` with `StatefulShellRoute.indexedStack` for the bottom-nav shell.
- **Persistence:** `shared_preferences` (`PreferencesService`) for offline-first cache (profile, content manifest, news, quests, telemetry queue, JWT, guest id).
- **Networking:** `dio` with shared auth interceptor; admin base URL via `--dart-define=ADMIN_API_URL=...`.
- **Theming:** `AppTheme` + `AppColors` + `AppSpacing`.

### 9.2 Identity & Security
- `firebase_core` + `firebase_app_check` (Play Integrity / App Attest, debug provider in debug builds).
- `firebase_auth` + `google_sign_in` for user identity.
- `AuthService.getValidToken()` exchanges an App Check token for an AIScroll JWT (`/api/client/token`); JWT cached in prefs and refreshed before expiry / on 401.
- Firestore mirror of `UserProfile` at `users/{uid}` with `set(merge: true)` writes.

### 9.3 Content Pipeline
- `ContentService` hydrates from cached admin manifest, then refreshes via `/api/content/*` every 30 minutes (foregrounded) and on resume after 1 minute staleness.
- `NewsService` uses `/api/news` similarly with a 2-minute foreground cadence.
- `PeriodicSyncScheduler` is the shared lifecycle-aware refresher.

### 9.4 Notifications
- `flutter_local_notifications` + `timezone` for scheduled local reminders (channel `daily_reminder`).
- `firebase_messaging` for push (channel `news`).
- Deep linking via the router's `deep_link` helper.

### 9.5 Ads
- `google_mobile_ads` initialized in `main.dart`.
- `AdConfig` controls test/prod unit IDs and ad cadence (`adEvery`, `adWarmup`).
- `AdsService.preloadRewarded` / `showRewarded` for streak-freeze rewards.

### 9.6 Telemetry
- `TelemetryService` (Dio) batches events to `/api/events/ingest`; persists pending events to prefs; flushes on background and timer.
- Logs include `userId` (when signed in), `guestId`, `sessionId`, `name`, `ts`, `props`.

### 9.7 Lifecycle
- `app.dart` watches `WidgetsBindingObserver`:
  - On `paused` / `detached`: flush telemetry, stop content/news schedulers.
  - On `resumed`: start schedulers, kick a refresh.

## 10. Non-Functional Requirements

| Area | Requirement |
|---|---|
| Performance | Cold start to first interactive frame < 2 s on mid-tier Android. |
| Offline | All cached content readable with no network; writes queued. |
| Reliability | Crash-free sessions ≥ 99.5 %. |
| Privacy | No PII beyond email/displayName; guest mode collects only `guestId`. |
| Security | All API calls attested with App Check + signed JWT. |
| Accessibility | Min font scaling 0.85–1.4×, semantic labels on icons, color contrast WCAG AA. |
| Localization | English-only at v1; all user-facing strings centralized for future i18n. |
| Telemetry hygiene | No event includes free-text user content. |
| Battery | Background work limited to schedulers paused on `paused`. |

## 11. Dependencies (from `pubspec.yaml`)

- `flutter_riverpod`, `go_router`
- `shared_preferences`, `dio`, `intl`, `uuid`, `cached_network_image`
- `share_plus`, `url_launcher`, `google_fonts`, `flutter_animate`
- `firebase_core`, `firebase_app_check`, `firebase_auth`, `firebase_messaging`, `cloud_firestore`, `google_sign_in`
- `google_mobile_ads`
- `flutter_local_notifications`, `timezone`

## 12. Configuration Surface

- `--dart-define=ADMIN_API_URL=...`: Backend base URL. When unset the app remains usable from cache.
- AdMob unit IDs: test in debug, prod in release via `AdConfig`.
- Firebase config: `google-services.json` (Android) / `GoogleService-Info.plist` (iOS).

## 13. Risks & Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Backend downtime | Stale or empty content | Offline-first cache; periodic non-blocking refresh; UI never throws on errors. |
| Ad fatigue | Lower engagement | `adWarmup` + `adEvery` controls; never adjacent to quizzes. |
| Streak burnout | Churn | Streak freezes (auto + rewarded); editable daily goal. |
| Account merge conflicts | Lost progress | Deterministic merge (max for scalars, union for sets); cloud writes are `merge: true`. |
| Auth abuse | Fake clients | Firebase App Check + signed AIScroll JWT, refreshed on 401. |
| Telemetry loss | Bad analytics | Local persistence of pending events + lifecycle force-flush. |
| Quiz cheesing | Fake mastery | Dwell-based read XP; SRS quality from quiz outcomes. |

## 14. Acceptance & Verification

- Onboarding (cold install) routes through Welcome → Persona → Level → Topics → Goal → News.
- Reading 5 cards (default goal) increments streak after the day boundary; missing a day consumes a freeze if available.
- Inline quiz pass updates `quizzesPassed`, awards XP, updates SRS.
- Boss quiz pass at ≥ 70 % grants `trackComplete` XP exactly once.
- Sign-out keeps local progress; hard reset clears everything.
- Guest → Google Sign-In merges progress (validated by both local and cloud).
- News pull-to-refresh updates `lastSyncedAt` and surfaces new items.
- Daily reminder fires at the configured local time.
- Native ads appear at the configured cadence; rewarded ad grants exactly one freeze on success.

## 15. Future Roadmap (post-v1)

- Premium subscription (ad-free + premium tracks gated by `isPremium`).
- Personalized recommendations (next-card suggestions).
- Leaderboards and streak-friend features.
- Multilingual content.
- Web companion.
- In-app AI assistant tutor on selected cards.
- Content creator portal (UGC).
