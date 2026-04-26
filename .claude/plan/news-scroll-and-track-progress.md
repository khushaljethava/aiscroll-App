# Plan: News scroll-to-read + Track progress fix + Resume-on-reopen

**Date:** 2026-04-26
**Three pieces, one plan:**
1. **News card** — clip the summary cleanly, reveal the rest with smooth in-card scroll, no fight with the vertical PageView.
2. **Tracks grid `0/23`** — completion counter never advances because progress is keyed off `learnedCardIds` but the swipe-through dwell flow only writes `readCardIdsToday`. Fix the data flow.
3. **Resume on reopen** — when reopening a track, jump to the card the user was last on instead of always starting at index 0.

---

## 1. Root-cause analysis (where the existing code stands)

### News card (`lib/features/news/screens/news_screen.dart`)

The story page already has a `SingleChildScrollView` for the text column (line ~553). On long articles it does scroll, but two UX problems:
- The vertical scroll inside the column **conflicts with the parent vertical PageView**: a drag inside the text often triggers a page swipe instead of scrolling the text. Users perceive this as "the text doesn't scroll."
- Even when scroll works, there's no visual hint that there's more text below — content just hard-clips at the action bar.

### Tracks `0/23` bug (`lib/features/feed/screens/track_learn_screen.dart:150`)

```dart
Future<void> _awardReadXP(LearningCard card) async {
  final counted = await _userNotifier.markCardRead(card.id);
  if (!counted) return;
  await _userNotifier.addXP(XPConstants.readCard, source: 'read_card');
  _gamificationNotifier.triggerXP(XPConstants.readCard);
  await _questsNotifier.recordEvent(QuestType.readCards);
  await _srsNotifier.recordReview(card.id, 3);
}
```

This calls `markCardRead` which writes to `readCardIdsToday` (the *daily* counter — resets at midnight rollover, see `user_provider.dart:185`).

But `tracks_screen.dart:191–192` reads progress as:
```dart
final learned = user.learnedCardIds;
final completed = track.completedCount(learned);
```

`learnedCardIds` is the *permanent* per-card "I've read this" set, populated only by `markCardLearned`, which the swipe-through dwell flow never calls. Result: `learnedCardIds` stays empty, `completedCount` returns 0, progress bar stays at 0/23 forever. Even reading 1000 cards across 100 sessions will not move the needle.

### Resume-on-reopen

Today, every entry to `TrackLearnScreen` constructs a fresh `PageController()` (`track_learn_screen.dart:65`) which defaults to `initialPage: 0`. There's no per-track resume-position state on `UserProfile` and no logic that would consult one.

---

## 2. Solutions

### 2.1 News card — scroll + clip + reveal

**Pattern:** the page itself scrolls vertically as a single coherent unit (header → image → text → action bar) inside a `Scrollable` whose physics yield to the parent `PageView` only at the scroll extents. Result: when summary is long, you scroll *within* the page; when you reach the top or bottom, the next swipe pages to the next story. Industry-standard "Inshorts / Twitter detail" feel.

Concrete approach (no third-party packages):
- Wrap the whole story body in a `CustomScrollView` (or `SingleChildScrollView`) with `physics: ClampingScrollPhysics()` + a `NotificationListener<ScrollEndNotification>` is overkill for v1. The simple working pattern is:
  - Make the story page itself a `SingleChildScrollView` containing image + text + source + action bar in vertical order.
  - The image is a fixed-height block (e.g. 300 dp), text flows naturally below, action bar is the last child.
  - PageView is unchanged; gesture conflict resolves itself because Flutter's `ScrollPosition` only competes with PageView when the inner reaches `extentBefore == 0` (top) on a downward drag. When the inner has scrolled, downward drag scrolls inner, upward drag at the bottom pages.
- Add a **subtle bottom fade** (a 32 dp linear gradient overlaying the bottom edge) so users see content is clipped and there's more below. The fade animates out as the user scrolls to the end.

We retain the existing "Read full story" CTA at the bottom for users who want the full reader.

### 2.2 Track progress fix

Two valid strategies; we go with the simpler one:

**Chosen — read = learned (collapsed semantics).** When the dwell timer fires and we award XP, also mark the card learned. `markCardLearned` is already idempotent. This makes the tracks grid count match what the user expects ("I scrolled past this card → it's done").

The bookmark concept (`bookmarkedCardIds`) stays separate. The "I really want to revisit this" path still exists and is unchanged.

Edge case: bossquiz unlock. `tracks_screen.dart` already gates the boss quiz on `completedCount`. Once we collapse read=learned, the gate becomes "scrolled all cards → boss quiz unlocked", which matches the existing UX intention.

Backward-compatibility: existing users have `readCardIdsToday` populated (today's reads) and possibly `learnedCardIds` populated (legacy explicit "Mark learned" taps from the detail view). Going forward, every dwell-completed card adds to *both*. No migration needed.

### 2.3 Resume-on-reopen

Add `Map<String, String> lastCardByTrack` to `UserProfile`:
- Updated on every page change in `TrackLearnScreen._onPageChanged` (only when the current item is a `LearningCard` — skip quizzes and ads so the resume target is always meaningful).
- Read in `TrackLearnScreen.initState` after `_computeItems`. Find the index of that card id in `_items`; if found, `pageController.jumpToPage(index)` on the next frame.
- Also persisted via existing `_scheduleSave` debounce → `_scheduleCloudSave` → mirrors to Firestore (multi-device resume comes free).

Don't auto-skip past learned cards; we open at the *last viewed* card, which may be a learned one or the first unlearned one — same behaviour as a real bookmark. If the user rage-quits at card 12, they reopen at card 12, not card 5.

If a track has no resume state (first open), behave as today (start at index 0).

---

## 3. Implementation steps

### Step A — News card scroll-to-read

**File:** `lib/features/news/screens/news_screen.dart`

A1. Replace the `_StoryPage`'s outer layout. Currently:
```
Material → InkWell → Container → Column → [Expanded(image), Expanded(scrollable text), action bar]
```
becomes:
```
Material → InkWell → Container → Column → [
   SingleChildScrollView (Expanded) → Column → [image-block, text-block, source-row],
   action bar (fixed at bottom),
]
```

A2. Image: was `Expanded(flex: 5, child: Stack(...))`. Convert to a fixed-height `SizedBox(height: 320, child: Stack(...))` so it scrolls with the rest. The hero overline + pinned badge stay in the Stack.

A3. Text column: was inside an inner `SingleChildScrollView`. Drop that — the outer scroll handles it. Keep the same widget tree (time-row, headline, summary, source-row).

A4. Add bottom-edge fade. After the action bar in the parent Column, wrap the scrollable in a `Stack` that overlays a `_FadeEdge` gradient when the scroll position has not reached the end. Implementation: a `ScrollController` watches the scroll, a `ValueNotifier<bool>` flips when `position.pixels < maxScrollExtent - 24`. The fade widget wraps an `IgnorePointer` so it never eats touches.

Pseudo:
```dart
final _scroll = ScrollController();
final _hasMore = ValueNotifier(true);
_scroll.addListener(() {
  final v = _scroll.position.pixels < _scroll.position.maxScrollExtent - 24;
  if (v != _hasMore.value) _hasMore.value = v;
});

Stack(children: [
  SingleChildScrollView(
    controller: _scroll,
    physics: const ClampingScrollPhysics(),
    child: Column(children: [imageBlock, padding(textBlock), padding(sourceRow), SizedBox(height: 12)]),
  ),
  Positioned(left: 0, right: 0, bottom: 0, height: 32,
    child: ValueListenableBuilder(
      valueListenable: _hasMore,
      builder: (_, more, __) => IgnorePointer(child: AnimatedOpacity(
        duration: 180.ms, opacity: more ? 1 : 0,
        child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.transparent, cs.surface.withValues(alpha: 0.95)],
        ))),
      )),
    ),
  ),
]);
```

A5. Convert `_StoryPage` from `StatelessWidget` to `StatefulWidget` for the `_scroll`/`_hasMore` lifecycle. Dispose both in `dispose`.

### Step B — Track progress: collapse read = learned

**File:** `lib/features/feed/screens/track_learn_screen.dart`

B1. In `_awardReadXP` (line ~150), after `markCardRead` succeeds, also call `markCardLearned`:
```dart
Future<void> _awardReadXP(LearningCard card) async {
  final counted = await _userNotifier.markCardRead(card.id);
  if (!counted) return;
  // Track-grid progress + boss-quiz gate read off `learnedCardIds`. Marking
  // here keeps "I've scrolled this card" and "I've learned it" aligned —
  // bookmark remains the explicit "save for later" affordance.
  await _userNotifier.markCardLearned(card.id);
  await _userNotifier.addXP(XPConstants.readCard, source: 'read_card');
  _gamificationNotifier.triggerXP(XPConstants.readCard);
  await _questsNotifier.recordEvent(QuestType.readCards);
  await _srsNotifier.recordReview(card.id, 3);
}
```

B2. (Optional) `learn_detail_screen` (the detail reader) likely has a "Mark learned" button. Verify it doesn't double-call XP — `markCardLearned` is idempotent so it's safe, but if both XP paths run we may double-award. Inspect during implementation.

### Step C — Resume-on-reopen

**File 1:** `lib/data/models/user_model.dart`

C1. Add `lastCardByTrack` field:
```dart
final Map<String, String> lastCardByTrack;
```
- Default `const {}` in the const constructor and `fromMap`.
- Add to `copyWith` (passthrough) — does NOT need the sentinel pattern since maps are non-nullable.
- Add to `toMap` and `fromMap`.

C2. `toFirestoreMap` already includes everything from `toMap` — automatic mirror.

**File 2:** `lib/data/providers/user_provider.dart`

C3. Add a setter on `UserNotifier`:
```dart
Future<void> setLastCardForTrack(String trackId, String cardId) async {
  // Skip rewriting same value — avoids a Firestore write storm during
  // rapid swipe sessions where every page change emits an event.
  if (state.lastCardByTrack[trackId] == cardId) return;
  final next = Map<String, String>.from(state.lastCardByTrack);
  next[trackId] = cardId;
  state = state.copyWith(lastCardByTrack: next);
  _scheduleSave(); // debounced local + cloud write
}
```

**File 3:** `lib/features/feed/screens/track_learn_screen.dart`

C4. After `_computeItems` in `initState`, compute the resume index:
```dart
final lastCardId = ref.read(userProvider).lastCardByTrack[widget.trackId];
final resumeIdx = lastCardId == null
    ? 0
    : _items.indexWhere((it) => it is LearningCard && it.id == lastCardId);
final initialPage = (resumeIdx > 0) ? resumeIdx : 0;
_pageController = PageController(initialPage: initialPage);
_currentIndex = initialPage;
```

If `_items` is empty or `lastCardId` no longer exists in this track (deleted from manifest), fall back to `0`.

C5. In `_onPageChanged`, after we identify the current item is a `LearningCard`, persist the position:
```dart
if (item is LearningCard) {
  _startDwell(item);
  _userNotifier.setLastCardForTrack(widget.trackId, item.id);
}
```

C6. `_primeDwellForCurrent` already kicks dwell on the first card. If `initialPage > 0`, the `addPostFrameCallback` won't fire `_primeDwellForCurrent` for the resumed item since that helper currently assumes `_items.first`. Fix:

```dart
void _primeDwellForCurrent() {
  if (_items.isEmpty) return;
  final idx = _currentIndex.clamp(0, _items.length - 1);
  final item = _items[idx];
  if (item is LearningCard) _startDwell(item);
}
```

Now resume + dwell works for any starting index.

---

## 4. Key files & line targets

| File | Operation | Description |
|---|---|---|
| `lib/features/news/screens/news_screen.dart:405–660` | Refactor `_StoryPage` | StatelessWidget → StatefulWidget; flatten Column into single SingleChildScrollView + fixed action bar; add `_FadeEdge` overlay; introduce `ScrollController` + `ValueNotifier<bool> _hasMore`. |
| `lib/features/news/screens/news_screen.dart` (new bottom of file) | Add | Private `_FadeEdge` widget + scroll-controller fields. |
| `lib/features/feed/screens/track_learn_screen.dart:150` | Edit | Add `await _userNotifier.markCardLearned(card.id);` so tracks grid counts climb on read. |
| `lib/features/feed/screens/track_learn_screen.dart:65` (initState) | Edit | Compute `initialPage` from `lastCardByTrack[trackId]`; use it in `PageController(initialPage: …)`. |
| `lib/features/feed/screens/track_learn_screen.dart:131` (`_primeDwellForCurrent`) | Edit | Use `_currentIndex` instead of hardcoded `_items.first`. |
| `lib/features/feed/screens/track_learn_screen.dart:168` (`_onPageChanged`) | Edit | Call `_userNotifier.setLastCardForTrack(trackId, item.id)` on each `LearningCard` page. |
| `lib/data/models/user_model.dart:54–328` | Add field | `lastCardByTrack: Map<String, String>` + constructor default + `copyWith` + `toMap` + `fromMap`. |
| `lib/data/providers/user_provider.dart` (after `completeTrackProgress`) | Add method | `setLastCardForTrack(trackId, cardId)` with no-op short-circuit for same-value writes. |

---

## 5. Risks & mitigation

| Risk | Mitigation |
|---|---|
| Outer `SingleChildScrollView` competes with vertical `PageView` for swipe gestures, especially at scroll extents | Use `ClampingScrollPhysics` on the inner scroller. Flutter resolves: PageView sees the gesture only after the inner scroll hits its boundary. Standard pattern, no special code needed. |
| Some users explicitly tap "Mark learned" in the detail view today — collapsing read=learned could feel like the explicit button is meaningless | The explicit button still works (idempotent). Optional follow-up: rename the detail button "Mark mastered" with a stronger semantic, or hide it once read. Out of scope for v1. |
| `lastCardByTrack` writes on every page change → cloud-write storm | The notifier short-circuits when value is unchanged, AND the cloud-write is debounced 1 s. A user swiping through 10 cards in 6 s produces ~1 cloud write. |
| Track manifest changes — saved `lastCardId` no longer in the track | `_items.indexWhere(...)` returns -1; we fall back to index 0. |
| Bottom fade overlay swallows touches at the very bottom of the action bar | `IgnorePointer` wrapping the gradient ensures all touches fall through to the action bar / content beneath. |
| Animation stutter on low-end devices when scrolling long articles | The fade is a single gradient overlay with 180 ms opacity tween — cheap. Image is a single `CachedNetworkImage`, already optimised. |
| Dwell timer might re-fire after `pageController.jumpToPage` in initState before user interacts | `_primeDwellForCurrent` is called once after the first frame. Behaviour is identical to a fresh-start at index 0 — XP + read-counter only fire after the 5 s threshold elapses. |

---

## 6. Testing strategy

### Manual QA
1. Open a news story with a long summary (one of the longer business pieces). Drag down inside the text — content scrolls, page does not change. Drag down again at the bottom — page swipes to next story. Drag up at the top — page swipes to previous. Bottom fade visible until you scroll to the end, then fades out.
2. Open a track. Read 4 cards (5 s dwell each). Go back to tracks grid → progress shows `4/23` (or whatever `track.totalCards` is). Boss-quiz button stays gated until all are read.
3. From the tracks grid, reopen the same track → opens at card 4 (the last one you were on). Swipe to card 7 → kill the app → reopen → opens at card 7.
4. Sign in on a second device with the same account (Firestore sync) → reopen the track → resumes at card 7 there too.

### Unit
- `UserProfile.toMap`/`fromMap` round-trip with non-empty `lastCardByTrack`.
- `setLastCardForTrack`: same-value call is a no-op (no state mutation, no save scheduled). Different-value triggers exactly one save.

### Edge cases
- Empty track: don't crash; pageController defaults to 0.
- `lastCardId` points at a deleted card: index lookup returns -1; fallback to 0.
- All cards already learned + reopen: still resumes at last card (same as today).

---

## 7. Out of scope

- "Read more" inline expansion modal (not needed — the in-card scroll covers the use-case).
- Reading-progress bar per article (would require timing every story; nice-to-have).
- Resume across multi-device with conflict resolution (not needed — last-write-wins on the cloud profile is fine).

---

## SESSION_ID (for /ccg:execute use)
- CODEX_SESSION: (skipped — wrapper not installed)
- GEMINI_SESSION: (skipped — wrapper not installed)
