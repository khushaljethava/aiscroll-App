# Brevio — Visual Foundation Design

- **Date:** 2026-05-31
- **Status:** Approved (design); pending spec review
- **Scope:** Sub-project 1 of 5 in the whole-app UI/UX redesign program
- **Author:** Design brainstorming session (Claude + khushaljethava)

---

## 1. Context & problem

`aiscroll` is a mature Flutter app — "Learn AI in seconds" — with a thoughtful
editorial design system already in place (Newsreader serif + Inter, tokenized
colors/spacing/radii/motion, full dark + light themes, a `context.sem`
semantic-color extension). The foundation is strong, but it is **applied
inconsistently**, which is the real source of the "not user-friendly" feeling:

1. **Three brand identities ship at once.** User-facing strings contain
   `aiscroll` (pubspec), `AIScroll` + `https://aiscroll.app` (referral share
   text), and `60 Second AI` (Welcome screen, push-notification copy, Settings
   deep-link instructions). This is a first-impression credibility problem.
2. **The type system is bypassed.** Key screens hardcode
   `TextStyle(fontSize: …)` instead of the carefully built `textTheme` tokens —
   e.g. the Welcome title, the Profile XP-card title, the level pill, and the
   stat values. The app's best asset (editorial typography) is not actually
   used on its most important screens.
3. **Two competing action colors.** Buttons use indigo (`primary #4F46E5`) via
   the theme, but CTAs in Profile (sign-in, level pill, streak-freeze, redeem)
   use amber (`ctaAmber #F59E0B`). The app reads like two designs stitched
   together.
4. **Tokens exist but literals are used anyway.** Widgets hardcode
   `BorderRadius.circular(999/10/12/20)` and ad-hoc `SizedBox` gaps instead of
   `AppRadius.*` / `AppSpacing.*`, and read color from `AppColors.*` directly
   instead of `colorScheme` / `context.sem` — which is why theming drifts in
   light mode.
5. **Inconsistent primitives.** Empty states are sometimes `AppEmptyState` and
   sometimes raw `Text` (Tracks); buttons are hand-rolled per screen; loading
   is bare spinners; pills/badges are built three different ways.

## 2. Direction (locked decisions)

| Decision | Choice |
| --- | --- |
| Overall mood | **Refined editorial** — evolve the existing premium dark, serif-headline, ink-black look; cleaner and more consistent, not a new aesthetic. |
| Brand name | **Brevio** (coined, from "brevity"). |
| Tagline | **"Learn AI Daily, in Seconds."** |
| Store title / subtitle | `Brevio: Learn AI Daily` / `AI news & 60-sec lessons` (keywords early per ASO best practice). |
| Brand / action color | **Warm coral** — new primary, replacing indigo as the action color. |

> **Pre-launch to-do (not blocking design):** verify `brevio` domain
> availability and trademark/App-Store-ID clearance before shipping the rename.

## 3. Goals & non-goals

**Goals**
- One brand, one action color, one type system — applied everywhere.
- All color sourced from `Theme.of(context).colorScheme` + `context.sem`; no
  direct `AppColors.*` in feature widgets.
- All text from `textTheme`; no ad-hoc `TextStyle(fontSize: …)`.
- All radii/spacing from `AppRadius` / `AppSpacing` tokens.
- A small, documented set of shared primitives (button, chip/badge, empty
  state, skeleton loader) used by every screen.
- Accessibility floor: 44px tap targets, semantic labels, WCAG AA contrast.

**Non-goals (handled in later sub-projects)**
- Per-screen redesign of News, Learn, Saved, Profile, Onboarding.
- Changing navigation structure or feature behavior.
- New gamification mechanics.

## 4. Design

### A. Brand rollout
- Introduce a **`Brevio` wordmark set in Newsreader serif** (the brand itself
  becomes editorial). Splash and Welcome lead with the wordmark; **retire the
  `🤖` emoji** placeholder.
- Replace **every** occurrence of `aiscroll` / `AIScroll` / `60 Second AI` in
  user-facing strings, push-notification copy, Settings deep-link instructions,
  and the referral share text + URL.
- Update `pubspec.yaml` description and the store title/subtitle copy.
- Centralize brand strings (name, tagline, share URL) in one constants file so
  this never fragments again.

### B. Color system — evolve, don't replace
Keep the ink/paper editorial palette (`inkBlack`, `inkSurface`, `inkSurface2`,
`paper`, `paperMuted`, hairlines). Changes:

1. **New primary = warm coral.** Coral becomes the single brand/action color:
   primary buttons, links, focus rings, selected states, progress accents that
   are not gamification.
   - Starting brand hue: `#FF5A4D` (illustrative/accent use).
   - Button-fill variant must pass **WCAG AA** with its label text. Because
     `#FF5A4D` + white is only ~2.6:1, primary buttons use **either** a
     darkened coral fill (`~#ED4435`) with white text **or** the coral fill
     with near-black ink text — whichever validates ≥4.5:1 (≥3:1 for large
     bold). Final values chosen with a contrast checker during implementation.
   - Indigo `#4F46E5` is **retired** as the action color (kept only, if needed,
     as a minor illustrative accent).

2. **Separate coral from the status reds (first-class requirement).** Coral
   occupies the warm red-orange slot, so the danger/advanced reds must move to a
   deeper, cooler crimson so "error" and "advanced" never read as "brand."
   - `error`: retune from `#EF4444` → starting `#C81E3A` (deeper, cooler).
   - Difficulty `advanced`: retune from `#EF4444` → starting `#B0182F`.
   - Requirement: brand coral vs. error/advanced must be visually distinct
     (clear hue + lightness separation) and each must pass contrast on its
     surfaces. Validate during implementation.

3. **Lock semantic roles** (and enforce via `context.sem`):
   - Scaffolds: `inkBlack` (dark) / `paper` (light).
   - Cards/surfaces: `sem.sectionSurface`; dividers: `sem.hairline`.
   - Brand/action: coral.
   - Gamification only: `xpGold #FBBF24`, `streakOrange #F97316`.
   - Difficulty: beginner green / intermediate amber / advanced crimson.
   - Category accents: **News only** (unchanged map).

4. **Sourcing mandate:** feature widgets read color from `colorScheme` /
   `context.sem`. Direct `AppColors.*` references in feature code are migrated.

### C. Typography — enforce the existing system
- **Ban** ad-hoc `TextStyle(fontSize: …)` in feature widgets.
- Documented mapping (all from `textTheme`):
  - Brand wordmark / hero → `displaySmall` / `headlineMedium` (Newsreader).
  - Screen/app-bar title → `headlineSmall` or `titleLarge`.
  - Card title → `titleMedium`; sub-title → `titleSmall`.
  - Body → `bodyLarge` / `bodyMedium`; captions/meta → `labelMedium` /
    `bodySmall`.
  - All-caps section labels → `labelMedium` with letter-spacing.
- Migrate the known offenders: Welcome title/tagline, XP-card title, level
  pill, stat values, bespoke pill labels.

### D. Components — standardize the primitives
- **Buttons:** rely on the themed `Elevated`/`Outlined`/`Text` button styles,
  plus **one** shared pill CTA widget. Remove hand-rolled buttons
  (`_SignInButton`, "Watch ad", "Redeem") and their bespoke radii/padding.
- **Chip / badge:** one shared component for the level pill, "EARNED" tag, and
  status dots, replacing the three current hand-built variants.
- **Empty states:** `AppEmptyState` everywhere (migrate Tracks' raw `Text`),
  with warmer, more guiding copy and an optional action.
- **Loading:** one shimmer/skeleton component for list screens (News, Tracks,
  Saved) replacing bare `CircularProgressIndicator`s.
- **Tokens, not literals:** replace `BorderRadius.circular(999/10/12/20)` →
  `AppRadius.*`; ad-hoc `SizedBox` gaps → `AppSpacing.*`.

### E. Motion & accessibility
- Use `AppMotion` tokens (`fast/base/slow`, `emphasized/standard`) consistently.
- Adopt Welcome's staggered fade-in as the standard list/entrance pattern.
- Accessibility floor: 44px min tap targets, semantic labels on all icon-only
  buttons, muted-text contrast at AA, and a dynamic-type (text scaling) sanity
  pass on the primary screens.

## 5. Approach & sequencing
This spec is **sub-project 1** of a foundation-first program. The full program:

1. **Visual foundation (this spec)** — brand, color, type, components, motion.
2. Onboarding & first-run.
3. News (default tab).
4. Learn (tracks → scroll → quiz).
5. Saved + Profile.

Each later sub-project gets its own spec → plan → implementation cycle and
inherits the tokens/primitives defined here. Implementation of this foundation
proceeds primitive-first (tokens & shared widgets), then a mechanical migration
of feature widgets to the tokens/primitives, validated screen by screen.

## 6. Acceptance criteria
- [ ] No user-facing string references `aiscroll`, `AIScroll`, or `60 Second AI`;
      all read `Brevio`. Brand strings centralized.
- [ ] `Brevio` wordmark (Newsreader) on Splash + Welcome; `🤖` placeholder gone.
- [ ] Coral is the only action color; indigo no longer used for actions.
- [ ] Error/advanced reds visually distinct from coral; all three pass contrast.
- [ ] Primary button text passes WCAG AA against its fill.
- [ ] No `TextStyle(fontSize:)` in feature widgets; all text via `textTheme`.
- [ ] No direct `AppColors.*` in feature widgets; color via `colorScheme`/`sem`.
- [ ] No raw radius/spacing literals where a token exists.
- [ ] `AppEmptyState` + shared skeleton loader used across list screens.
- [ ] Shared button + chip/badge primitives replace per-screen variants.
- [ ] Icon-only buttons have semantic labels; tap targets ≥ 44px.

## 7. Key references
- Theme: `lib/core/theme/app_theme.dart`, `app_colors.dart`,
  `app_semantic_colors.dart`, `app_spacing.dart`
- Shared widgets: `lib/shared/widgets/app_empty_state.dart`,
  `app_section_card.dart`, `app_tag_chip.dart`, `search_field.dart`
- Offending screens (examples): `lib/features/onboarding/screens/welcome_screen.dart`,
  `lib/features/profile/screens/profile_screen.dart`,
  `lib/features/tracks/screens/tracks_screen.dart`
- Brand strings to migrate: `pubspec.yaml`, `welcome_screen.dart`,
  `profile_screen.dart` (push copy, Settings text, referral share text + URL)
