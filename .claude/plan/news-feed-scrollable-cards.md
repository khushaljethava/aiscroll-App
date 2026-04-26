# Plan: News feed — full-card scroll, no internal scroll, smaller headline

**Date:** 2026-04-26
**Correction of:** my last plan (`news-scroll-and-track-progress.md`) — I built per-page internal scroll with vertical PageView, opposite of what you asked.

**What you actually want:**
1. **Whole news card scrolls** — vertical feed where each card is its full natural height; you scroll the *list*, not within a single page.
2. **No internal scrolling on the card body** — the entire summary text shows inline, no clipping, no fade overlay.
3. **Headline font smaller** — current `headlineMedium` (28 sp) is too big.
4. **Better visual design** — cards feel polished, distinct from one another, hold their own in a continuous feed.

---

## 1. What's wrong with the current `news_screen.dart`

After my last edit:
- `_FeedBody` renders a vertical `PageView.builder` — one full-screen story per page; you swipe up/down to advance.
- `_StoryPage` is a `StatefulWidget` with its own `ScrollController` and a `SingleChildScrollView` for the text + a `_FadeEdge` gradient overlay.
- The image is fixed-height inside the inner scroller; the action bar is pinned at the bottom of each page.

That's "swipe-paged stories with internal scroll" — the *opposite* of "scrollable feed of self-contained cards." The whole `_StoryPage` and PageView pattern needs to go.

---

## 2. Target architecture

```
NewsScreen
└── Column
    ├── stale-banner (unchanged)
    ├── category rail (unchanged)
    └── Expanded
        └── RefreshIndicator (pull-to-refresh)
            └── ListView.builder            ← was PageView.builder
                  itemBuilder:
                    if (item is NewsArticle) → _StoryCard
                    if (item is _FeedAdSlot) → NativeAdCard (already wired)
```

Each `_StoryCard` is a self-contained editorial card:
- Hero image (rounded top corners, height 200 dp)
- Category overline + relative time row
- **Headline** (sized down from 28 sp → 20 sp, `titleLarge`)
- Summary (fully visible; no `maxLines`, no `overflow`, no scroll)
- Source row (avatar + name)
- Inline action bar (Read full story / save / share / open source)

Because every card is natural-height and the parent scrolls, the user can scroll up/down through the entire feed continuously — Twitter / Reddit / Hacker News style.

The interleaved ad sentinels (`_FeedAdSlot`) and `interleaveAds()` helper stay as-is. `NativeAdCard` already adapts to natural height; no change needed.

---

## 3. Design refresh

Concrete visual choices for "add some design":

- **Card surface:** `Theme.of(context).colorScheme.surface` with subtle border (`outlineVariant`), `BorderRadius.circular(20)`, no heavy shadow (clean editorial vibe).
- **Spacing:** 12 dp gap between cards; horizontal screen gutter via `AppSpacing.screenGutter`.
- **Image:** 200 dp height, full-width, `BorderRadius.vertical(top: Radius.circular(20))`. Keep the existing 3 dp accent bar at the very top of the image and the bottom scrim gradient.
- **Overline + time row:** sits *above* the headline (not on the image), padding 18 dp horizontal / 16 dp top. Category dot (6 dp) + uppercase category label + bullet separator + relative time + "Read" pill if read.
- **Headline:** `titleLarge` (≈ 22 sp default) with `fontSize: 20`, `FontWeight.w700`, `height: 1.25`, `letterSpacing: -0.2`. **Three-line max wouldn't be needed** — show the full headline (some are short, some are 3-4 lines).
- **Summary:** `bodyLarge` `fontSize: 15`, `height: 1.55`, no max-lines, full text visible.
- **Source row:** small (24 dp) circle avatar with first letter, source name in `labelLarge`. Tappable → opens source URL.
- **Action bar:** flat, no top border — `Row` of icon buttons (32 dp tap targets) + a small text "Read more →" button at the right that opens the detail screen. Less visually heavy than the pill-shaped "Read full story" CTA on the previous design (which fit a full-screen card but is too prominent inline).
- **Featured pinned badge:** stays — top-right of the image area.

---

## 4. "Mark as read" semantics — adjusted for a feed

Today, `_onPageChanged` calls `markNewsRead` when a story becomes the active page. With a continuous scroll feed there's no "active page," so we need a new trigger.

Three options:

| Option | Pros | Cons |
|---|---|---|
| Mark on tap (Read full story / Save / Share / Open source) | Zero false positives — user clearly engaged | Most users never tap; "read" stays empty |
| Mark on `VisibilityDetector` ≥ 50 % for ≥ 1 s | Matches what users would call "I read it" | Adds `visibility_detector` dep (~30 KB, well-maintained Flutter Team package) |
| Mark on first build (i.e., card scrolls into viewport once) | No new dep; ListView.builder lazy-builds so it's effectively visible | Mass-marks anything that's even briefly in the off-screen prebuild range (overcounts) |

**Chosen:** option 2 — `visibility_detector`. It's the right semantic, the dep is trivial, and we get accurate "I saw this" tracking which feeds telemetry, badges, daily quests honestly.

Implementation:
- Add `visibility_detector: ^0.4.0+2` to `pubspec.yaml`.
- Wrap each `_StoryCard` in `VisibilityDetector(key: ValueKey(article.id), onVisibilityChanged: …)`.
- In the callback, when `info.visibleFraction >= 0.5`, start a 1-second timer; if the card is still ≥ 50 % visible after 1 s, fire `markNewsRead`. Cancel the timer if visibility drops first. Idempotent — `markNewsRead` already short-circuits on already-read ids.

---

## 5. Implementation steps

### Step 1 — Add dep
**File:** `pubspec.yaml`
```yaml
visibility_detector: ^0.4.0+2
```
`flutter pub get`.

### Step 2 — Replace `_FeedBody` body
**File:** `lib/features/news/screens/news_screen.dart`

Replace the `PageView.builder` branch with:
```dart
return RefreshIndicator(
  onRefresh: onRefresh,
  color: cs.onSurface,
  backgroundColor: cs.surfaceContainerHighest,
  child: ListView.separated(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.screenGutter, AppSpacing.sm,
      AppSpacing.screenGutter, AppSpacing.xl,
    ),
    physics: const AlwaysScrollableScrollPhysics(),
    itemCount: items.length,
    separatorBuilder: (_, _) => const SizedBox(height: 12),
    itemBuilder: (context, index) {
      final item = items[index];
      if (item is _FeedAdSlot) {
        // NativeAdCard adapts to natural height — wrap in fixed
        // height because the AdMob native template needs intrinsic
        // size constraints inside a scrollable parent.
        return SizedBox(
          height: 360,
          child: NativeAdCard(key: ValueKey('news_ad_$index')),
        );
      }
      final article = item as NewsArticle;
      final category = categoryByKey[article.categoryKey];
      return _StoryCard(
        article: article,
        categoryLabel: category?.label ?? article.categoryKey,
        accent: AppColors.categoryAccent(article.categoryKey),
        isSaved: bookmarkedIds.contains(article.id),
        isRead: readIds.contains(article.id),
        onMarkRead: () => onMarkRead(article),   // NEW callback (visibility-driven)
        onOpen: () => onOpen(article),
        onBookmark: () => onBookmark(article),
        onShare: () => onShare(article),
        onOpenSource: () => onOpenSource(article),
      );
    },
  ),
);
```

`onPageChanged`/`pageController` go away. `_NewsScreenState` no longer needs the controller.

### Step 3 — Add `onMarkRead` plumbing
**File:** `lib/features/news/screens/news_screen.dart`

In `_NewsScreenState`:
```dart
void _onMarkRead(NewsArticle article) {
  // ignore: discarded_futures
  ref.read(userProvider.notifier).markNewsRead(article.id);
}
```

Pass it into `_FeedBody` along with the existing callbacks. Drop the existing `_onPageChanged` method; haptics now fire on the visibility callback inside `_StoryCard` instead (or skip haptics on auto-read — they're noise).

### Step 4 — Replace `_StoryPage` with `_StoryCard`
**File:** `lib/features/news/screens/news_screen.dart`

Delete `_StoryPage` (StatefulWidget with `_scroll`/`_hasMoreBelow`) and the `_HeroImage` extracted helper. Replace with a leaner `_StoryCard`:

```dart
class _StoryCard extends StatefulWidget {
  const _StoryCard({
    required this.article,
    required this.categoryLabel,
    required this.accent,
    required this.isSaved,
    required this.isRead,
    required this.onMarkRead,
    required this.onOpen,
    required this.onBookmark,
    required this.onShare,
    required this.onOpenSource,
  });
  // ...fields
  @override
  State<_StoryCard> createState() => _StoryCardState();
}

class _StoryCardState extends State<_StoryCard> {
  Timer? _readTimer;

  void _onVisibilityChanged(VisibilityInfo info) {
    if (widget.isRead) return;                   // already counted
    if (info.visibleFraction >= 0.5) {
      _readTimer ??= Timer(const Duration(seconds: 1), widget.onMarkRead);
    } else {
      _readTimer?.cancel();
      _readTimer = null;
    }
  }

  @override
  void dispose() {
    _readTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final hasImage = widget.article.coverImageUrl?.isNotEmpty ?? false;

    return VisibilityDetector(
      key: ValueKey('news_card_${widget.article.id}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onOpen,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero image (200 dp, rounded top corners come from clipBehavior)
                _CardHero(
                  article: widget.article,
                  accent: widget.accent,
                  hasImage: hasImage,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Overline + time row (no "READ" pill on the card itself —
                      // we'll show a subtle dimmed state for whole-card if needed)
                      _CardOverline(
                        categoryLabel: widget.categoryLabel,
                        accent: widget.accent,
                        publishedAt: widget.article.publishedAt,
                        isRead: widget.isRead,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.article.headline,
                        style: tt.titleLarge?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.article.summary,
                        style: tt.bodyLarge?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 15,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _SourceRow(
                        sourceName: widget.article.sourceName,
                        accent: widget.accent,
                      ),
                    ],
                  ),
                ),
                // Action bar — flat, no top border. Compact.
                _CardActionBar(
                  isSaved: widget.isSaved,
                  onOpen: widget.onOpen,
                  onBookmark: widget.onBookmark,
                  onShare: widget.onShare,
                  onOpenSource: widget.onOpenSource,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

### Step 5 — `_CardHero`, `_CardOverline`, `_CardActionBar` widgets
Small private widgets that compose the card. `_SourceRow`, `_PhotoFallback`, `_ReadPill`, `_Overline` already exist — reuse where possible, but rebuild the action bar more compact:

```dart
class _CardActionBar extends StatelessWidget {
  // ...
  Widget build(...) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: [
          _IconBtn(icon: isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            color: isSaved ? AppColors.ctaAmber : cs.onSurfaceVariant,
            tooltip: isSaved ? 'Remove bookmark' : 'Save', onTap: onBookmark),
          _IconBtn(icon: Icons.ios_share_rounded, color: cs.onSurfaceVariant, tooltip: 'Share', onTap: onShare),
          _IconBtn(icon: Icons.open_in_new_rounded, color: cs.onSurfaceVariant, tooltip: 'Open source', onTap: onOpenSource),
          const Spacer(),
          TextButton(
            onPressed: onOpen,
            child: const Text('Read more'),
          ),
        ],
      ),
    );
  }
}
```

### Step 6 — Initialize `VisibilityDetectorController` (recommended)
**File:** `lib/main.dart`

After `WidgetsFlutterBinding.ensureInitialized()`:
```dart
VisibilityDetectorController.instance.updateInterval = const Duration(milliseconds: 100);
```
The default is 500 ms which feels sluggish for a 1-second mark-as-read threshold. 100 ms gives crisp behaviour without overhead.

### Step 7 — Remove dead code
- Delete `_StoryPage`, `_StoryPageState`, `_HeroImage`, `_FadeEdge` references, `_PrimaryCta`, `_RoundAction` if no other widget uses them. Keep `_PhotoFallback`, `_Overline`, `_ReadPill`, `_SourceRow`, `_LoadingSkeleton`.
- Delete `_pageController` field from `_NewsScreenState` and `dispose()` cleanup.
- Drop `_onPageChanged` method.
- The `_NewsScreenState._onRefresh` no longer needs `_pageController.jumpToPage(0)` — RefreshIndicator handles scroll-to-top naturally.

---

## 6. Key files

| File | Operation | Description |
|---|---|---|
| `pubspec.yaml` | Add | `visibility_detector: ^0.4.0+2`. |
| `lib/main.dart` | Edit | Set `VisibilityDetectorController.instance.updateInterval` to 100 ms. |
| `lib/features/news/screens/news_screen.dart:32–47` (`_NewsScreenState`) | Edit | Drop `_pageController` + dispose, drop `_onPageChanged`, add `_onMarkRead`, simplify `_onRefresh`. |
| `lib/features/news/screens/news_screen.dart:347–412` (`_FeedBody`) | Replace | `PageView.builder` → `ListView.separated` with `RefreshIndicator`. Pass `onMarkRead` through. |
| `lib/features/news/screens/news_screen.dart:404–960` | Replace | Delete `_StoryPage`, `_StoryPageState`, `_HeroImage`. Add `_StoryCard`, `_StoryCardState`, `_CardHero`, `_CardOverline`, `_CardActionBar`, `_IconBtn`. |
| Existing helpers | Keep | `_PhotoFallback`, `_Overline`, `_ReadPill`, `_SourceRow`, `_LoadingSkeleton`. |
| `_PrimaryCta`, `_RoundAction` | Delete | No longer referenced. |

---

## 7. Risks & mitigation

| Risk | Mitigation |
|---|---|
| Long summaries make individual cards very tall — list scroll feels jumpy on cheap devices | `ListView.builder` lazy-builds. `CachedNetworkImage` is already cached. With 30 articles, it's fine. If we see complaints, add `cacheExtent: 1500` to ListView. |
| `VisibilityDetector` adds a tiny perf cost from layout post-frame callbacks | 100 ms throttle keeps it well below 60 fps budget. Flutter Team package is widely shipped (used by core Google apps). |
| Native ad cards used `AdWidget` inside an `Expanded` previously — won't work in a list | We wrap in `SizedBox(height: 360)`. Matches `TemplateType.medium` natural size. |
| Visibility callbacks fire repeatedly when user scrolls back/forth | Single-shot timer per card; cleared on dispose. `markNewsRead` is idempotent. |
| Feed cards now have inline action bar — taps on icons might bubble to the card's `InkWell` open-detail | `InkWell` is on the card root; `_CardActionBar` uses `IconButton`/`TextButton` which absorb their own taps. Standard Flutter behaviour, no special handling. |
| Hardcoded headline `fontSize: 20` ignores user-side text scaling | Acceptable for v1 — `MediaQuery.textScaler` will still scale the value at render time. |

---

## 8. Testing

### Manual
1. Open News tab → scroll through ~10 articles. Whole feed scrolls smoothly. Each card shows full headline + full summary, no "fade" gradient anywhere.
2. Tap a card → opens detail. Pull down at the top → refresh.
3. Headline visibly smaller (was filling 4-5 lines for many stories, now ~2-3 lines).
4. Native ad slots (every 7 cards) still appear, look natural in the feed.
5. Stay on a card 1+ seconds → next launch / next refresh: that card has the dimmed/read state.

### Edge cases
- Empty feed: empty-state view (unchanged).
- Very short summary (1-line): card looks balanced, not awkward.
- Very long summary (10+ lines): card grows naturally; user scrolls past.
- Slow network: hero image placeholder shows; rest of card paints immediately.
- Rotation / split-screen: ListView reflows, scroll position preserved.

---

## 9. Out of scope
- Animation when cards enter the viewport (could add later with `flutter_animate`).
- Article-level "save the scroll position" persistence — go_router restoration handles tab-switch scroll preservation already.
- Reading-progress per article (not asked; would need timing).
- Pinned/featured stories surfaced at top of the feed in a different card style — could be a follow-up.

---

## SESSION_ID (for /ccg:execute use)
- CODEX_SESSION: (skipped — wrapper not installed)
- GEMINI_SESSION: (skipped — wrapper not installed)
