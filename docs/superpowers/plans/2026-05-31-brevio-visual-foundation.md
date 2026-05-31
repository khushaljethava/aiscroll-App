# Brevio Visual Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish the Brevio visual foundation — one brand, one warm-coral action color (separated from status reds), enforced typography, and shared component primitives — applied consistently across the app.

**Architecture:** Token-first. We extend the existing token files (`app_colors.dart`, `app_semantic_colors.dart`, `app_theme.dart`), add a brand-constants file and a small set of shared widgets, then migrate the worst offenders (Welcome, Splash, Profile, Tracks) to the tokens/primitives. Guard tests (file-content scans) lock the consistency rules so they don't regress. The action color flows through `ColorScheme.primary`; gamification colors stay in `AppSemanticColors`.

**Tech Stack:** Flutter, Dart, `flutter_riverpod`, `google_fonts`, `flutter_test` (already a dev dependency). No new packages required.

---

## File structure

**Create:**
- `lib/core/constants/brand.dart` — single source of truth for brand name, tagline, share URL, store copy.
- `lib/shared/widgets/brand_wordmark.dart` — the `Brevio` serif wordmark.
- `lib/shared/widgets/app_button.dart` — the one pill CTA button.
- `lib/shared/widgets/app_badge.dart` — shared pill/badge + status dot.
- `lib/shared/widgets/app_skeleton.dart` — shimmer skeleton block.
- `test/foundation/brand_constants_test.dart`
- `test/foundation/theme_color_test.dart`
- `test/foundation/consistency_guard_test.dart`
- `test/widgets/app_button_test.dart`
- `test/widgets/app_badge_test.dart`
- `test/widgets/brand_wordmark_test.dart`

**Modify:**
- `lib/core/theme/app_colors.dart` — add coral tokens, retune error/advanced reds.
- `lib/core/theme/app_theme.dart` — point primary/CTA at coral; fix comment.
- `lib/app.dart:163` — MaterialApp title → brand constant.
- `lib/features/onboarding/screens/splash_screen.dart:52` — wordmark.
- `lib/features/onboarding/screens/welcome_screen.dart` — wordmark + textTheme.
- `lib/features/feed/widgets/shareable_card.dart:117` — `→ Brevio`.
- `lib/core/notifications/notification_service.dart:34` — brand string.
- `lib/data/remote/news_push_service.dart:169` — fallback title.
- `lib/features/profile/screens/profile_screen.dart` — brand strings (push/settings/referral), buttons → `AppButton`, pills → `AppBadge`, color sourcing.
- `lib/features/tracks/screens/tracks_screen.dart` — empty state → `AppEmptyState`.

---

## Color values (locked)

These are the concrete starting values; the guard/contrast tests below verify the constraints.

- Brand coral (accent, selected, focus): `#FF5A4D`
- Coral pressed: `#E64A3F`
- Text on coral (`onPrimary`): `#2A0B06` (near-black warm — ~6:1 on coral, passes AA; coral + white is only ~2.6:1)
- Error (retuned, cooler/deeper): `#C81E3A`
- Difficulty `advanced` (retuned): `#B0182F`

Rationale recorded in `docs/superpowers/specs/2026-05-31-brevio-visual-foundation-design.md`.

---

## Task 1: Brand constants

**Files:**
- Create: `lib/core/constants/brand.dart`
- Test: `test/foundation/brand_constants_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/foundation/brand_constants_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:aiscroll/core/constants/brand.dart';

void main() {
  test('brand exposes Brevio identity', () {
    expect(Brand.name, 'Brevio');
    expect(Brand.tagline, 'Learn AI Daily, in Seconds.');
    expect(Brand.shareUrl, startsWith('https://'));
    expect(Brand.shareUrl, isNot(contains('aiscroll')));
    expect(Brand.storeSubtitle.length, lessThanOrEqualTo(30));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/foundation/brand_constants_test.dart`
Expected: FAIL — `Brand` not defined / target of URI doesn't exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/constants/brand.dart

/// Single source of truth for Brevio brand identity. Never hardcode the
/// product name, tagline, or share URL anywhere else.
class Brand {
  Brand._();

  static const String name = 'Brevio';
  static const String tagline = 'Learn AI Daily, in Seconds.';
  static const String welcomeTitle = 'Welcome to $name';

  /// Marketing/share URL. TODO(pre-launch): confirm domain ownership.
  static const String shareUrl = 'https://brevio.app';

  /// App Store / Play copy. Subtitle must be <= 30 chars (Apple limit).
  static const String storeTitle = '$name: Learn AI Daily';
  static const String storeSubtitle = 'AI news & 60-sec lessons';

  /// Push-notification channel description / Settings deep-link instructions.
  static const String pushFromLine = 'Breaking AI news from the $name team.';
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/foundation/brand_constants_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/constants/brand.dart test/foundation/brand_constants_test.dart
git commit -m "feat(brand): add centralized Brevio brand constants"
```

---

## Task 2: Migrate user-facing brand strings

**Files:**
- Modify: `lib/app.dart:163`, `lib/features/onboarding/screens/splash_screen.dart:52`,
  `lib/features/feed/widgets/shareable_card.dart:117`,
  `lib/core/notifications/notification_service.dart:34`,
  `lib/data/remote/news_push_service.dart:169`,
  `lib/features/profile/screens/profile_screen.dart` (lines ~1095, 1104, 1131, 1634-1636)
- Test: `test/foundation/consistency_guard_test.dart`

- [ ] **Step 1: Write the failing guard test**

```dart
// test/foundation/consistency_guard_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Scans lib/ for banned legacy brand strings. Comments are migrated in a
/// later task, so this first pass skips comment-only lines.
void main() {
  test('no legacy brand names in user-facing strings', () {
    final banned = ['60 Second AI', 'AIScroll', 'aiscroll.app'];
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
        for (final b in banned) {
          if (line.contains(b)) offenders.add('${file.path}:${i + 1}  $b');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'Legacy brand strings:\n${offenders.join('\n')}');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/foundation/consistency_guard_test.dart`
Expected: FAIL — lists offenders across `app.dart`, `splash_screen.dart`, `shareable_card.dart`, `notification_service.dart`, `news_push_service.dart`, `profile_screen.dart`.

- [ ] **Step 3: Apply the edits**

`lib/app.dart` — add import `import 'core/constants/brand.dart';`, then line 163:
```dart
      title: Brand.name,
```

`lib/features/onboarding/screens/splash_screen.dart` — add import
`import '../../../core/constants/brand.dart';`, then line 52:
```dart
                Brand.name,
```

`lib/features/feed/widgets/shareable_card.dart` — add import
`import '../../../core/constants/brand.dart';`, then line 117:
```dart
                    '→ ${Brand.name}',
```

`lib/core/notifications/notification_service.dart` — add import
`import '../constants/brand.dart';`, then line 34:
```dart
      'Random AI news drops from the ${Brand.name} team.';
```

`lib/data/remote/news_push_service.dart` — add import
`import '../../core/constants/brand.dart';`, then line 169:
```dart
        notif?.title ?? message.data['title'] as String? ?? Brand.name;
```

`lib/features/profile/screens/profile_screen.dart` — add import
`import '../../../core/constants/brand.dart';`, then:

Line ~1095 (remove `const` on the `Text`):
```dart
      subtitle: Text(Brand.pushFromLine),
```
Lines ~1104 and ~1131:
```dart
              'Push notifications are blocked. Enable them in '
              'Settings → Apps → ${Brand.name} → Notifications.',
```
```dart
              'Notifications are blocked. Enable them in '
              'Settings → Apps → ${Brand.name} → Notifications.',
```
Lines ~1634-1636:
```dart
            'I\'m learning AI in 60s on ${Brand.name}. Use my code $code when '
            'you sign up and we both get a streak freeze. ${Brand.shareUrl}',
        subject: 'Join me on ${Brand.name}',
```

> Remove `const` from any `Text`/`SnackBar` the analyzer flags after adding
> the `Brand.*` interpolation.

- [ ] **Step 4: Run guard test + analyzer**

Run: `flutter test test/foundation/consistency_guard_test.dart && flutter analyze`
Expected: test PASS; no new analyzer errors.

- [ ] **Step 5: Commit**

```bash
git add lib test/foundation/consistency_guard_test.dart
git commit -m "refactor(brand): route user-facing strings through Brand constants"
```

---

## Task 3: Coral color tokens + status-red retune

**Files:**
- Modify: `lib/core/theme/app_colors.dart`
- Test: `test/foundation/theme_color_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/foundation/theme_color_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aiscroll/core/theme/app_colors.dart';
import 'package:aiscroll/core/theme/app_theme.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('brand coral defined and distinct from status reds', () {
    expect(AppColors.brandCoral, const Color(0xFFFF5A4D));
    expect(_contrast(AppColors.brandCoral, AppColors.error), greaterThan(1.4));
    expect(_contrast(AppColors.brandCoral, AppColors.advanced), greaterThan(1.4));
  });

  test('coral button text passes WCAG AA', () {
    expect(_contrast(AppColors.brandCoral, AppColors.onCoral),
        greaterThanOrEqualTo(4.5));
  });

  test('theme primary is coral in both brightnesses', () {
    expect(AppTheme.darkTheme.colorScheme.primary, AppColors.brandCoral);
    expect(AppTheme.lightTheme.colorScheme.primary, AppColors.brandCoral);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/foundation/theme_color_test.dart`
Expected: FAIL — `brandCoral`/`onCoral` not defined; primary still indigo.

- [ ] **Step 3: Edit `app_colors.dart`**

Add under the `// --- Brand ---` section:
```dart
  /// Brevio brand / action color (warm coral). Single action color: primary
  /// buttons, links, focus, selected states, non-gamification accents.
  static const brandCoral = Color(0xFFFF5A4D);
  static const brandCoralPressed = Color(0xFFE64A3F);

  /// Near-black warm ink for text/icons on coral fills (AA: ~6:1 on coral).
  static const onCoral = Color(0xFF2A0B06);
```
Retune the reds:
```dart
  static const error = Color(0xFFC81E3A); // was 0xFFEF4444 — cooler/deeper
```
```dart
  static const advanced = Color(0xFFB0182F); // was 0xFFEF4444 — separated from coral
```
Update the `primary` doc comment to note it is retired as the action color
(kept only for the "rare" badge rarity).

- [ ] **Step 4: Run test (theme assertion still fails until Task 4)**

Run: `flutter test test/foundation/theme_color_test.dart`
Expected: first two tests PASS; `theme primary is coral` FAILS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/app_colors.dart test/foundation/theme_color_test.dart
git commit -m "feat(theme): add coral brand tokens, separate status reds"
```

---

## Task 4: Wire coral into the theme

**Files:**
- Modify: `lib/core/theme/app_theme.dart`

- [ ] **Step 1: Dark `ColorScheme`** — replace primary/onPrimary:
```dart
        primary: AppColors.brandCoral,
        onPrimary: AppColors.onCoral,
```

- [ ] **Step 2: Light `ColorScheme`** — replace primary/onPrimary:
```dart
        primary: AppColors.brandCoral,
        onPrimary: AppColors.onCoral,
```

- [ ] **Step 3: Fix the stale brand comment** at the top of the file:
```dart
/// Editorial theme for Brevio.
```

- [ ] **Step 4: Run color test + analyzer**

Run: `flutter test test/foundation/theme_color_test.dart && flutter analyze`
Expected: all three color tests PASS; no analyzer errors.

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/app_theme.dart
git commit -m "feat(theme): make coral the primary action color"
```

---

## Task 5: Brand wordmark widget

**Files:**
- Create: `lib/shared/widgets/brand_wordmark.dart`
- Test: `test/widgets/brand_wordmark_test.dart`
- Modify: `lib/features/onboarding/screens/splash_screen.dart`,
  `lib/features/onboarding/screens/welcome_screen.dart`

- [ ] **Step 1: Write the failing widget test**

```dart
// test/widgets/brand_wordmark_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aiscroll/shared/widgets/brand_wordmark.dart';
import 'package:aiscroll/core/constants/brand.dart';

void main() {
  testWidgets('wordmark renders the brand name', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: BrandWordmark()),
    ));
    expect(find.text(Brand.name), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/brand_wordmark_test.dart`
Expected: FAIL — `BrandWordmark` not defined.

- [ ] **Step 3: Implement the wordmark**

```dart
// lib/shared/widgets/brand_wordmark.dart
import 'package:flutter/material.dart';

import '../../core/constants/brand.dart';

/// The Brevio wordmark, set in the theme's editorial serif (Newsreader via
/// `displaySmall`/`headlineMedium`). Use on Splash and Welcome.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.large = true});

  final bool large;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final style = large ? tt.displaySmall : tt.headlineMedium;
    return Text(
      Brand.name,
      textAlign: TextAlign.center,
      style: style?.copyWith(color: Theme.of(context).colorScheme.onSurface),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/brand_wordmark_test.dart`
Expected: PASS.

- [ ] **Step 5: Use it on Splash and Welcome**

In `splash_screen.dart`, replace the `Text(Brand.name, ...)` (from Task 2) with
`const BrandWordmark()`; add import
`import '../../../shared/widgets/brand_wordmark.dart';`.

In `welcome_screen.dart`, replace the `🤖` emoji block (lines ~93-104) and the
hardcoded title `Text('Welcome to 60 Second AI', style: TextStyle(fontSize: 26, ...))`
and the hardcoded tagline with:
```dart
              const SizedBox(height: 64),
              const BrandWordmark()
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.1, end: 0, duration: 400.ms),
              const SizedBox(height: 8),
              Text(
                Brand.tagline,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
```
Add imports:
`import '../../../shared/widgets/brand_wordmark.dart';`
`import '../../../core/constants/brand.dart';`

- [ ] **Step 6: Run analyzer + test**

Run: `flutter analyze && flutter test test/widgets/brand_wordmark_test.dart`
Expected: no errors; PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/shared/widgets/brand_wordmark.dart test/widgets/brand_wordmark_test.dart lib/features/onboarding/screens/splash_screen.dart lib/features/onboarding/screens/welcome_screen.dart
git commit -m "feat(brand): serif Brevio wordmark on splash + welcome"
```

---

## Task 6: Shared pill CTA button

**Files:**
- Create: `lib/shared/widgets/app_button.dart`
- Test: `test/widgets/app_button_test.dart`
- Modify: `lib/features/profile/screens/profile_screen.dart` (`_SignInButton`, "Watch ad", "Redeem")

- [ ] **Step 1: Write the failing widget test**

```dart
// test/widgets/app_button_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aiscroll/shared/widgets/app_button.dart';

void main() {
  testWidgets('AppButton shows label and fires onPressed', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AppButton(label: 'Go', onPressed: () => tapped = true)),
    ));
    expect(find.text('Go'), findsOneWidget);
    await tester.tap(find.byType(AppButton));
    expect(tapped, isTrue);
  });

  testWidgets('AppButton disables + shows spinner when loading', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppButton(label: 'Go', loading: true, onPressed: () => tapped = true),
      ),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(AppButton));
    expect(tapped, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/app_button_test.dart`
Expected: FAIL — `AppButton` not defined.

- [ ] **Step 3: Implement `AppButton`**

```dart
// lib/shared/widgets/app_button.dart
import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// The single pill call-to-action button. Coral fill via ColorScheme.primary.
/// Replaces per-screen hand-rolled ElevatedButtons.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final child = loading
        ? SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(label),
            ],
          );
    final button = ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: 14),
        minimumSize: const Size(0, 48), // >= 44px tap target
      ),
      child: child,
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/app_button_test.dart`
Expected: PASS.

- [ ] **Step 5: Migrate Profile buttons**

In `profile_screen.dart` (add import `import '../../../shared/widgets/app_button.dart';`):
- `_SignInButton` body →
  ```dart
      child: AppButton(
        label: 'Sign in / Create account',
        icon: Icons.login_rounded,
        expand: false,
        onPressed: () => context.push(AppRoutes.onboardingWelcome),
      ),
  ```
- "Watch ad" `ElevatedButton.icon` →
  ```dart
            AppButton(
              label: _watching ? 'Loading' : 'Watch ad',
              icon: _watching ? null : Icons.play_circle_outline_rounded,
              loading: _watching,
              expand: false,
              onPressed: (atCap || _watching) ? null : _watchAdForFreeze,
            ),
  ```
- Referral `FilledButton` →
  ```dart
                  AppButton(
                    label: 'Redeem',
                    loading: _redeeming,
                    expand: false,
                    onPressed: _redeeming ? null : _redeem,
                  ),
  ```

- [ ] **Step 6: Run analyzer + test**

Run: `flutter analyze && flutter test test/widgets/app_button_test.dart`
Expected: no errors; PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/shared/widgets/app_button.dart test/widgets/app_button_test.dart lib/features/profile/screens/profile_screen.dart
git commit -m "feat(ui): shared AppButton pill CTA, migrate profile buttons"
```

---

## Task 7: Shared badge / pill / status dot

**Files:**
- Create: `lib/shared/widgets/app_badge.dart`
- Test: `test/widgets/app_badge_test.dart`
- Modify: `lib/features/profile/screens/profile_screen.dart` (`_LevelPill`, "EARNED"),
  `lib/features/tracks/screens/tracks_screen.dart` (`_StationLabel` dot)

- [ ] **Step 1: Write the failing widget test**

```dart
// test/widgets/app_badge_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aiscroll/shared/widgets/app_badge.dart';

void main() {
  testWidgets('AppBadge shows label', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AppBadge(label: 'Level 3', color: Colors.amber)),
    ));
    expect(find.text('Level 3'), findsOneWidget);
  });

  testWidgets('AppStatusDot paints', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AppStatusDot(color: Colors.green)),
    ));
    expect(find.byType(AppStatusDot), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/app_badge_test.dart`
Expected: FAIL — `AppBadge`/`AppStatusDot` not defined.

- [ ] **Step 3: Implement**

```dart
// lib/shared/widgets/app_badge.dart
import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// A tinted pill badge (level pill, "EARNED" tag, etc.). Tints [color] for the
/// background and border so it adapts to any accent.
class AppBadge extends StatelessWidget {
  const AppBadge({super.key, required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: tt.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Small filled status dot used in meta rows.
class AppStatusDot extends StatelessWidget {
  const AppStatusDot({super.key, required this.color, this.size = 6});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/app_badge_test.dart`
Expected: PASS.

- [ ] **Step 5: Migrate call sites**

- `profile_screen.dart` `_LevelPill` body →
  `AppBadge(label: 'Level $level · $title', color: context.sem.xpGold)`
- `profile_screen.dart` "EARNED" tag (`_BadgeTile`) →
  `AppBadge(label: 'EARNED', color: context.sem.success)`
- `tracks_screen.dart` `_StationLabel` 6×6 dot `Container` →
  `AppStatusDot(color: accent)`

Add import where needed: `import '../../../shared/widgets/app_badge.dart';`

- [ ] **Step 6: Run analyzer + test**

Run: `flutter analyze && flutter test test/widgets/app_badge_test.dart`
Expected: no errors; PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/shared/widgets/app_badge.dart test/widgets/app_badge_test.dart lib/features/profile/screens/profile_screen.dart lib/features/tracks/screens/tracks_screen.dart
git commit -m "feat(ui): shared AppBadge + AppStatusDot, migrate pills/dots"
```

---

## Task 8: Skeleton loader + Tracks empty state

**Files:**
- Create: `lib/shared/widgets/app_skeleton.dart`
- Modify: `lib/features/tracks/screens/tracks_screen.dart`

- [ ] **Step 1: Implement the skeleton block**

```dart
// lib/shared/widgets/app_skeleton.dart
import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// A single shimmering placeholder block. Compose several to fake a list item
/// while data loads, instead of a bare spinner.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({super.key, this.height = 16, this.width, this.radius = AppRadius.sm});

  final double height;
  final double? width;
  final double radius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 0.9).animate(_c),
      child: Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Migrate the Tracks empty state**

In `tracks_screen.dart` (add import `import '../../../shared/widgets/app_empty_state.dart';`),
replace the `SliverFillRemaining` raw-`Text` empty branch with:
```dart
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                icon: Icons.search_off_rounded,
                title: query.isEmpty ? 'No tracks here yet' : 'No matches',
                message: query.isEmpty
                    ? 'Try a different difficulty filter.'
                    : 'Nothing matches “$query”. Try another search.',
              ),
            )
```

- [ ] **Step 3: Run analyzer + full suite**

Run: `flutter analyze && flutter test`
Expected: no errors; all tests PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/shared/widgets/app_skeleton.dart lib/features/tracks/screens/tracks_screen.dart
git commit -m "feat(ui): skeleton loader primitive + Tracks empty state"
```

---

## Task 9: Enforce typography + color sourcing (guard tests)

**Files:**
- Modify: `test/foundation/consistency_guard_test.dart` (add two guards)
- Modify: offending feature widgets until guards pass

- [ ] **Step 1: Add the failing guards**

Append to `test/foundation/consistency_guard_test.dart` (inside `main`):
```dart
  test('no ad-hoc TextStyle(fontSize:) in feature widgets', () {
    final offenders = <String>[];
    for (final file in Directory('lib/features').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.readAsStringSync().contains('fontSize:')) offenders.add(file.path);
    }
    expect(offenders, isEmpty,
        reason: 'Use textTheme tokens, not raw fontSize:\n${offenders.join('\n')}');
  });

  test('no direct AppColors.* in feature widgets', () {
    final offenders = <String>[];
    for (final file in Directory('lib/features').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (RegExp(r'AppColors\.').hasMatch(file.readAsStringSync())) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'Source color from colorScheme/context.sem:\n${offenders.join('\n')}');
  });
```

- [ ] **Step 2: Run to see the offender list**

Run: `flutter test test/foundation/consistency_guard_test.dart`
Expected: FAIL — lists offending feature files.

- [ ] **Step 3: Migrate offenders iteratively (per spec §C mapping)**

For each offending file:
- `TextStyle(fontSize: N, fontWeight: W)` → nearest `textTheme` token. Example
  (Profile `_XpProgressCard` title):
  ```dart
              Text(title, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
  ```
- `AppColors.primary` (action) → `Theme.of(context).colorScheme.primary`
- `AppColors.ctaAmber` (gamification) → `context.sem.xpGold` / `context.sem.streakOrange`;
  (pure CTA) → `colorScheme.primary`
- `AppColors.textPrimary` / `textSecondary` → `colorScheme.onSurface` / `onSurfaceVariant`
- `AppColors.inkSurface*` → `context.sem.sectionSurface` / `colorScheme.surfaceContainerHighest`
- `AppColors.accent` → `context.sem.success`

Token definitions in `lib/core/theme/` keep their `AppColors.*` references —
the guard only scans `lib/features`. Re-run the guard after each file:
Run: `flutter test test/foundation/consistency_guard_test.dart`

- [ ] **Step 4: Full suite + analyzer**

Run: `flutter analyze && flutter test`
Expected: no errors; all PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test/foundation/consistency_guard_test.dart
git commit -m "refactor(ui): enforce textTheme + semantic color sourcing in features"
```

---

## Task 10: Accessibility pass

**Files:**
- Modify: feature widgets surfaced by the audit in Step 1

- [ ] **Step 1: Find icon buttons missing semantics**

Run: `grep -rn "IconButton(" lib/features | grep -v "tooltip:"`
Expected: a list of `IconButton`s without `tooltip:`.

- [ ] **Step 2: Add a `tooltip:`** to each flagged `IconButton` describing its
  action (e.g. `tooltip: 'Share'`). For icon-only `GestureDetector`/`InkWell`
  tappables, wrap with `Semantics(button: true, label: '<action>', child: ...)`.

- [ ] **Step 3: Verify tap targets** — wrap any custom tappable smaller than
  44px in `SizedBox(width: 48, height: 48, ...)` or add padding. (The Tracks
  medallion is 84px — OK.)

- [ ] **Step 4: Run analyzer + full suite**

Run: `flutter analyze && flutter test`
Expected: no errors; all PASS.

- [ ] **Step 5: Commit**

```bash
git add lib
git commit -m "fix(a11y): semantic labels on icon buttons, 44px tap targets"
```

---

## Task 11: Migrate brand comments + asset name (final consistency)

**Files:**
- Modify: `lib/main.dart:40`, `lib/data/remote/ads_service.dart:8`,
  `lib/data/remote/auth_service.dart:36`, `lib/data/models/srs_model.dart:3`,
  `lib/core/share/card_image_share.dart:45`
- Modify: `test/foundation/consistency_guard_test.dart`

- [ ] **Step 1: Replace `60 Second AI` in the listed doc comments** with `Brevio`
  (no behavior change). In `card_image_share.dart:45`, rename the export file
  from `aiscroll-card.png` to `brevio-card.png`.

- [ ] **Step 2: Extend the guard to comments** — in
  `consistency_guard_test.dart`, remove the comment-skip lines in the
  `no legacy brand names` test so it scans comments too. Re-run:
  Run: `flutter test test/foundation/consistency_guard_test.dart`
  Expected: PASS.

- [ ] **Step 3: Full suite + analyzer**

Run: `flutter analyze && flutter test`
Expected: no errors; all PASS.

- [ ] **Step 4: Commit**

```bash
git add lib test/foundation/consistency_guard_test.dart
git commit -m "chore(brand): finish Brevio rename in comments + asset name"
```

---

## Self-review notes

- **Spec coverage:** brand rollout (T1, T2, T5, T11), color system + status-red
  separation (T3, T4), typography enforcement (T9), component primitives —
  button (T6), badge/dot (T7), empty state + skeleton (T8) — accessibility (T10).
  Every acceptance criterion in the spec maps to a task.
- **Contrast:** coral + `onCoral` is asserted ≥4.5:1 in `theme_color_test.dart`;
  if the chosen coral fails, darken `onCoral`/`brandCoral` until it passes — do
  not weaken the assertion.
- **Type consistency:** `AppButton(label, onPressed, icon, loading, expand)`,
  `AppBadge(label, color, icon)`, `AppStatusDot(color, size)`,
  `BrandWordmark(large)`, `AppSkeleton(height, width, radius)` signatures are
  used identically at every call site.
- **Guards are the regression net:** Tasks 2 and 9 install file-scan tests that
  fail the build if legacy strings, raw `fontSize:`, or `AppColors.*` reappear
  in `lib/features`.
- **Package import name:** tests import `package:aiscroll/...` (the `name:` in
  `pubspec.yaml`). The package name is unchanged by this work; only user-facing
  copy becomes "Brevio".
