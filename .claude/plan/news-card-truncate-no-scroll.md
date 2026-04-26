# Plan: News card — drop inner scroll, truncate summary, fade hint

**Date:** 2026-04-26
**Problem:** When a story has a long headline + long summary, the inner `SingleChildScrollView` (`news_screen.dart:472`) absorbs vertical drag gestures, so the user can't swipe up to the next story until they scroll the inner content to its bottom. UX result: people get "stuck" on long cards.

---

## 1. Why this happens (Flutter mechanics)

```
PageView.builder (vertical)
└── _StoryPage
    └── Column
        ├── Expanded(flex:5) → image (no scroll)
        ├── Expanded(flex:6) → SingleChildScrollView ← captures vertical drags
        └── action bar
```

A vertical drag on the text region first goes to the *innermost* `Scrollable`. Only when the inner reaches its scroll extent does Flutter "bubble" the gesture up to the parent `PageView`. So on a card whose summary is, say, 1.5× the available height, the user has to:
1. Drag to scroll the text down,
2. Reach the bottom,
3. *Then* swipe again to page.

That's two distinct gestures for one mental action ("next story"). Confusing on a feed.

---

## 2. Three options I considered

| Option | UX | Implementation cost |
|---|---|---|
| **A. Truncate + fade hint + "Read full story"** | Card is a teaser; full reader for long-form. One gesture = one page change, every time. | 30 lines of edits. |
| B. Custom `ScrollPhysics` to convert fast flings into page changes | Best of both worlds in theory. | High — gesture-arena work, easy to break. Edge cases multiply. |
| C. Show full body, accept overflow clipping | Keeps everything visible-ish but cuts text off at the action bar. | Trivial. |
| D. Disable inner scroll *and* keep full text — let it spill behind the action bar | Same as C with no clipping but partial readability. | Trivial but ugly. |

**Chosen: Option A.** It matches the editorial-card pattern (Inshorts, Apple News, NYT) where the card is intentionally a bite-sized teaser. The "Read full story" CTA finally earns its prominence.

---

## 3. Solution detail

### 3.1 Drop the inner scroll
Replace `Expanded(flex: 6, child: SingleChildScrollView(...))` with a plain `Expanded(flex: 6, child: Padding(...))`. The text column now lays out within the available height, no scrolling.

### 3.2 Truncate summary with ellipsis
```dart
Text(
  article.summary,
  maxLines: 7,                     // tunable — see §3.4 below
  overflow: TextOverflow.ellipsis,
  style: tt.bodyLarge?.copyWith(
    color: cs.onSurfaceVariant,
    height: 1.55,
    fontSize: 15.5,
  ),
),
```

### 3.3 Soft fade hint at the bottom
A 24 dp gradient overlay along the bottom edge of the text region, fading from transparent to surface color. Tells the reader "there's more, tap to see it" without shouting. Wrap the text-region `Stack(children: [textColumn, fadeOverlay])`.

The fade is **only** shown when the summary is actually truncated. We measure: if text rendered with `TextPainter` exceeds the available size, fade is on; else hidden. (Cheap — Flutter's `Text` already runs this layout, we re-use it via a `LayoutBuilder` or just always show a faint fade since most articles will overflow at this width.)

For v1, **always show a faint fade** (alpha ~0.6 at the bottom edge). Simpler than measuring per-card; doesn't hurt anything when the text fits.

### 3.4 Picking `maxLines`
Default Flutter card heights at moto g13 (720×1516 dp viewport):
- After top bar (~48), category rail (~42), card padding (8+8), bottom nav (~80) → card height ≈ 1330 dp.
- Card flex 5/6 split → text region ≈ 720 dp tall.
- Headline (3 lines × 21 sp × 1.22 line-height ≈ 77 dp) + 16 dp gap + source row (50 dp) + 16 dp gap = ~160 dp non-summary.
- Summary budget ≈ 560 dp.
- Body 15.5 sp × 1.55 line-height ≈ 24 dp/line → ~23 lines fit.

So **7 lines is conservative and works on every device**. We could push to 9-10 on tall phones, but the truncation should be obvious enough that users tap through. Keep it at 7.

### 3.5 Make "Read full story" the primary CTA
Already done — the bottom action bar's pill-shaped CTA opens detail. The truncation makes this CTA *meaningful* now (was decorative before because the full story was already on-card).

---

## 4. Implementation steps

### Step 1 — Edit `_StoryPage` text region
**File:** `lib/features/news/screens/news_screen.dart`

Replace:
```dart
Expanded(
  flex: 6,
  child: SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(...),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(...time + read pill...),
        const SizedBox(height: AppSpacing.sm),
        Text(article.headline, style: ...),
        const SizedBox(height: AppSpacing.md),
        Text(article.summary, style: ...),
        const SizedBox(height: AppSpacing.lg),
        _SourceRow(...),
      ],
    ),
  ),
),
```

with:

```dart
Expanded(
  flex: 6,
  child: Stack(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(...time + read pill... unchanged),
            const SizedBox(height: AppSpacing.sm),
            Text(
              article.headline,
              maxLines: 4,                        // safety cap; rarely hit
              overflow: TextOverflow.ellipsis,
              style: tt.titleLarge?.copyWith(
                color: cs.onSurface,
                fontSize: 21,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                height: 1.22,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: Text(
                article.summary,
                maxLines: 7,
                overflow: TextOverflow.ellipsis,
                style: tt.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.55,
                  fontSize: 15.5,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SourceRow(
              sourceName: article.sourceName,
              accent: accent,
            ),
          ],
        ),
      ),
      // Bottom fade hint — IgnorePointer so it never eats taps.
      Positioned(
        left: 0, right: 0, bottom: 0, height: 28,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  cs.surface.withValues(alpha: 0),
                  cs.surface.withValues(alpha: 0.92),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  ),
),
```

Two structural notes:
- The summary `Text` is wrapped in `Expanded` so it absorbs the remaining vertical space inside the text column. That guarantees the source row always sits just above the action bar, and the truncation kicks in based on real available height (not just `maxLines: 7`).
- Headline gets `maxLines: 4` as a defensive cap — most are 2-3 lines, but a freak 5-liner would push the source row off-screen.

### Step 2 — Verify nothing else broke
- `_LoadingSkeleton` already mirrors the layout — no change needed.
- `_StoryPage` parent `Material → InkWell(onTap: onOpen)` still wraps the whole card, so a tap anywhere outside the action-bar buttons opens the detail reader. That's the user's path to the full text.

### Step 3 — Run analyzer
`flutter analyze` should be clean. No new dependencies.

---

## 5. Key files

| File | Operation | Description |
|---|---|---|
| `lib/features/news/screens/news_screen.dart:472–506` | Edit | Replace `SingleChildScrollView` with `Stack(Padding(Column), fadeOverlay)`. Add `maxLines` + ellipsis on headline (4) and summary (7). Wrap summary in `Expanded`. |

That's it. ~25-line edit.

---

## 6. Risks & mitigation

| Risk | Mitigation |
|---|---|
| Some users *want* to read the full summary on the card | The fade overlay + the prominent "Read full story" CTA both signal the action. Editorial-card precedent (Inshorts) trains users for this pattern. |
| Truncation cuts mid-sentence in an awkward place | `TextOverflow.ellipsis` adds "…" which is universally understood. Could upgrade to fade-out text instead of ellipsis later (e.g. `ShaderMask`) but it's a v2 polish. |
| Very tall devices (tablets / foldables) waste vertical room with `maxLines: 7` | Acceptable for v1. If we ship to tablets, switch to a height-based clip with `LayoutBuilder` measuring available space. |
| Users on very short phones (< 5") might still see truncation on short summaries | The `Expanded` around the summary means truncation kicks in based on *actual* height, not just line count, so the source row stays visible. |
| Headline at 4 lines + 7-line summary = a lot of card real-estate eaten by text | Source row sits with `Spacer`-equivalent (the `Expanded` summary). On most stories the summary is ~5-6 lines and there's natural breathing room. |

---

## 7. Out of scope

- Inline expand-on-tap (e.g. tap card → summary grows in place). Adds animation complexity and the detail screen already does this job better.
- Different `maxLines` per device size class. Worth doing later if we add tablet support.
- Smart truncation that ends at sentence boundaries. Pure cosmetic; ellipsis on a clause is fine.
- Showing a "Continue reading →" inline label inside the fade region. Adds visual noise; the action bar already has the CTA.

---

## SESSION_ID (for /ccg:execute use)
- CODEX_SESSION: (skipped — wrapper not installed)
- GEMINI_SESSION: (skipped — wrapper not installed)
