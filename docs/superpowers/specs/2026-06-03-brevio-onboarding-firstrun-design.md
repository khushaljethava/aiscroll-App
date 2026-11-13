# Brevio — Onboarding & First-Run Design

- **Date:** 2026-06-03
- **Status:** Approved (design); pending spec review
- **Scope:** Sub-project 2 of 5 in the whole-app UI/UX redesign program
- **Author:** Design brainstorming session (Claude + khushaljethava)
- **Inherits:** `2026-05-31-brevio-visual-foundation-design.md` (tokens, primitives, coral action color)

---

## 1. Context & problem

Sub-project 1 (visual foundation) established one brand, one warm-coral action
color (`#FF5A4D` via `ColorScheme.primary`), enforced `textTheme` typography,
and a set of shared primitives (`AppButton`, `AppBadge`, `AppEmptyState`,
`AppSkeleton`, `BrandWordmark`). It applied them to Splash and Welcome.

The first-run **funnel** was deliberately left for this sub-project, and it
shows: the experience is split across two visual eras.

- **On the foundation:** `splash_screen.dart`, `welcome_screen.dart` (Brevio
  serif wordmark, coral via `cs.primary`, `textTheme`, shared `AuthButton`).
- **Still on the old look:** `persona_screen.dart`, `knowledge_level_screen.dart`,
  `topic_picker_screen.dart`, `daily_goal_screen.dart`, the step bar in
  `onboarding_shell.dart`, and the auth forms `login_screen.dart` /
  `register_screen.dart`. These use **amber `AppColors.ctaAmber`** as the action
  color (contradicting "coral is the single action color"), raw
  `TextStyle(fontSize:)` instead of `textTheme`, hardcoded `AppColors.*` instead
  of `colorScheme`/`context.sem`, literal `BorderRadius.circular()` instead of
  `AppRadius`, and hand-rolled selection cards / buttons.

The foundation's intended `fontSize:` / `AppColors.*` guard tests (Task 9 of the
foundation plan) were **never committed** — only the legacy-brand-string guard
exists in `test/foundation/consistency_guard_test.dart`. That is why these
offenders never failed CI.

Offender map (counts of `AppColors.` / `fontSize:` / radius-literal / `ctaAmber`):

| File | AppColors | fontSize | radius lit | ctaAmber |
| --- | --- | --- | --- | --- |
| daily_goal_screen.dart | 19 | 8 | 3 | 7 |
| knowledge_level_screen.dart | 11 | 7 | 1 | 4 |
| topic_picker_screen.dart | 12 | 5 | 2 | 3 |
| persona_screen.dart | 10 | 5 | 1 | 3 |
| login_screen.dart | 10 | 7 | 3 | 0 |
| register_screen.dart | 10 | 7 | 3 | 0 |
| onboarding_shell.dart | 2 | 0 | 1 | 1 |
| auth_button.dart | 0 | 0 | 1 | 0 |
| splash_screen.dart / welcome_screen.dart | 0 | 0 | 0 | 0 |

## 2. Direction (locked decisions)

| Decision | Choice |
| --- | --- |
| Scope | **Migration + light UX polish.** Repaint the funnel to the foundation and make targeted UX improvements. **No change to step order or auth logic.** |
| Aesthetic | **Editorial.** Serif (Newsreader) headlines via `textTheme`, restrained coral selection cards, **no emoji**. Matches the Brevio wordmark; reads premium/magazine. |
| Emoji replacement | **Typographic + coral accents.** Where emoji currently carry the screen (Knowledge level, Daily goal), replace with large serif labels/numerals and coral accents — no icon set introduced. |
| Finish beat | **Add a "You're all set" confirmation screen** after Daily goal, before News. |

## 3. Goals & non-goals

**Goals**
- The entire first-run funnel uses coral as the only action color (no
  `ctaAmber` in onboarding).
- All onboarding text from `textTheme`; no ad-hoc `TextStyle(fontSize:)`.
- All onboarding color from `colorScheme` / `context.sem`; no direct
  `AppColors.*` in onboarding feature widgets.
- Radii/spacing from `AppRadius` / `AppSpacing` tokens.
- Hand-rolled selection cards replaced by one shared `AppOptionCard`; CTAs use
  the shared `AppButton`.
- A short editorial payoff at the end of the funnel.
- A guard test prevents `fontSize:` / `AppColors.*` from regressing in
  onboarding.

**Non-goals (handled in later sub-projects)**
- Changing navigation structure, the set/order of personalization steps, or auth
  behavior (Google / email / guest paths all unchanged).
- Redesign of News, Learn, Saved, Profile (sub-projects 3–5).
- New personalization questions or gamification mechanics.

## 4. Design

### A. New shared primitive — `AppOptionCard`
`lib/shared/widgets/app_option_card.dart`. The single selectable card, replacing
the bespoke `_PersonaCard` (persona) and `_GoalCard` (daily goal).

- Props: `title` (String), `subtitle` (String?), `leading` (Widget?),
  `trailing` (Widget?), `selected` (bool), `onTap` (VoidCallback).
- Selected: `cs.primary`-tinted fill (`withValues(alpha: 0.10)`), 2px
  `cs.primary` border, trailing `Icons.check_circle_rounded` in `cs.primary`.
- Unselected: `context.sem.sectionSurface` fill, 1px hairline border.
- Tokens: `AppRadius.lg` corners, `AppSpacing` padding/gaps; text via
  `textTheme` (`titleMedium` title, `bodySmall`/`bodyMedium` subtitle on
  `onSurfaceVariant`).
- Min tap target ≥ 48px.

### B. Per-screen changes
All headlines → serif `textTheme` (`headlineMedium` or `headlineSmall`,
Newsreader). Subtitles → `bodyMedium` on `cs.onSurfaceVariant`. All entrance
animations keep the existing `flutter_animate` stagger.

- **Persona** (`persona_screen.dart`): cards → `AppOptionCard` (no emoji);
  headline/subtitle to `textTheme`; remove all `AppColors.*`.
- **Knowledge level** (`knowledge_level_screen.dart`): drop the 64px emoji; the
  hero becomes the big **serif level word** (e.g. "A Little") via `displaySmall`
  plus its description; slider recolored to `cs.primary` (coral) via
  `SliderThemeData`; step labels and Continue button via `textTheme`/`AppButton`.
- **Topics** (`topic_picker_screen.dart`): selection chips route through the
  existing `AppTagChip`, selected state recolored to `cs.primary`; headline and
  Continue button migrated.
- **Daily goal** (`daily_goal_screen.dart`): drop emoji; each card leads with the
  serif numeral (**5 / 10 / 15**, `headlineSmall`) and a label pill rendered with
  `AppBadge`; cards → `AppOptionCard`; Finish button → `AppButton(loading:)`.
- **Login / Register** (`login_screen.dart`, `register_screen.dart`):
  `AppColors.*` → `colorScheme`/`context.sem`; `fontSize:` → `textTheme`; radius
  literals → `AppRadius`; keep `AuthButton`. Behavior unchanged.
- **Step bar** (`onboarding_shell.dart`): filled segments use `cs.primary`
  (coral) instead of `AppColors.ctaAmber`; unfilled use `context.sem.hairline`;
  radius via `AppRadius`.
- **`auth_button.dart`**: `BorderRadius.circular(14)` → `AppRadius` token
  (pill/lg as appropriate).
- **Welcome** (`welcome_screen.dart`, minor): the "Create account" `AuthButton`
  currently sets `foregroundColor: cs.onSurface` on a `cs.primary` fill — change
  to `cs.onPrimary` (the AA-validated `onCoral` ink) for correct contrast. No
  other changes.

### C. Finish beat — "You're all set"
- New route `AppRoutes.onboardingDone = '/onboarding/done'`, registered as a
  child of the onboarding shell (no step bar — it is past the funnel). New
  screen `lib/features/onboarding/screens/onboarding_done_screen.dart`.
- Flow change (logic-preserving): Daily-goal "Finish" still calls
  `onboardingProvider.notifier.completeOnboarding(stayGuest:)`, then
  `context.go(AppRoutes.onboardingDone)` instead of going straight to News. The
  done screen shows an editorial confirmation — "You're all set" with the
  persona-aware line — summarizing the chosen knowledge level, topic count, and
  daily goal (read from `onboardingProvider`), and a single coral `AppButton`
  ("Start learning") → `context.go(AppRoutes.news)`.
- Because completion is persisted before the done screen, the router's
  `onboarded` guard already treats the user as onboarded; the done screen is
  reachable only as the explicit post-finish destination and routes forward on
  tap. (Splash/guard behavior is otherwise untouched.)

## 5. Regression net (guards & tests)
- Extend `test/foundation/consistency_guard_test.dart` with the two foundation
  guards, scoped to also cover `lib/features/onboarding`:
  - no `TextStyle(fontSize:)` in onboarding feature widgets;
  - no direct `AppColors.*` in onboarding feature widgets.
  (Theme/token files under `lib/core/theme` keep their `AppColors.*` — the guard
  only scans feature dirs, matching the foundation's approach.)
- New widget tests:
  - `test/widgets/app_option_card_test.dart` — renders title/subtitle, fires
    `onTap`, reflects `selected`.
  - `test/widgets/onboarding_done_test.dart` — renders the summary and the CTA
    navigates to News.
- `flutter analyze` clean; full `flutter test` green.

## 6. Acceptance criteria
- [ ] No `AppColors.ctaAmber` (or any `ctaAmber`) anywhere in
      `lib/features/onboarding`; coral is the only action color in the funnel.
- [ ] No `TextStyle(fontSize:)` in onboarding feature widgets; all text via
      `textTheme` (serif headlines on step screens).
- [ ] No direct `AppColors.*` in onboarding feature widgets; color via
      `colorScheme` / `context.sem`.
- [ ] No raw radius/spacing literals where an `AppRadius`/`AppSpacing` token
      exists, across the migrated files.
- [ ] Persona and Daily-goal use the shared `AppOptionCard`; all funnel CTAs use
      `AppButton`; topics use `AppTagChip`.
- [ ] No emoji on Persona / Knowledge level / Daily goal; their visual weight is
      carried by serif typography + coral accents.
- [ ] A "You're all set" screen appears after Daily-goal Finish and routes to
      News on tap; `completeOnboarding` is still called exactly once.
- [ ] Login / Register migrated to tokens/`textTheme`; auth behavior unchanged.
- [ ] Step bar and `auth_button` use coral + tokens.
- [ ] `consistency_guard_test.dart` enforces the `fontSize:`/`AppColors.*` rules
      over onboarding; new widget tests pass; `flutter analyze`/`flutter test`
      green.

## 7. Key references
- Foundation spec: `docs/superpowers/specs/2026-05-31-brevio-visual-foundation-design.md`
- Tokens: `lib/core/theme/app_colors.dart`, `app_semantic_colors.dart`,
  `app_spacing.dart`, `app_theme.dart`
- Primitives: `lib/shared/widgets/app_button.dart`, `app_badge.dart`,
  `app_tag_chip.dart`, `brand_wordmark.dart`
- Screens to migrate: `lib/features/onboarding/screens/{persona,knowledge_level,
  topic_picker,daily_goal,login,register}_screen.dart`,
  `lib/features/onboarding/onboarding_shell.dart`,
  `lib/features/onboarding/widgets/auth_button.dart`
- New: `lib/shared/widgets/app_option_card.dart`,
  `lib/features/onboarding/screens/onboarding_done_screen.dart`,
  route `AppRoutes.onboardingDone` in `lib/core/router/app_router.dart`
- State: `lib/features/onboarding/providers/onboarding_provider.dart`
  (`completeOnboarding`, `OnboardingState` — read for the done-screen summary)
