# Brevio Onboarding & First-Run Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the Brevio first-run funnel (persona → level → topics → goal, plus login/register, the step bar, and a new finish beat) onto the visual foundation — coral action color, editorial serif typography, shared primitives, tokens — without changing step order or auth logic.

**Architecture:** Primitive-first, then mechanical screen migration. Add one shared `AppOptionCard`, migrate each funnel screen to it + `AppButton` + `textTheme` + `colorScheme`/`context.sem`/`AppRadius`, add a "You're all set" screen, then lock the rules with a guard test. Screens are validated by `flutter analyze` + existing tests + the final guard; the two new widgets get dedicated tests.

**Tech Stack:** Flutter, Dart, `flutter_riverpod`, `go_router`, `flutter_animate`, `google_fonts`, `flutter_test`. No new packages.

**Spec:** `docs/superpowers/specs/2026-06-03-brevio-onboarding-firstrun-design.md`

---

## File structure

**Create:**
- `lib/shared/widgets/app_option_card.dart` — shared selectable card (persona, goal).
- `lib/features/onboarding/screens/onboarding_done_screen.dart` — "You're all set" finish beat.
- `test/widgets/app_option_card_test.dart`
- `test/widgets/onboarding_done_test.dart`

**Modify:**
- `lib/features/onboarding/screens/persona_screen.dart`
- `lib/features/onboarding/screens/knowledge_level_screen.dart`
- `lib/features/onboarding/screens/topic_picker_screen.dart`
- `lib/features/onboarding/screens/daily_goal_screen.dart`
- `lib/features/onboarding/screens/login_screen.dart`
- `lib/features/onboarding/screens/register_screen.dart`
- `lib/features/onboarding/onboarding_shell.dart` — step bar coral + tokens.
- `lib/features/onboarding/widgets/auth_button.dart` — radius token.
- `lib/features/onboarding/screens/welcome_screen.dart` — `onPrimary` button contrast fix.
- `lib/core/router/app_router.dart` — `onboardingDone` route + allowlist.
- `test/foundation/consistency_guard_test.dart` — add `fontSize:` / `AppColors.*` guards over onboarding.

---

## Color/token mapping (apply consistently)

| Old | New |
| --- | --- |
| `AppColors.textPrimary` | `cs.onSurface` |
| `AppColors.textSecondary` | `cs.onSurfaceVariant` |
| `AppColors.ctaAmber` (action) | `cs.primary` |
| `AppColors.inkBlack` (text on amber fill) | `cs.onPrimary` |
| `AppColors.inkSurface` | `context.sem.sectionSurface` |
| `AppColors.inkSurface2` | `cs.surfaceContainerHighest` |
| `AppColors.inkHairline` | `context.sem.hairline` |
| `AppColors.accent` | `context.sem.success` |
| `TextStyle(fontSize: 28, fontWeight: bold)` headline | `tt.headlineSmall` (serif Newsreader) |
| `TextStyle(fontSize: 24, bold)` | `tt.headlineSmall` / `tt.titleLarge` |
| `TextStyle(fontSize: 16-18)` body/title | `tt.titleMedium` / `tt.bodyLarge` |
| `TextStyle(fontSize: 11-15)` meta | `tt.bodyMedium` / `tt.bodySmall` / `tt.labelMedium` |
| `BorderRadius.circular(16/14/24)` | `AppRadius.lg` / `AppRadius.md` / `AppRadius.chip` |

Where `cs = Theme.of(context).colorScheme` and `tt = Theme.of(context).textTheme`.

---

## Task 1: `AppOptionCard` shared primitive

**Files:**
- Create: `lib/shared/widgets/app_option_card.dart`
- Test: `test/widgets/app_option_card_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/app_option_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aiscroll/shared/widgets/app_option_card.dart';

void main() {
  testWidgets('AppOptionCard shows title + subtitle and fires onTap',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppOptionCard(
          title: 'Student',
          subtitle: 'Building AI skills while I study',
          selected: false,
          onTap: () => tapped = true,
        ),
      ),
    ));
    expect(find.text('Student'), findsOneWidget);
    expect(find.text('Building AI skills while I study'), findsOneWidget);
    await tester.tap(find.byType(AppOptionCard));
    expect(tapped, isTrue);
  });

  testWidgets('AppOptionCard shows a check when selected', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppOptionCard(
          title: 'Student',
          selected: true,
          onTap: () {},
        ),
      ),
    ));
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/app_option_card_test.dart`
Expected: FAIL — `AppOptionCard` not defined / target of URI doesn't exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/shared/widgets/app_option_card.dart
import 'package:flutter/material.dart';

import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_spacing.dart';

/// The single selectable option card for the onboarding funnel (persona,
/// daily goal). Coral selection via [ColorScheme.primary]; replaces the
/// per-screen hand-rolled selection cards.
class AppOptionCard extends StatelessWidget {
  const AppOptionCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;

  /// Optional trailing widget. When null and [selected], a coral check is shown.
  final Widget? trailing;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sem = context.sem;
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: selected
                ? cs.primary.withValues(alpha: 0.10)
                : sem.sectionSurface,
            borderRadius: AppRadius.card,
            border: Border.all(
              color: selected ? cs.primary : sem.hairline,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppSpacing.lg),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: tt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle!,
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (selected) ...[
                const SizedBox(width: AppSpacing.md),
                Icon(Icons.check_circle_rounded, color: cs.primary, size: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/app_option_card_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/app_option_card.dart test/widgets/app_option_card_test.dart
git commit -m "feat(ui): shared AppOptionCard selectable card primitive"
```

---

## Task 2: Migrate Persona screen

**Files:**
- Modify: `lib/features/onboarding/screens/persona_screen.dart`

- [ ] **Step 1: Replace imports**

Replace:
```dart
import '../../../core/theme/app_colors.dart';
```
with:
```dart
import '../../../shared/widgets/app_option_card.dart';
```
(Keep the existing `material`, `flutter_animate`, `flutter_riverpod`, `go_router`, `app_router.dart`, and `onboarding_provider.dart` imports.)

- [ ] **Step 2: Drop the emoji from the data model**

In `_PersonaOption`, remove the `emoji` field and its constructor param. Update the three `_personas` entries to drop `emoji:`. Result:
```dart
  static const _personas = [
    _PersonaOption(
      id: 'student',
      title: 'Student',
      subtitle: "I'm studying and want to build AI skills",
    ),
    _PersonaOption(
      id: 'professional',
      title: 'Professional',
      subtitle: 'I use AI at work or want to stay relevant',
    ),
    _PersonaOption(
      id: 'curious',
      title: 'Just curious',
      subtitle: 'I just want to understand AI basics',
    ),
  ];
```
And:
```dart
class _PersonaOption {
  const _PersonaOption({
    required this.id,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final String title;
  final String subtitle;
}
```

- [ ] **Step 3: Replace headline + subtitle with `textTheme`**

Add at the top of `build`:
```dart
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
```
Replace the `Text('Who are you?', ...)` block with:
```dart
              Text(
                'Who are you?',
                style: tt.headlineSmall,
              ).animate().fadeIn(duration: 400.ms).slideY(
                    begin: -0.2,
                    end: 0,
                    duration: 400.ms,
                    curve: Curves.easeOut,
                  ),
```
Replace the `Text('Personalize your learning path', ...)` block with:
```dart
              Text(
                'Personalize your learning path',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
```

- [ ] **Step 4: Replace `_PersonaCard` usage with `AppOptionCard`**

In the `List.generate` body, replace the `_PersonaCard(...)` with:
```dart
                  child: AppOptionCard(
                    title: option.title,
                    subtitle: option.subtitle,
                    selected: isSelected,
                    onTap: () {
                      ref
                          .read(onboardingProvider.notifier)
                          .setPersona(option.id);
                      context.go(AppRoutes.onboardingLevel);
                    },
                  ),
```
Delete the entire `_PersonaCard` class (no longer used).

- [ ] **Step 5: Verify**

Run: `flutter analyze lib/features/onboarding/screens/persona_screen.dart`
Expected: no errors, no unused-import / unused-element warnings.

- [ ] **Step 6: Commit**

```bash
git add lib/features/onboarding/screens/persona_screen.dart
git commit -m "refactor(onboarding): persona screen on AppOptionCard + textTheme, no emoji"
```

---

## Task 3: Migrate Knowledge-level screen

**Files:**
- Modify: `lib/features/onboarding/screens/knowledge_level_screen.dart`

- [ ] **Step 1: Replace imports**

Replace `import '../../../core/theme/app_colors.dart';` with:
```dart
import '../../../shared/widgets/app_button.dart';
```

- [ ] **Step 2: Remove the emoji constant**

Delete the `_emojis` static list. Keep `_labels` and `_descriptions`.

- [ ] **Step 3: Add theme locals + migrate headline/subtitle**

At the top of `build` add:
```dart
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
```
Replace the `Text('What do you know\nabout AI?', ...)`:
```dart
              Text(
                'What do you know\nabout AI?',
                style: tt.headlineSmall?.copyWith(height: 1.3),
              ).animate().fadeIn(duration: 400.ms).slideY(
                    begin: -0.2,
                    end: 0,
                    duration: 400.ms,
                    curve: Curves.easeOut,
                  ),
```
Replace `Text('Be honest — we tailor your feed accordingly', ...)`:
```dart
              Text(
                'Be honest — we tailor your feed accordingly',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
```

- [ ] **Step 4: Make the serif level word the hero (drop emoji)**

Replace the `AnimatedSwitcher` `Column` children (currently emoji + label + description) with:
```dart
                    children: [
                      Text(
                        _labels[stepIndex],
                        textAlign: TextAlign.center,
                        style: tt.displaySmall?.copyWith(color: cs.primary),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _descriptions[stepIndex],
                        textAlign: TextAlign.center,
                        style:
                            tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
```

- [ ] **Step 5: Recolor the slider + step labels**

Change `_StyledSlider.build` to source colors from the scheme:
```dart
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SliderTheme(
      data: SliderThemeData(
        activeTrackColor: cs.primary,
        inactiveTrackColor: cs.surfaceContainerHighest,
        thumbColor: cs.primary,
        overlayColor: cs.primary.withValues(alpha: 0.15),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
        trackHeight: 6,
      ),
      child: Slider(
        value: value,
        min: 0,
        max: 3,
        divisions: 3,
        onChanged: onChanged,
      ),
    );
  }
```
Replace the step-label `Text` style (inside the `_labels.map` in `build`, where `tt`/`cs` are in scope):
```dart
                        (l) => Text(
                          l,
                          style: tt.labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
```

- [ ] **Step 6: Replace the Continue button with `AppButton`**

Replace the `SizedBox(width: double.infinity, child: ElevatedButton(...))` Continue block with:
```dart
              AppButton(
                label: 'Continue',
                onPressed: () => context.go(AppRoutes.onboardingTopics),
              ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
```

- [ ] **Step 7: Verify**

Run: `flutter analyze lib/features/onboarding/screens/knowledge_level_screen.dart`
Expected: no errors/warnings.

- [ ] **Step 8: Commit**

```bash
git add lib/features/onboarding/screens/knowledge_level_screen.dart
git commit -m "refactor(onboarding): knowledge-level serif hero + coral slider, AppButton"
```

---

## Task 4: Migrate Topics screen

**Files:**
- Modify: `lib/features/onboarding/screens/topic_picker_screen.dart`

- [ ] **Step 1: Replace imports**

Replace `import '../../../core/theme/app_colors.dart';` with:
```dart
import '../../../core/theme/app_semantic_colors.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_tag_chip.dart';
```

- [ ] **Step 2: Drop emoji from the data model**

Remove the `emoji` field from `_TopicOption` and its constructor param; drop `emoji:` from every `_topics` entry. Result model:
```dart
class _TopicOption {
  const _TopicOption({required this.id, required this.label});
  final String id;
  final String label;
}
```

- [ ] **Step 3: Theme locals + headline/subtitle**

Top of `build`:
```dart
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sem = context.sem;
```
Replace `Text('Pick topics you\ncare about', ...)`:
```dart
              Text(
                'Pick topics you\ncare about',
                style: tt.headlineSmall?.copyWith(height: 1.3),
              ).animate().fadeIn(duration: 400.ms).slideY(
                    begin: -0.2,
                    end: 0,
                    duration: 400.ms,
                    curve: Curves.easeOut,
                  ),
```
Replace the count / “choose at least 3” `Text`:
```dart
              Text(
                hasEnough
                    ? '${selectedTopics.length} selected — nice!'
                    : 'Choose at least 3',
                style: tt.bodyMedium?.copyWith(
                  color: hasEnough ? sem.success : cs.onSurfaceVariant,
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
```

- [ ] **Step 4: Replace `_TopicChip` with `AppTagChip`**

In the `Wrap` `List.generate`, replace `_TopicChip(...)` with:
```dart
                      return AppTagChip(
                        label: topic.label,
                        accent: cs.primary,
                        emphasised: isSelected,
                        onTap: () {
                          ref
                              .read(onboardingProvider.notifier)
                              .toggleTopic(topic.id);
                        },
                      )
```
Delete the `_TopicChip` class.

- [ ] **Step 5: Replace the Continue button with `AppButton`**

Replace the `SizedBox(... ElevatedButton ...)` Continue block with:
```dart
              AppButton(
                label: 'Continue',
                onPressed: hasEnough
                    ? () => context.go(AppRoutes.onboardingGoal)
                    : null,
              ).animate().fadeIn(delay: 700.ms, duration: 400.ms),
```

- [ ] **Step 6: Verify**

Run: `flutter analyze lib/features/onboarding/screens/topic_picker_screen.dart`
Expected: no errors/warnings.

- [ ] **Step 7: Commit**

```bash
git add lib/features/onboarding/screens/topic_picker_screen.dart
git commit -m "refactor(onboarding): topics on AppTagChip (coral) + AppButton, no emoji"
```

---

## Task 5: Migrate Daily-goal screen

**Files:**
- Modify: `lib/features/onboarding/screens/daily_goal_screen.dart`

- [ ] **Step 1: Replace imports**

Replace `import '../../../core/theme/app_colors.dart';` with:
```dart
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_option_card.dart';
```

- [ ] **Step 2: Drop emoji from the data model**

Remove the `emoji` field from `_GoalOption` and its param; drop `emoji:` from each `_goals` entry. Result model:
```dart
class _GoalOption {
  const _GoalOption({
    required this.cards,
    required this.label,
    required this.duration,
    required this.description,
  });
  final int cards;
  final String label;
  final String duration;
  final String description;
}
```

- [ ] **Step 3: Change finish to route to the done screen**

Replace `_finishOnboarding`'s `context.go(AppRoutes.news);` line with:
```dart
    context.go(AppRoutes.onboardingDone);
```
(Keep the `completeOnboarding(stayGuest: user.isGuest)` call exactly as-is — completion still happens here, once.)

- [ ] **Step 4: Theme locals + headline/subtitle**

Top of `build`:
```dart
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
```
Replace `Text('Set your daily goal', ...)`:
```dart
              Text(
                'Set your daily goal',
                style: tt.headlineSmall,
              ).animate().fadeIn(duration: 400.ms).slideY(
                    begin: -0.2,
                    end: 0,
                    duration: 400.ms,
                    curve: Curves.easeOut,
                  ),
```
Replace `Text('How many cards a day works for you?', ...)`:
```dart
              Text(
                'How many cards a day works for you?',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
```

- [ ] **Step 5: Replace `_GoalCard` usage + class with `AppOptionCard`**

In the `List.generate`, replace `_GoalCard(...)` with an `AppOptionCard` whose leading is the serif numeral and whose subtitle carries duration + description:
```dart
                  child: AppOptionCard(
                    selected: isSelected,
                    onTap: () {
                      ref
                          .read(onboardingProvider.notifier)
                          .setDailyGoal(goal.cards);
                    },
                    leading: SizedBox(
                      width: 44,
                      child: Text(
                        '${goal.cards}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                    ),
                    title: '${goal.cards} cards/day',
                    subtitle: '${goal.duration} · ${goal.description}',
                    trailing: AppBadge(
                      label: goal.label,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
```
Delete the `_GoalCard` class.

- [ ] **Step 6: Replace the Finish button with `AppButton`**

Replace the `SizedBox(... ElevatedButton ...)` Finish block with:
```dart
              AppButton(
                label: 'Finish',
                loading: _isFinishing,
                onPressed: _isFinishing ? null : _finishOnboarding,
              ).animate().fadeIn(delay: 600.ms, duration: 400.ms),
```

- [ ] **Step 7: Verify**

Run: `flutter analyze lib/features/onboarding/screens/daily_goal_screen.dart`
Expected: no errors. (`AppRoutes.onboardingDone` is added in Task 8; if running this task before Task 8, expect one "undefined getter" error — resolve by doing Task 8. When executing in order, do Task 8 immediately after and analyze together.)

- [ ] **Step 8: Commit**

```bash
git add lib/features/onboarding/screens/daily_goal_screen.dart
git commit -m "refactor(onboarding): daily goal on AppOptionCard + serif numerals, AppButton"
```

---

## Task 6: Step bar, AuthButton radius, Welcome contrast fix

**Files:**
- Modify: `lib/features/onboarding/onboarding_shell.dart`,
  `lib/features/onboarding/widgets/auth_button.dart`,
  `lib/features/onboarding/screens/welcome_screen.dart`

- [ ] **Step 1: Step bar → coral + tokens**

In `onboarding_shell.dart`, replace `import '../../core/theme/app_colors.dart';` with:
```dart
import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_spacing.dart';
```
In `_StepBar.build`, add a theme local and replace the `AnimatedContainer` decoration colors/radius:
```dart
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sem = context.sem;
    return Row(
      children: List.generate(total, (i) {
        final filled = i <= current;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
            child: AnimatedContainer(
              duration: AppMotion.base,
              height: 3,
              decoration: BoxDecoration(
                color: filled ? cs.primary : sem.hairline,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
            ),
          ),
        );
      }),
    );
  }
```

- [ ] **Step 2: AuthButton radius token**

In `auth_button.dart`, add `import '../../../core/theme/app_spacing.dart';` and replace `borderRadius: BorderRadius.circular(14),` with:
```dart
            borderRadius: AppRadius.input,
```

- [ ] **Step 3: Welcome "Create account" contrast fix**

In `welcome_screen.dart`, in the first `AuthButton` (Create account), change:
```dart
                foregroundColor: cs.onSurface,
```
to:
```dart
                foregroundColor: cs.onPrimary,
```

- [ ] **Step 4: Verify**

Run: `flutter analyze lib/features/onboarding/onboarding_shell.dart lib/features/onboarding/widgets/auth_button.dart lib/features/onboarding/screens/welcome_screen.dart`
Expected: no errors/warnings.

- [ ] **Step 5: Commit**

```bash
git add lib/features/onboarding/onboarding_shell.dart lib/features/onboarding/widgets/auth_button.dart lib/features/onboarding/screens/welcome_screen.dart
git commit -m "refactor(onboarding): coral step bar + token radius, fix welcome CTA contrast"
```

---

## Task 7: Migrate Login & Register forms

**Files:**
- Modify: `lib/features/onboarding/screens/login_screen.dart`,
  `lib/features/onboarding/screens/register_screen.dart`

> These are mechanical token swaps; behavior (auth calls, validation, navigation)
> is unchanged. Apply the **Color/token mapping** table above to every
> `AppColors.*`, `fontSize:`, and `BorderRadius.circular()` literal in each file.

- [ ] **Step 1: Baseline + locate offenders**

Run: `flutter analyze lib/features/onboarding/screens/login_screen.dart lib/features/onboarding/screens/register_screen.dart`
(baseline: clean today). Then open both files to locate each `AppColors.*`, `TextStyle(fontSize:)`, and `BorderRadius.circular()`.

- [ ] **Step 2: Swap imports**

In each file, replace `import '../../../core/theme/app_colors.dart';` with `import '../../../core/theme/app_semantic_colors.dart';` (only if a `context.sem` token is used after migration; otherwise remove the import entirely). Add `import '../../../core/theme/app_spacing.dart';` where a radius literal is replaced by `AppRadius`.

- [ ] **Step 3: Apply the mapping**

Add `final cs = Theme.of(context).colorScheme;` and `final tt = Theme.of(context).textTheme;` at the top of each `build` (or sub-widget `build`) that needs them. Replace each occurrence per the mapping table:
- `AppColors.textPrimary` → `cs.onSurface`
- `AppColors.textSecondary` → `cs.onSurfaceVariant`
- `AppColors.inkSurface` → `context.sem.sectionSurface`
- `AppColors.inkSurface2` → `cs.surfaceContainerHighest`
- `AppColors.inkHairline` → `context.sem.hairline`
- `TextStyle(fontSize: 28, fontWeight: FontWeight.bold)` → `tt.headlineSmall`
- field-label / body `TextStyle(fontSize: 14-16)` → `tt.bodyMedium` / `tt.titleSmall`
- `BorderRadius.circular(14)` → `AppRadius.input`; `BorderRadius.circular(12)` → `AppRadius.md`

Keep `AuthButton` usage and any required Google-brand-blue exact color (if present) as-is.

- [ ] **Step 4: Verify**

Run: `flutter analyze lib/features/onboarding/screens/login_screen.dart lib/features/onboarding/screens/register_screen.dart`
Then confirm no offenders remain:
Run: `grep -nE "AppColors\.|fontSize:|BorderRadius.circular" lib/features/onboarding/screens/login_screen.dart lib/features/onboarding/screens/register_screen.dart`
Expected: no matches.

- [ ] **Step 5: Commit**

```bash
git add lib/features/onboarding/screens/login_screen.dart lib/features/onboarding/screens/register_screen.dart
git commit -m "refactor(onboarding): login + register on tokens + textTheme"
```

---

## Task 8: "You're all set" finish screen + route

**Files:**
- Create: `lib/features/onboarding/screens/onboarding_done_screen.dart`
- Modify: `lib/core/router/app_router.dart`
- Test: `test/widgets/onboarding_done_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/onboarding_done_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aiscroll/features/onboarding/screens/onboarding_done_screen.dart';

void main() {
  testWidgets('done screen shows the all-set headline + CTA', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: OnboardingDoneScreen()),
    ));
    expect(find.text("You're all set"), findsOneWidget);
    expect(find.text('Start learning'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/onboarding_done_test.dart`
Expected: FAIL — `OnboardingDoneScreen` not defined.

- [ ] **Step 3: Implement the done screen**

```dart
// lib/features/onboarding/screens/onboarding_done_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../providers/onboarding_provider.dart';

/// Editorial payoff shown after the funnel: confirms the picks and routes to
/// News. [OnboardingNotifier.completeOnboarding] has already run on the
/// daily-goal screen, so this screen only summarizes state and forwards.
class OnboardingDoneScreen extends ConsumerWidget {
  const OnboardingDoneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sem = context.sem;
    final s = ref.watch(onboardingProvider);

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              Text(value,
                  style:
                      tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.editorialGutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                "You're all set",
                textAlign: TextAlign.center,
                style: tt.displaySmall?.copyWith(color: cs.primary),
              ).animate().fadeIn(duration: 400.ms).slideY(
                  begin: 0.15, end: 0, duration: 400.ms, curve: Curves.easeOut),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Your feed is tuned to you. Here’s the plan:',
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
              const SizedBox(height: AppSpacing.xxl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: sem.sectionSurface,
                  borderRadius: AppRadius.card,
                  border: Border.all(color: sem.hairline),
                ),
                child: Column(
                  children: [
                    row('Knowledge level',
                        knowledgeLabelFromValue(s.knowledgeLevel)),
                    row('Topics', '${s.selectedTopics.length} chosen'),
                    row('Daily goal', '${s.dailyGoal} cards/day'),
                  ],
                ),
              ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
              const Spacer(),
              AppButton(
                label: 'Start learning',
                onPressed: () => context.go(AppRoutes.news),
              ).animate().fadeIn(delay: 450.ms, duration: 400.ms),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/onboarding_done_test.dart`
Expected: PASS.

- [ ] **Step 5: Register the route + allowlist**

In `lib/core/router/app_router.dart`:
- Add the import near the other onboarding screen imports:
```dart
import '../../features/onboarding/screens/onboarding_done_screen.dart';
```
- Add the route constant in `AppRoutes` after `onboardingGoal`:
```dart
  static const onboardingDone = '/onboarding/done';
```
- Add `onboardingDone` to the `alwaysOpen` set (so the post-completion guard
  `onboarded && inOnboarding → news` does **not** bounce it):
```dart
    const alwaysOpen = {
      AppRoutes.onboardingWelcome,
      AppRoutes.onboardingLogin,
      AppRoutes.onboardingRegister,
      AppRoutes.onboardingDone,
    };
```
- Add the child `GoRoute` after the `goal` route, inside the onboarding shell's `routes:`:
```dart
        GoRoute(
          path: 'done',
          name: 'onboarding_done',
          builder: (context, state) => const OnboardingDoneScreen(),
        ),
```

- [ ] **Step 6: Verify build**

Run: `flutter analyze lib/core/router/app_router.dart lib/features/onboarding/screens/onboarding_done_screen.dart lib/features/onboarding/screens/daily_goal_screen.dart`
Expected: no errors (resolves the Task 5 forward-reference to `onboardingDone`).

- [ ] **Step 7: Commit**

```bash
git add lib/features/onboarding/screens/onboarding_done_screen.dart test/widgets/onboarding_done_test.dart lib/core/router/app_router.dart
git commit -m "feat(onboarding): You're all set finish screen + route"
```

---

## Task 9: Lock the rules — onboarding consistency guards

**Files:**
- Modify: `test/foundation/consistency_guard_test.dart`

- [ ] **Step 1: Add the two guards**

Append inside `main()` in `test/foundation/consistency_guard_test.dart`:
```dart
  test('no ad-hoc TextStyle(fontSize:) in onboarding widgets', () {
    final offenders = <String>[];
    for (final file
        in Directory('lib/features/onboarding').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.readAsStringSync().contains('fontSize:')) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'Use textTheme tokens, not raw fontSize:\n'
            '${offenders.join('\n')}');
  });

  test('no direct AppColors.* in onboarding widgets', () {
    final offenders = <String>[];
    for (final file
        in Directory('lib/features/onboarding').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (RegExp(r'AppColors\.').hasMatch(file.readAsStringSync())) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'Source color from colorScheme/context.sem:\n'
            '${offenders.join('\n')}');
  });
```

- [ ] **Step 2: Run the guard**

Run: `flutter test test/foundation/consistency_guard_test.dart`
Expected: PASS (all onboarding offenders migrated in Tasks 2–8). If any file is listed, migrate it per the mapping table and re-run.

- [ ] **Step 3: Full suite + analyzer**

Run: `flutter analyze && flutter test`
Expected: no analyzer errors; all tests PASS.

- [ ] **Step 4: Commit**

```bash
git add test/foundation/consistency_guard_test.dart
git commit -m "test(onboarding): guard against fontSize/AppColors regressions"
```

---

## Self-review notes

- **Spec coverage:** AppOptionCard (T1); coral + textTheme + no-emoji migration of
  persona (T2), knowledge level (T3), topics (T4), daily goal (T5); step
  bar + auth_button + welcome contrast (T6); login/register (T7); finish beat +
  route + allowlist (T8); regression guards + new widget tests (T1, T8, T9).
  Every acceptance criterion in the spec maps to a task.
- **Router subtlety:** because `completeOnboarding` persists onboarded=true on
  the daily-goal screen, `/onboarding/done` must be in `alwaysOpen` (T8 Step 5)
  or the guard would redirect it to News. Captured explicitly.
- **Type consistency:** `AppOptionCard(title, subtitle?, leading?, trailing?,
  selected, onTap)` is used identically in persona (T2) and daily goal (T5).
  `AppButton(label, onPressed, icon?, loading?, expand?)` and
  `AppBadge(label, color)` match their foundation definitions.
- **Emoji removal** is verified structurally — the `fontSize:`/`AppColors.*`
  guards plus the explicit `emoji` field deletions in T2/T3/T4/T5; no emoji
  string literals remain on those screens.
- **Behavior preserved:** no auth/validation/step-order changes; only the
  daily-goal terminal navigation moves from News → done → News.
