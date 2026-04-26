import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Semantic color tokens that don't fit cleanly into Material's [ColorScheme].
///
/// Read these via `Theme.of(context).extension<AppSemanticColors>()!` or the
/// shorter `context.sem` extension below. They switch automatically with the
/// active brightness, unlike the raw constants in [AppColors] which are a
/// fixed dark-mode palette.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.xpGold,
    required this.streakOrange,
    required this.success,
    required this.warning,
    required this.hairline,
    required this.sectionSurface,
    required this.dangerSurface,
  });

  /// XP / level pill accents, premium tile gradient stop.
  final Color xpGold;

  /// Streak flame, "fire" affordances.
  final Color streakOrange;

  /// Distinct from [ColorScheme.tertiary] — used for "passed quiz" / earned
  /// badge dots. Reads cleanly on both ink and paper.
  final Color success;

  /// Stale-cache / failed-sync banners. Warmer than [xpGold] so it doesn't
  /// blend into XP affordances.
  final Color warning;

  /// 1px rule color for dividers and card borders. Slightly more opaque than
  /// [ColorScheme.outlineVariant] so hairlines stay visible on `paper`.
  final Color hairline;

  /// Canonical "card" background. In dark mode this lifts above the
  /// `inkBlack` scaffold; in light mode it's pure white on warm `paper`.
  final Color sectionSurface;

  /// Subtle red-tinted background for danger-zone groups (sign-out, erase).
  final Color dangerSurface;

  static const dark = AppSemanticColors(
    xpGold: AppColors.xpGold,
    streakOrange: AppColors.streakOrange,
    success: AppColors.accent,
    warning: AppColors.warning,
    hairline: AppColors.inkHairline,
    sectionSurface: AppColors.inkSurface,
    dangerSurface: Color(0x14EF4444),
  );

  static const light = AppSemanticColors(
    xpGold: Color(0xFFB8860B),
    streakOrange: AppColors.streakOrange,
    success: Color(0xFF047857),
    warning: Color(0xFFB45309),
    hairline: AppColors.paperHairline,
    sectionSurface: Colors.white,
    dangerSurface: Color(0x0DEF4444),
  );

  @override
  AppSemanticColors copyWith({
    Color? xpGold,
    Color? streakOrange,
    Color? success,
    Color? warning,
    Color? hairline,
    Color? sectionSurface,
    Color? dangerSurface,
  }) {
    return AppSemanticColors(
      xpGold: xpGold ?? this.xpGold,
      streakOrange: streakOrange ?? this.streakOrange,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      hairline: hairline ?? this.hairline,
      sectionSurface: sectionSurface ?? this.sectionSurface,
      dangerSurface: dangerSurface ?? this.dangerSurface,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      xpGold: Color.lerp(xpGold, other.xpGold, t)!,
      streakOrange: Color.lerp(streakOrange, other.streakOrange, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      sectionSurface: Color.lerp(sectionSurface, other.sectionSurface, t)!,
      dangerSurface: Color.lerp(dangerSurface, other.dangerSurface, t)!,
    );
  }
}

/// Shorthand: `context.sem.xpGold` instead of
/// `Theme.of(context).extension<AppSemanticColors>()!.xpGold`.
extension AppSemanticColorsX on BuildContext {
  AppSemanticColors get sem =>
      Theme.of(this).extension<AppSemanticColors>() ?? AppSemanticColors.dark;
}
