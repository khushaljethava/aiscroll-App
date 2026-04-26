import 'package:flutter/material.dart';

/// Spatial, shape, and motion tokens shared across the app. Consolidated here
/// so values stay consistent when the design is iterated on.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Standard horizontal gutter on full-width screens.
  static const double screenGutter = 20;

  /// Generous gutter used by the editorial News detail article body to give
  /// the serif headline room to breathe.
  static const double editorialGutter = 24;
}

class AppRadius {
  AppRadius._();

  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 22;
  static const double pill = 999;

  static BorderRadius get card => BorderRadius.circular(xl);
  static BorderRadius get chip => BorderRadius.circular(pill);
  static BorderRadius get input => BorderRadius.circular(md);
}

class AppMotion {
  AppMotion._();

  /// Micro-interactions: chip selection, icon state toggles.
  static const Duration fast = Duration(milliseconds: 180);

  /// Page transitions inside a feature, small list reorders.
  static const Duration base = Duration(milliseconds: 240);

  /// Full-screen transitions, larger card morphs.
  static const Duration slow = Duration(milliseconds: 360);

  static const Curve emphasized = Curves.easeOutCubic;
  static const Curve standard = Curves.easeOut;
}
