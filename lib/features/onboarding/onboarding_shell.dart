import 'package:flutter/material.dart';

/// A lightweight pass-through shell for the onboarding flow.
/// Each sub-screen handles its own navigation via go_router.
/// The shell provides a consistent dark background with no AppBar,
/// letting each screen manage its own header content.
class OnboardingShell extends StatelessWidget {
  const OnboardingShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor omitted — the theme's scaffoldBackgroundColor
      // (inkBlack in dark, paper in light) adapts to the user's choice.
      body: child,
    );
  }
}
