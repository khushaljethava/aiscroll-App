import 'package:flutter/material.dart';

/// Editorial design token palette.
///
/// The app has converged on a single dark editorial look: `inkBlack` as the
/// scaffold, `inkSurface` / `inkSurface2` as layered surfaces, and `ctaAccent`
/// as the primary brand CTA. Indigo `primary` is retained as a feature accent
/// (XP, topic chips) but should not be used as a background.
///
/// Legacy tokens (`surface`, `surfaceVariant`, `cardDark`) are kept as
/// `@Deprecated` aliases so older call-sites continue to compile while they're
/// migrated to the ink palette.
class AppColors {
  AppColors._();

  // --- Brand ----------------------------------------------------------------

  /// Indigo accent — retired as the primary action color; now kept only as a
  /// categorical accent (e.g. "rare" badge rarity, XP chips). Do NOT use for
  /// buttons, links, or focus rings — use [brandAccent] instead.
  static const primary = Color(0xFF4F46E5);
  static const primaryMuted = Color(0x244F46E5); // primary @ 14%
  static const accent = Color(0xFF10B981);
  static const error = Color(0xFFC81E3A); // was 0xFFEF4444 — cooler/deeper

  /// AgentBuildLog brand / action color — "electric cobalt" from the Stitch
  /// "Editorial Ink" design system shared with agentbuildlog.com. Single action
  /// color: primary buttons, links, focus, selected states.
  static const brandAccent = Color(0xFF2F5BFF);
  /// Darkened cobalt for pressed/active button states.
  static const brandAccentPressed = Color(0xFF2449D6);

  /// White text/icons on cobalt fills (AA: ~5:1).
  static const onBrand = Color(0xFFFFFFFF);

  /// Lighter cobalt for dark surfaces (AA on [inkBlack]), with dark ink on it.
  static const brandAccentOnInk = Color(0xFF7D98FF);
  static const onBrandOnInk = Color(0xFF0A0F2E);

  /// CTA accent on editorial surfaces (News, Learn header, Go-Pro tile).
  /// One accent across the product, so this is the brand cobalt.
  static const ctaAccent = brandAccent;

  /// Warning — genuinely an alarm state (stale cache, failed sync). Warmer
  /// than [ctaAccent] so it reads differently.
  static const warning = Color(0xFFEA580C);

  // --- Text on ink / paper --------------------------------------------------

  static const textPrimary = Color(0xFFF9FAFB);
  static const textSecondary = Color(0xFF9CA3AF);
  static const textDark = Color(0xFF111827);

  // --- Difficulty -----------------------------------------------------------

  static const beginner = Color(0xFF10B981);
  static const intermediate = Color(0xFFF59E0B);
  static const advanced = Color(0xFFB0182F); // was 0xFFEF4444 — separated from coral

  // --- Gamification ---------------------------------------------------------

  static const xpGold = Color(0xFFFBBF24);
  static const streakOrange = Color(0xFFF97316);

  // --- Editorial ink / paper ------------------------------------------------

  /// True-black editorial background. Scaffold for every screen in dark mode.
  static const inkBlack = Color(0xFF111110);

  /// Slightly lifted surface over [inkBlack] — cards, sheets, chips.
  static const inkSurface = Color(0xFF1A1A18);

  /// Second-level surface — pressed state, muted containers.
  static const inkSurface2 = Color(0xFF262522);

  /// 1px hairline divider on dark editorial surfaces.
  static const inkHairline = Color(0x1FFFFFFF); // white @ 12%

  /// Warm paper background for light mode editorial layouts.
  static const paper = Color(0xFFFBF9F5);

  /// Slightly darker paper — muted section backgrounds.
  static const paperMuted = Color(0xFFF0EEEA);

  /// 1px hairline on paper.
  static const paperHairline = Color(0xFFE7E5E0); // Stitch hairline rule

  /// Near-black ink on paper, avoiding pure black so it doesn't feel harsh
  /// under a serif headline.
  static const inkOnPaper = Color(0xFF141414);

  /// Secondary ink — meta rows, captions.
  static const inkMutedOnPaper = Color(0xFF55534E);

  /// Secondary text on dark editorial surfaces.
  static const textMutedOnInk = Color(0xFFB5B3BA);

  // --- Brand partners / overlays -------------------------------------------

  /// Google brand blue — used exclusively by the Google Sign-In button.
  /// Don't repurpose; Google requires their exact brand color on the button.
  static const googleBlue = Color(0xFF4285F4);

  /// Frosted glass outline — 20 % white, works on top of photography.
  static const glassOverlay = Color(0x33FFFFFF);

  // --- Legacy aliases (deprecated) -----------------------------------------
  //
  // These map the old indigo tokens to the editorial palette so existing
  // code keeps rendering. Migrate call-sites progressively; do not add new
  // references.

  @Deprecated('Use inkSurface instead — this is the editorial surface.')
  static const cardDark = inkSurface;

  @Deprecated('Use inkSurface instead (or Colors.white for light-mode cards).')
  static const cardLight = Colors.white;

  @Deprecated('Use inkBlack for scaffolds or inkSurface for cards.')
  static const surface = inkBlack;

  @Deprecated('Use inkSurface2 for muted containers or primaryMuted for tinted.')
  static const surfaceVariant = inkSurface2;

  // --- Category accents -----------------------------------------------------

  /// Canonical accent per category key. Falls back to [primary] for unknown
  /// keys. Tuned to read well on both paper and ink backgrounds.
  static const Map<String, Color> categoryAccents = <String, Color>{
    'tech': Color(0xFF3B82F6), // cobalt
    'business': Color(0xFF10B981), // emerald
    'sports': Color(0xFFF59E0B), // amber
    'politics': Color(0xFFE11D48), // rose
    'science': Color(0xFF8B5CF6), // violet
    'world': Color(0xFF06B6D4), // cyan
    'culture': Color(0xFFEC4899), // pink
    'health': Color(0xFF14B8A6), // teal
    'entertainment': Color(0xFFF97316), // orange
  };

  static Color categoryAccent(String? key) {
    if (key == null || key.isEmpty) return primary;
    return categoryAccents[key.toLowerCase()] ?? primary;
  }

  /// Subtle tinted background for a category chip / meta row. Safe for both
  /// light and dark surfaces.
  static Color categoryTint(String? key, {double alpha = 0.12}) {
    return categoryAccent(key).withValues(alpha: alpha);
  }
}
