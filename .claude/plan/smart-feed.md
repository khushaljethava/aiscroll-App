# Implementation Plan: Smart Feed (SRS + Personalized Ranking)

> **Scope**: Replace the static seed-order feed with a personalized, spaced-repetition-driven queue. This is the "moat" feature — it converts AIScroll from a swipeable card deck into an actual learning system.
> **Combined because**: SRS decides *when* a card returns; the ranker decides *what* enters the queue. Designing them as one unit avoids two competing sources of truth for "what should the user see next."

---

## Task Type
- [x] Backend (state, scheduler, ranker — pure Dart logic)
- [x] Frontend (feed composition, small UI affordances)
- [ ] Fullstack (no remote backend in this slice — see follow-up #3 in the recommendations list)

---

## Architecture Decisions (cross-checked with architect)

### A. SRS storage lives inside `UserProfile`
- Embed `Map<String, CardReview>` as a new field on `UserProfile`. One atomic write path, no risk of profile/SRS drift after mid-write crash.
- **Rejected**: separate prefs key (illusory separation, doubles event surface), sqflite (right answer at 10k+ cards/user — we're nowhere near).
- **Mitigation**: debounce `saveUserProfile` writes (500 ms coalesce window) so a burst of swipes doesn't serialize N times.

### B. `FeedComposer` notifier owns the in-session ordering
- A `StateNotifier<FeedQueue>` builds the ordered list once at session start (or pull-to-refresh) and exposes it as immutable to `PageView.builder`.
- New due reviews surfaced mid-session **append** to the tail — never reorder, so `PageView.currentIndex` stays valid.
- "Just saw" exclusion is a session-scoped `Set<String>` inside the composer, separate from persisted `learnedCardIds`.
- **Rejected**: pure provider rebuild (breaks scroll position), session-frozen list (defeats half of SRS).

### C. Ranker is a pure function, not a notifier
- `int score(LearningCard, RankingContext)` — `RankingContext` bundles user prefs + SRS state.
- Easy to unit test; easy to A/B-test variants later by swapping in a different scoring function.

---

## SRS Algorithm (SM-2, lightly adapted)

Standard SM-2 with a quality scale mapped to AIScroll's interaction events:

| User action | Quality `q` | Outcome |
|---|---|---|
| Quiz answer correct (parent card) | 5 | Strongest signal — biggest interval bump |
| Right-swipe "Learned" | 4 | Solid recall |
| Card seen ≥15s, not learned, not due-review | 3 | "Familiar but not committed" |
| Card seen but skipped fast (< 5s dwell) | 2 | Weak signal — small interval impact |
| Quiz answer wrong | 1 | Reset interval |
| Quiz skipped (when shown) | 0 | Reset interval |

### Update formula
```
afterReview(review, q):
  if q < 3:
    reps = 0
    interval = 1
    ease = max(1.3, ease + (0.1 - (5-q) * (0.08 + (5-q)*0.02)))
  else:
    if reps == 0: interval = 1
    elif reps == 1: interval = 6
    else: interval = round(interval * ease)
    reps = reps + 1
    ease = max(1.3, ease + (0.1 - (5-q) * (0.08 + (5-q)*0.02)))
  nextReview = today + interval days
```

### Defaults for unseen cards
- `reps = 0`, `ease = 2.5`, `interval = 0`, `nextReview = epoch` (i.e. "due now").

### Daily review cap
- Configurable `dailyReviewCap` on `UserProfile` (default: 20). Prevents overwhelm on first launch when every card is "due."
- Composer takes `min(dueCards, dailyReviewCap)` reviews per session, fills the rest with new cards.
- `newCardsPerSession` default: `max(5, dailyGoal)`.

---

## Ranking Function

`score(card, ctx) -> int` — higher = more likely to appear sooner among non-due new cards.

```
score = 0

// Topic match (user said they care about this)
if card.topicKey in ctx.selectedTopicKeys: score += 30

// Difficulty match against knowledgeLevel
allowed = allowedDifficultiesFor(ctx.knowledgeLevel)
//   nothing      -> {beginner}
//   a_little     -> {beginner, intermediate}  (beginner +5)
//   quite_a_bit  -> {intermediate, advanced}  (intermediate +5)
//   a_lot        -> {beginner, intermediate, advanced} (advanced +5)
if card.difficulty not in allowed: return -1   // hard filter
score += difficultyMatchBonus(card.difficulty, ctx.knowledgeLevel)  // 0 or 5

// Cards related to ones the user already learned (strong cohesion signal)
relatedLearnedCount = count(card.relatedCardIds intersect ctx.learnedCardIds)
score += relatedLearnedCount * 4

// Mild penalty for cards the user has already learned that aren't due yet
if card.id in ctx.learnedCardIds and not ctx.dueIds.contains(card.id):
  return -1   // hard filter — don't surface

// Tie-breaker: track sequence (cards earlier in their track get a small boost)
score += (100 - cardIndexInTrack(card)).clamp(0, 100) / 20  // 0..5
```

---

## Feed Composition Algorithm

```
buildFeedQueue(allCards, allQuizzes, user, srs, sessionSeen):
  today = startOfDay(now)
  ctx = RankingContext.from(user, srs)

  // 1. Reviews due (oldest first, cap by dailyReviewCap)
  due = srs.dueCards(today)
        .where(c => not sessionSeen.contains(c.id))
        .sortBy(c => srs[c].nextReview)         // oldest overdue first
        .take(user.dailyReviewCap - srs.reviewsDoneToday(user))

  // 2. New cards by ranking score
  candidatePool = allCards
        .where(c => not user.learnedCardIds.contains(c.id))
        .where(c => not sessionSeen.contains(c.id))
        .map(c => (c, score(c, ctx)))
        .where((_, s) => s >= 0)
        .sortBy((_, s) => -s)                    // highest first
        .take(max(5, user.dailyGoal))

  // 3. Interleave: 1 review per 3 new (or all reviews first, configurable)
  ordered = interleave(due, candidatePool, ratio=(1, 3))

  // 4. Insert quiz cards every 4 learning cards as today
  return withQuizzesInterleaved(ordered, allQuizzes)
```

The composer can be re-invoked on pull-to-refresh; otherwise it appends new due cards (e.g. quiz fail bumps a card to re-due) at the tail.

---

## Implementation Steps

### Step 1 — `CardReview` model + UserProfile field

**New file**: `lib/data/models/srs_model.dart`
```dart
class CardReview {
  final String cardId;
  final int reps;
  final double ease;
  final int intervalDays;
  final DateTime nextReview;
  final DateTime? lastReview;

  // toMap / fromMap
  // copyWithReview(quality) -> CardReview   // pure SM-2 transform
  bool isDue(DateTime today) => !nextReview.isAfter(today);
}
```

**Modify** `lib/data/models/user_model.dart`:
- Add `Map<String, CardReview> cardReviews = const {}`
- Add `int reviewsDoneToday = 0` (resets on day rollover)
- Add `int dailyReviewCap = 20`
- Update `copyWith`, `toMap`, `fromMap` accordingly.

### Step 2 — `SRSNotifier` provider

**New file**: `lib/features/feed/providers/srs_provider.dart`
```dart
class SRSNotifier extends StateNotifier<Map<String, CardReview>> {
  SRSNotifier(this._ref) : super({});

  Future<void> recordReview(String cardId, int quality) async {
    final existing = state[cardId] ?? CardReview.fresh(cardId);
    final updated = existing.afterReview(quality);
    state = {...state, cardId: updated};
    // Push back into UserProfile (debounced via _DebouncedSaver below)
    await _ref.read(userProvider.notifier).updateReviews(state);
  }

  List<String> dueCardIds(DateTime today) =>
    state.entries.where((e) => e.value.isDue(today)).map((e) => e.key).toList();
}
```

`UserNotifier.updateReviews(Map)` is a thin setter that updates `state.cardReviews` and triggers the debounced save.

### Step 3 — Debounced profile save

**Modify** `lib/data/providers/user_provider.dart`:
- Add a `Timer? _saveTimer` field; replace `await _prefs.saveUserProfile(state)` calls inside frequent-write methods (`addXP`, `markCardRead`, `updateReviews`) with `_scheduleSave()`.
- `_scheduleSave()` cancels and re-arms a 500 ms `Timer` that performs the actual write.
- Critical writes (`reset`, `setOnboardingData`, `saveProfile`) bypass the timer and write immediately + flush.

### Step 4 — `FeedComposer` notifier

**New file**: `lib/features/feed/providers/feed_composer_provider.dart`
```dart
class FeedQueue {
  final List<dynamic> items;       // LearningCard | QuizQuestion
  final Set<String> sessionSeen;
}

class FeedComposer extends StateNotifier<FeedQueue> {
  FeedComposer(this._ref) : super(const FeedQueue.empty());

  Future<void> initSession() async { /* build via algorithm above */ }
  void markSeen(String cardId) { state = state.copyWith(sessionSeen: ...); }
  void appendDue(String cardId) { /* called when SRS resurfaces a failed card */ }
  Future<void> refresh() => initSession();
}
```

Replace all consumers of `feedCardsProvider` with `feedComposerProvider`.

### Step 5 — Topic key normalization

**Modify** `lib/data/models/card_model.dart`:
- Add `String get topicKey` — derived from `topicTag` (lowercase + spaces→underscores). Cards in the seed already have semi-normalized tags.
- Add a `kCanonicalTopicKeys` const set in `lib/core/constants/` matching the onboarding picker IDs (`ai_basics`, `machine_learning`, `chatgpt_llms`, `computer_vision`, `generative_ai`, `ai_ethics`, `data_science`, `ai_business`, `prompt_engineering`, `future_ai`).
- Optionally, add explicit `List<String> topicKeys` to `LearningCard` so a single card can match multiple onboarding topics (better recall for ranking). Backfill seed data.

### Step 6 — Ranker as pure function

**New file**: `lib/features/feed/providers/feed_ranker.dart`
```dart
class RankingContext { /* selectedTopicKeys, knowledgeLevel, learnedCardIds, dueIds */ }
int score(LearningCard card, RankingContext ctx) { /* per algorithm above */ }
List<LearningCard> rankNewCards(Iterable<LearningCard> pool, RankingContext ctx);
```

### Step 7 — Wire SRS events from feed

**Modify** `lib/features/feed/screens/feed_screen.dart`:
- `_awardReadXP(card)` → after `markCardRead`, also call `srsProvider.notifier.recordReview(card.id, 3)` (familiar).
- `_onLearnedSwipe(card)` → on the new-learn path, `recordReview(card.id, 4)`.
- Quiz handler `onAnswer(correct, parentCardId)` → `recordReview(parentCardId, correct ? 5 : 1)`.
- Quiz skip (`_skip` already calls `onAnswer(false)`) → `recordReview(parentCardId, 0)`.
- On page change, `feedComposer.markSeen(currentCard.id)`.

`QuizCardWidget.onAnswer` currently has signature `(bool correct)`. Extend to `(bool correct, String parentCardId)` (already in `QuizQuestion.parentCardId`).

### Step 8 — Surface "reviews due" affordance

**Modify** `lib/features/feed/screens/feed_screen.dart` `_HomeHeader`:
- Below `_StreakWidget`, add a tiny `_ReviewsDueChip` showing `N due today` (only when N > 0).
- Tap = pull-to-refresh on the feed (re-runs composer).

**Modify** `lib/features/profile/screens/profile_screen.dart` `_StatsRow`:
- Replace the `quizzesPassed` stat (or add a 4th) with `Reviews Due / Reviews Done Today`.

### Step 9 — Pull-to-refresh on the feed

**Modify** `lib/features/feed/screens/feed_screen.dart` `_buildFeed`:
- Wrap the `PageView.builder` in a `RefreshIndicator` (vertical PageView already supports it via `onRefresh`).
- `onRefresh` → `await ref.read(feedComposerProvider.notifier).refresh()`.

### Step 10 — Daily reset of `reviewsDoneToday`

**Modify** `lib/data/providers/user_provider.dart` `load()`:
- In the date-rollover branch already added in Phase 2.2, reset `reviewsDoneToday: 0` alongside the other daily counters.

### Step 11 — Migration / first-run behavior

In `UserNotifier.load()`:
- If `cardReviews` is empty AND `learnedCardIds` is non-empty (existing user upgrading), seed each learned card with a default `CardReview(reps: 1, ease: 2.5, intervalDays: 6, nextReview: today + 6d)`.
- This way existing learned cards don't all flood back as "due" on day 1 of the upgrade.

### Step 12 — Tests

**New tests**:
- `test/srs_algorithm_test.dart`:
  - SM-2 quality 5 from fresh: reps=1, interval=1, ease ≈ 2.6
  - SM-2 quality 5 second time: reps=2, interval=6
  - SM-2 quality 5 third time: reps=3, interval=15 (`6 * 2.5`)
  - SM-2 quality 1: reps=0, interval=1, ease decreases
  - Ease never drops below 1.3
- `test/feed_ranker_test.dart`:
  - Topic-matched card outranks non-matched
  - Out-of-difficulty card hard-filtered (score < 0)
  - Already-learned non-due card hard-filtered
  - Related-to-learned cards rank higher than unrelated
- `test/feed_composer_test.dart`:
  - Initial queue includes due reviews ahead of new cards
  - `markSeen` excludes from future composition without reordering current queue
  - `appendDue` adds to tail without rebuild
  - Daily review cap respected

### Step 13 — Verify

1. `flutter analyze --no-pub` → 0 issues.
2. `flutter test --no-pub` → all green (existing 9 + new ~12).
3. Manual smoke (debug build):
   - Cold start with no profile → all cards "new", topic-matched cards appear first.
   - Right-swipe 3 cards → restart → those 3 appear scheduled per SRS, not in main feed.
   - Fail a quiz → that quiz's parent card appears at end of session feed.
   - Toggle daily review cap → composer respects new cap.

---

## Key Files

| File | Operation | Description |
|------|-----------|-------------|
| `lib/data/models/srs_model.dart` | **Create** | `CardReview` + SM-2 transform + `isDue` |
| `lib/data/models/user_model.dart` | **Modify** | Add `cardReviews`, `reviewsDoneToday`, `dailyReviewCap` fields + serialization |
| `lib/data/models/card_model.dart` | **Modify** | Add `topicKey` getter and optional `topicKeys` list |
| `lib/core/constants/topic_constants.dart` | **Create** | Canonical topic keys matching onboarding picker |
| `lib/data/providers/user_provider.dart` | **Modify** | Add `updateReviews`, debounced `_scheduleSave`, reset `reviewsDoneToday` on rollover |
| `lib/features/feed/providers/srs_provider.dart` | **Create** | `SRSNotifier` — `recordReview`, `dueCardIds`, `dueCount` |
| `lib/features/feed/providers/feed_ranker.dart` | **Create** | Pure ranking function + `RankingContext` |
| `lib/features/feed/providers/feed_composer_provider.dart` | **Create** | `FeedComposer` notifier — session ordering, append-only |
| `lib/features/feed/providers/feed_provider.dart` | **Modify** | Deprecate `feedCardsProvider`; expose `feedComposerProvider` |
| `lib/features/feed/screens/feed_screen.dart` | **Modify** | Use composer, wire SRS events, add `RefreshIndicator`, add `_ReviewsDueChip` |
| `lib/features/feed/widgets/quiz_card_widget.dart` | **Modify** | Extend `onAnswer` to include `parentCardId`; emit on skip |
| `lib/features/profile/screens/profile_screen.dart` | **Modify** | Surface reviews-done/due in stats row + setting for `dailyReviewCap` |
| `lib/data/seed/cards_seed_data.dart` | **Modify** | Backfill `topicKeys` on each seed card |
| `lib/app.dart` | **Modify** | Initialize `feedComposerProvider` after `userProvider.load()` and `questsProvider.load()` |
| `test/srs_algorithm_test.dart` | **Create** | SM-2 transitions |
| `test/feed_ranker_test.dart` | **Create** | Score ordering / hard filters |
| `test/feed_composer_test.dart` | **Create** | Session composition / append behavior |

---

## Risks and Mitigation

| Risk | Mitigation |
|---|---|
| **Profile JSON bloat** — `cardReviews` map grows linearly with reviewed cards. At 1000 cards × ~80 bytes ≈ 80 KB per write. | Debounced writes (500 ms coalesce). Revisit at 1 MB threshold (per architect: "you're not there"). |
| **PageView index drift** if composer re-shuffles mid-session | Composer is **append-only** mid-session; full rebuild only on explicit `refresh()` (which resets index to 0 explicitly). |
| **First-run flood of "due" reviews** for upgrading users | Step 11 seeds existing `learnedCardIds` with a 6-day interval so they don't all bomb the user on day 1. |
| **Ranker scoring needs tuning** — first heuristics may feel arbitrary | Score function is a single pure function with unit tests; iterating is one-file change. Add `kRankingWeights` constants so future A/B tests just swap a weight map. |
| **Topic key mismatch** — seed cards have human tags ('AI History') that don't map to any onboarding topic | `topicKey` derivation is best-effort; cards with no canonical match still appear (no boost, no penalty). Step 5 also adds explicit `topicKeys` so curators can multi-tag. |
| **Quiz `parentCardId` may not exist in current learned-card scope** — quizzes may quiz on cards user hasn't seen yet | Recording quality on a card the user hasn't seen is fine — `recordReview` falls back to `CardReview.fresh`. The card just enters the SRS pool slightly ahead of schedule. |
| **Daily review cap interacts oddly with `dailyGoal`** — user could "complete" their daily goal entirely on reviews and never see new cards | Composer enforces minimum new-card slot count: `max(2, dailyGoal - reviewCap/2)` new cards even if reviews are plentiful. |
| **Session-seen set isn't persisted** — closing the app and reopening shows same first card again | Acceptable for v1 — it's a feature, not a bug ("resume where you left off"). Persist in v2 if user feedback demands it. |

---

## Acceptance Criteria

- [ ] `flutter analyze` reports 0 issues.
- [ ] `flutter test` passes (existing 9 + new ~12 = 21+).
- [ ] First-launch new user: feed leads with cards whose `topicKey` is in `selectedTopics`.
- [ ] After right-swiping a card, restarting the app, then waiting 1 simulated day: the same card appears in the feed marked as a review (not as new).
- [ ] Failing a quiz on card X causes X to re-appear within 5 cards (interval=1 reset).
- [ ] Profile screen shows "N reviews done / M due" stat that updates as the user scrolls.
- [ ] Pull-to-refresh on the feed regenerates the queue with current state.
- [ ] Daily review cap of 20 is respected even when 100+ cards are due.
- [ ] Existing user upgrade path: previously learned cards are seeded with a 6-day review schedule, not all marked due on day 1.

---

## Follow-up (out of scope for this slice)

These are intentionally deferred — call them out so we don't accidentally bundle:

1. **Backend sync** (recommendation #3) — once SRS state is meaningful, losing it on reinstall hurts. Add Firestore mirror for `UserProfile` + `cardReviews` *after* SRS is stable.
2. **Boss quiz** (recommendation #6) — depends on per-track quiz pool which already exists; small standalone slice.
3. **Notifications for due reviews** — depends on `flutter_local_notifications` and OS permissions; trigger when `dueCount > 0` at a user-set time.
4. **Streak freeze / pause days** (recommendation #9) — small modification to `updateStreak`.
5. **Light-mode pass** — most screens hardcode `AppColors.*`; needs a `Theme.of(context).colorScheme.*` sweep.

---

## SESSION_ID

- CODEX_SESSION: _(not used — codeagent-wrapper not installed)_
- GEMINI_SESSION: _(not used — codeagent-wrapper not installed)_
- ARCHITECT_AGENT_ID: `a252b5a707e3c448b` (validated storage choice + composer architecture)
