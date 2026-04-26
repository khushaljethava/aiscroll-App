# AIScroll — User Stories

**Product:** AIScroll  
**Tagline:** *Learn AI in Seconds, One Scroll at a Time*  
**Platform:** Flutter (Android first, iOS-ready)  
**Document version:** 1.0  
**Last updated:** 2026-04-26

---

## 1. Personas

| Persona | Description | Primary motivation |
|---|---|---|
| **Curious Newcomer** | Has heard about AI but doesn't know where to start. Selects "Just Curious" persona, "Nothing"–"A little" knowledge level. | Understand AI without jargon, in tiny daily doses. |
| **Student Learner** | College/school student, intermediate knowledge, wants structured learning. Selects "Student" persona. | Build a strong AI foundation, track progress, prepare for projects/interviews. |
| **Working Professional** | Engineer, PM, designer, or analyst who needs to stay current. Selects "Professional" persona. | Stay updated on AI news + level up skills in short reading sessions. |
| **Returning Power User** | Has streak, badges, and bookmarks; logs in across devices. | Maintain streak, unlock badges, finish tracks, sync progress. |
| **Guest User** | Wants zero-friction trial; defers sign-up. | Try the product before committing; keep progress if/when signing up later. |

---

## 2. Story Map (Epics)

1. Onboarding & Authentication
2. News Feed (Inshorts-style)
3. Learning Tracks & Card Feed
4. Quizzes (Inline + Boss Quiz)
5. Spaced Repetition System (SRS)
6. Gamification (XP, Levels, Streaks, Badges, Quests)
7. Saved (Bookmarks)
8. Profile, Settings & Account
9. Notifications
10. Monetization (Ads & Rewards)
11. Offline-First & Cloud Sync
12. Search, Filters & Discovery

---

## 3. Epic 1 — Onboarding & Authentication

### US-1.1 — Splash routing
**As a** returning user,  
**I want** the app to remember whether I've onboarded,  
**so that** I land directly on the news feed without repeating setup.

**Acceptance criteria**
- App shows a branded splash with logo and animation on cold start.
- If `isOnboardingComplete` is true, the app routes to `/news`.
- If false, it routes to `/onboarding/welcome`.
- Splash duration is short (≈ 1.5 s) and never blocks longer than 3 s.

### US-1.2 — Welcome / sign-up choice
**As a** new user,  
**I want** clear authentication options on the welcome screen,  
**so that** I can choose how (or whether) to create an account.

**Acceptance criteria**
- Options: *Create account*, *I already have an account*, *Continue with Google*, *Continue without an account*.
- Guest mode is always available; it never blocks the main flow.
- Google Sign-In opens the native sheet; if cancelled, no error is shown.
- After successful sign-in, onboarding fields complete on the cloud profile bypass the persona/level/topic/goal screens.

### US-1.3 — Email/password registration & login
**As a** user who prefers email-based auth,  
**I want** to register or log in using email and password,  
**so that** I can sync my progress without using Google.

**Acceptance criteria**
- Name (≥ 2 chars), valid email regex, password ≥ 6 chars, confirm-password match.
- Errors map to FirebaseAuth messages and surface as readable snackbars.
- On success the user becomes `isGuest = false`, `firebaseUid` set, profile is upserted to Firestore.

### US-1.4 — Persona selection
**As a** new user,  
**I want** to pick "Student", "Professional", or "Just Curious",  
**so that** content tone is tailored to me.

**Acceptance criteria**
- Persona is stored in `UserProfile.persona`.
- A default of *Just Curious* is acceptable if skipped.
- Selection persists across app restarts.

### US-1.5 — Knowledge-level slider
**As a** new user,  
**I want** to indicate how much AI I already know on a 4-step slider (Nothing → A Lot),  
**so that** difficulty starts at the right level.

**Acceptance criteria**
- Stored in `UserProfile.knowledgeLevel`.
- Affects default track filtering on first launch (UI hint only — content remains accessible).

### US-1.6 — Topic preferences
**As a** new user,  
**I want** to pick at least 3 topics of interest,  
**so that** my feeds prioritize what I care about.

**Acceptance criteria**
- Topic list comes from `TopicKeys` (AI Basics, ML, ChatGPT & LLMs, CV, GenAI, Ethics, Data Science, AI in Business, Prompt Engineering, Future of AI).
- "Continue" is disabled until ≥ 3 topics are selected.
- Stored in `UserProfile.selectedTopics`.

### US-1.7 — Daily goal
**As a** new user,  
**I want** to set my daily goal (5 / 10 / 15 cards),  
**so that** the app can track my streak and progress.

**Acceptance criteria**
- Stored in `UserProfile.dailyGoal`.
- Drives streak logic and the *daily goal* card on the profile.
- `completeOnboarding` flips `isOnboardingComplete` to true and routes to `/news`.

### US-1.8 — Guest → signed-in upgrade (merge)
**As a** guest who later signs in,  
**I want** my local progress to merge into my cloud account,  
**so that** I don't lose XP, streak, bookmarks, or SRS state.

**Acceptance criteria**
- On Google or email sign-in, `pullFromCloudAndMerge` runs.
- Cloud identity (uid, email, name, photo) wins; scalar progress takes the **max**; collections (bookmarks, learnedCardIds, badges) take the **union**; daily-rollover counters always come from local.
- Merge result is written back to Firestore via `set(merge: true)`.

### US-1.9 — Sign-out without losing data
**As a** signed-in user,  
**I want** to sign out while keeping my local progress,  
**so that** I can use the app as a guest temporarily.

**Acceptance criteria**
- `signOutKeepProgress` clears `firebaseUid` but preserves XP, streaks, bookmarks, etc.
- App returns to guest mode and continues on `/news`.

### US-1.10 — Hard reset
**As a** user wanting a clean slate,  
**I want** a "reset everything" option in the danger zone,  
**so that** I can wipe local data and re-onboard.

**Acceptance criteria**
- Clears all user prefs, cached content, telemetry queue.
- Routes back to splash → onboarding/welcome.

---

## 4. Epic 2 — News Feed

### US-2.1 — Vertical news feed
**As a** user,  
**I want** an Inshorts-style vertical, swipeable feed of AI news,  
**so that** I can catch up in seconds.

**Acceptance criteria**
- Vertical `PageView` with one `NewsArticle` per page (`headline`, `summary`, `coverImageUrl`, `sourceName`, `publishedAt`, `categoryKey`).
- Pinned articles render first.
- Swiping marks the article as read after a short dwell.

### US-2.2 — Category rail filter
**As a** user,  
**I want** to filter the feed by category,  
**so that** I can focus on what's relevant.

**Acceptance criteria**
- Horizontal category chips include "All" and admin-defined categories.
- Selecting a category narrows `visibleArticles`.
- Empty filter shows an "no articles" empty state.

### US-2.3 — Bookmark, share, open source
**As a** reader,  
**I want** to bookmark, share, and open the source URL of an article,  
**so that** I can revisit, share, or read the full piece.

**Acceptance criteria**
- Bookmark toggles `bookmarkedNewsIds`; haptic feedback fires.
- Share uses `share_plus` with headline + URL.
- Open Source launches `sourceUrl` in an in-app/external browser.

### US-2.4 — Read full article
**As a** reader,  
**I want** to tap into a detail screen for the full body,  
**so that** I can read more than the summary.

**Acceptance criteria**
- Detail route `/news/:id` renders `NewsArticle.body`.
- Read state persists via `readNewsIds`.

### US-2.5 — Pull-to-refresh
**As a** user,  
**I want** to pull to refresh the news feed,  
**so that** I can fetch the latest articles on demand.

**Acceptance criteria**
- Pull triggers `NewsNotifier.refresh()`.
- Loading indicator surfaces; errors do not clear cached items.
- Background `PeriodicSyncScheduler` also refreshes every 2 minutes while foregrounded.

### US-2.6 — Native ads in news
**As a** product owner,  
**I want** to interleave native ads in the feed,  
**so that** I can monetize free users without breaking the read flow.

**Acceptance criteria**
- After `AdConfig.adWarmup` items, a native ad appears every `AdConfig.adEvery` items.
- Ads visually match the card style.
- Ads respect platform policy (test IDs in debug, prod IDs in release).

### US-2.7 — News push notifications
**As a** user,  
**I want** to receive push notifications when major AI news drops,  
**so that** I don't miss important updates.

**Acceptance criteria**
- FCM token is registered on launch.
- Foreground messages render via the local notifications "news" channel.
- Tapping deep-links to `/news/:id`.

---

## 5. Epic 3 — Learning Tracks & Card Feed

### US-3.1 — Tracks grid
**As a** learner,  
**I want** a grid of curated tracks (e.g. AI Agents Deep Dive, Generative AI & LLMs, ML Foundations),  
**so that** I can pick what to study next.

**Acceptance criteria**
- Each card shows `emoji`, `name`, `description`, `level`, and a progress bar of `learnedCardIds / totalCards`.
- Search field filters by name/description.
- Difficulty filter chips: All / Beginner / Intermediate / Advanced.

### US-3.2 — Card-by-card learning experience
**As a** learner,  
**I want** an immersive vertical card feed for each track,  
**so that** I can read short, focused pieces of content.

**Acceptance criteria**
- `TrackLearnScreen` renders each `LearningCard` as a `ZineCard` (emoji, title, explanation, takeaway, difficulty badge, topic chip).
- Body content scrolls internally inside fixed card chrome.
- Tap-to-open opens a detail reader with extra actions (Share / Learned / Like).

### US-3.3 — Inline quizzes
**As a** learner,  
**I want** quizzes inserted between cards,  
**so that** I can check understanding without leaving the flow.

**Acceptance criteria**
- Every `_quizCadence` cards an `InlineQuizCard` is shown if a `QuizQuestion` is available for that parent card.
- Correct answer awards `xpReward`, increments `quizzesPassed`, fires `recordEvent(passQuiz)`, and updates SRS.
- Wrong answer reveals explanation and still updates SRS with low quality.

### US-3.4 — Boss quiz (track completion)
**As a** learner,  
**I want** an end-of-track boss quiz,  
**so that** I can certify mastery of the track.

**Acceptance criteria**
- Available from the `_TrackCompletionPage` after the last card.
- Pulls from `bossQuizPoolProvider`.
- Pass threshold is 70 %.
- On pass, `awardBossQuizCompletion` grants `XPConstants.trackComplete` exactly once per track.
- Each answer also updates SRS for the parent card.

### US-3.5 — Dwell-based XP
**As a** learner,  
**I want** the app to award XP only after I actually spend time on a card,  
**so that** I can't game the system by swiping mindlessly.

**Acceptance criteria**
- A card is marked read after dwelling ≥ `_dwellThreshold` ms (`feedProvider`).
- `markCardRead` is idempotent: re-reads of the same card today don't re-award XP.
- Reading the card grants `XPConstants.readCard`; first card of the day grants `firstCardBonus`.

### US-3.6 — "Mark as learned" + bookmarking
**As a** learner,  
**I want** to mark a card as learned or bookmark it,  
**so that** I can manage my study list.

**Acceptance criteria**
- "Learned" appends to `learnedCardIds`, awards `learnedSwipe` XP, and contributes to track completion.
- Bookmark toggles `bookmarkedCardIds` and surfaces in Saved.

### US-3.7 — Resume position
**As a** learner,  
**I want** to resume a track at the last card I was on,  
**so that** I don't waste time finding my place.

**Acceptance criteria**
- `lastCardByTrack[trackId]` records the last card index per track.
- Re-entering a track scrolls/animates to that position.

### US-3.8 — Native ads in learning feed
**As a** product owner,  
**I want** sparse native ads in the learning feed for free users,  
**so that** monetization happens without disrupting study flow.

**Acceptance criteria**
- `_LearnAdSlot` is interleaved using `AdConfig.adEvery` and `adWarmup`.
- Ads never appear immediately before a quiz card.

---

## 6. Epic 4 — Spaced Repetition System (SRS)

### US-4.1 — Schedule reviews via SM-2
**As a** learner,  
**I want** the app to schedule cards for review using SM-2,  
**so that** I retain what I learned long-term.

**Acceptance criteria**
- Each card has a `CardReview` with `reps`, `ease`, `intervalDays`, `nextReview`.
- Quality 0–5 (mapped from quiz correctness and confidence) updates the SRS.
- Quality < 3 resets `reps` to 0 with a 1-day interval.

### US-4.2 — Daily review cap
**As a** learner,  
**I want** a daily cap on reviews,  
**so that** the app doesn't burn me out.

**Acceptance criteria**
- `dailyReviewCap` defaults to a sensible value and is editable in settings.
- `reviewsDoneToday` rolls over at the local-day boundary.
- Once the cap is hit, additional reviews are queued for the next day.

### US-4.3 — Due-cards count
**As a** learner,  
**I want** to see how many cards are due today,  
**so that** I can plan my session.

**Acceptance criteria**
- `srsProvider.dueCount()` exposes the number of `nextReview <= today` cards.
- Profile/Stats grid shows the count.

---

## 7. Epic 5 — Gamification

### US-5.1 — XP, levels, titles
**As a** learner,  
**I want** to earn XP and level up,  
**so that** I feel progress every day.

**Acceptance criteria**
- XP rewards from `XPConstants` for read/learned/quiz/quest/streak/track-complete.
- Level, title, and emoji derive from `XPConstants.getLevelFromXP/Title/Emoji`.
- Level-up triggers a celebratory animation via `gamificationProvider.triggerLevelUp`.

### US-5.2 — Daily streak
**As a** learner,  
**I want** a streak that increments each day I hit my goal,  
**so that** I stay motivated.

**Acceptance criteria**
- `currentStreak` increments after the user reads ≥ `dailyGoal` cards in a day.
- `longestStreak` is updated when surpassed.
- Missing a day resets streak unless a freeze is consumed.

### US-5.3 — Streak freezes
**As a** user with a busy day,  
**I want** to use a streak freeze to keep my streak alive,  
**so that** life events don't punish my consistency.

**Acceptance criteria**
- Weekly auto-grant of freezes (capped).
- Rewarded ad in profile grants additional freezes (`AdsService.showRewarded`).
- A missed day auto-consumes one freeze if available.

### US-5.4 — Daily quests
**As a** learner,  
**I want** 2–3 daily quests with rewards,  
**so that** I have variety beyond just reading.

**Acceptance criteria**
- Quests are regenerated daily from `QuestTemplates.defaultDailyQuests`.
- Types include `readCards`, `passQuiz`, `learnNew`, `shareCard`.
- Completion awards `xpReward` and triggers gamification toast.

### US-5.5 — Badges
**As a** learner,  
**I want** to earn badges for milestones,  
**so that** my long-term progress is visible.

**Acceptance criteria**
- `BadgeDefinitions` enumerates all badges with rarities.
- Earning a badge appends to `earnedBadgeIds` and triggers `gamificationProvider.triggerBadge`.
- Profile shows earned vs locked badges.

### US-5.6 — Streak calendar
**As a** learner,  
**I want** a weekly calendar of activity on my profile,  
**so that** I can see at a glance how I've been doing.

**Acceptance criteria**
- `_StreakCalendar` shows the last 7 days with per-day status (active / freeze / missed).

---

## 8. Epic 6 — Saved (Bookmarks)

### US-6.1 — Saved Cards & News tabs
**As a** user,  
**I want** a Saved screen with two tabs (Cards, News),  
**so that** I can revisit content easily.

**Acceptance criteria**
- Cards tab groups bookmarks by track.
- News tab lists bookmarked articles in reverse-chronological order.
- Each tab has a search field.

### US-6.2 — Unbookmark
**As a** user,  
**I want** to unbookmark items by swipe or button,  
**so that** I can prune my list.

**Acceptance criteria**
- Swipe-to-dismiss and tap-to-toggle both unbookmark.
- Removal is immediate; haptic feedback fires.

---

## 9. Epic 7 — Profile, Settings & Account

### US-7.1 — Profile header & stats
**As a** user,  
**I want** to see my avatar, name, email, level, XP, and key stats,  
**so that** I can track my standing.

**Acceptance criteria**
- Header shows avatar, name, email (or "Guest"), level title with emoji.
- XP progress card shows current XP and progress to next level.
- Stats grid: streak, cards read total, quizzes passed, reviews done today.

### US-7.2 — Edit profile
**As a** signed-in user,  
**I want** to edit my display name and avatar,  
**so that** my profile reflects me.

**Acceptance criteria**
- `/profile/edit` saves to `UserProfile` and Firestore.

### US-7.3 — Appearance & feedback settings
**As a** user,  
**I want** to toggle haptics and sound effects,  
**so that** the app feels right for me.

**Acceptance criteria**
- `hapticsEnabled` / `soundEnabled` toggles persist locally.
- All feedback service calls respect these flags.

### US-7.4 — Notification settings
**As a** user,  
**I want** to enable/disable daily reminders and pick a time,  
**so that** I'm nudged exactly when it suits me.

**Acceptance criteria**
- `notificationsEnabled` toggles permission flow on first enable.
- `reminderMinutesSinceMidnight` controls schedule via `flutter_local_notifications` + `timezone`.
- `dailyReviewCap` selectable via stepper or chips.

### US-7.5 — Sign out / hard reset
**As a** user,  
**I want** clear danger-zone actions,  
**so that** I can leave or reset deliberately.

**Acceptance criteria**
- "Sign out (keep progress)" preserves local data; "Erase all data" wipes everything.
- Confirmation dialog precedes both.

---

## 10. Epic 8 — Notifications

### US-8.1 — Daily reminder
**As a** learner,  
**I want** a daily reminder at my chosen time,  
**so that** I don't break my streak.

**Acceptance criteria**
- Scheduled via `NotificationService` with channel `daily_reminder`.
- Re-schedules on settings change and app boot.

### US-8.2 — Push deep links
**As a** user,  
**I want** taps on news pushes to open the article,  
**so that** I can read it immediately.

**Acceptance criteria**
- FCM payload contains article id; tap routes to `/news/:id`.
- Background handler hydrates the route on cold start.

---

## 11. Epic 9 — Monetization & Ads

### US-9.1 — Native ads
**As a** product owner,  
**I want** native ads in News and Learn,  
**so that** AIScroll is sustainable for free users.

**Acceptance criteria**
- AdMob native units; test IDs in debug.
- Frequency capped per `AdConfig.adEvery`.

### US-9.2 — Rewarded ads
**As a** user,  
**I want** to watch a rewarded ad to gain a streak freeze,  
**so that** I can recover from missed days without paying.

**Acceptance criteria**
- `AdsService.preloadRewarded` warms the ad.
- `showRewarded` only awards on actual `OnUserEarnedReward` callback.

### US-9.3 — Premium flag
**As a** future paying user,  
**I want** premium status to remove ads and unlock perks,  
**so that** I can upgrade my experience.

**Acceptance criteria**
- `isPremium` is part of `UserProfile`; UI hides ads when true.
- (Purchase flow is out of scope for v1.)

---

## 12. Epic 10 — Offline-First & Cloud Sync

### US-10.1 — Offline reading
**As a** user on a flaky network,  
**I want** the app to render the latest cached news/cards instantly,  
**so that** I can keep learning offline.

**Acceptance criteria**
- `hydrateFromCache` runs at boot for content and news.
- Pull-to-refresh is the only network requirement after boot.

### US-10.2 — Cloud sync of profile
**As a** signed-in user on multiple devices,  
**I want** my profile (XP, streak, bookmarks, SRS) to sync,  
**so that** I have a single source of truth.

**Acceptance criteria**
- `FirestoreService` upserts `users/{uid}` with `merge: true`, debounced.
- Failures are logged but never thrown to UI.
- On launch / sign-in, cloud copy is fetched and merged.

### US-10.3 — Backend availability fallback
**As a** user,  
**I want** the app to behave gracefully when the admin backend is unset,  
**so that** preview builds still work.

**Acceptance criteria**
- When `ADMIN_API_URL` is empty, services no-op; cached data renders normally.
- No crashes, no error spam.

---

## 13. Epic 11 — Search, Filters & Discovery

### US-11.1 — Track search
**As a** learner,  
**I want** to search tracks by name/description,  
**so that** I can find what I want quickly.

### US-11.2 — Difficulty filter
**As a** learner,  
**I want** to filter by Beginner / Intermediate / Advanced,  
**so that** I can match my level.

### US-11.3 — Saved search
**As a** user,  
**I want** to search my bookmarks,  
**so that** I can find a saved card or article.

---

## 14. Epic 12 — Telemetry & Reliability

### US-12.1 — Event tracking
**As a** product team,  
**we want** to capture key events (session_start, card_read, quiz_pass, news_open, etc.),  
**so that** we can analyze engagement.

**Acceptance criteria**
- `TelemetryService.log` enqueues events with `guestId`, optional `userId`, `sessionId`.
- Periodic flush every 30 s or batch of 20.
- Pending queue persisted to SharedPreferences across cold restarts.
- App-lifecycle background triggers a force-flush.

### US-12.2 — App Check enforcement
**As a** product owner,  
**I want** API requests to be attested,  
**so that** the backend rejects abuse.

**Acceptance criteria**
- Firebase App Check is initialized at boot (Play Integrity / App Attest).
- `AuthService.getValidToken` exchanges App Check token for an AIScroll JWT.
- 401 responses trigger token refresh.

---

## 15. Out-of-Scope (Non-Goals for v1)

- In-app purchases / subscription billing UI
- Social features (friends, leaderboards beyond personal stats)
- Authoring/UGC inside the mobile app
- Web/desktop client
- Multilingual content (English-only at launch)
