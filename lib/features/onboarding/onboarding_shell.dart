import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';

/// A lightweight pass-through shell for the onboarding flow.
///
/// Adds a top progress indicator on the 4 personalization steps
/// (persona → level → topics → goal) so the user always knows where
/// they are in the funnel. Welcome/login/register screens render with
/// no indicator because they're not part of the funnel.
class OnboardingShell extends StatelessWidget {
  const OnboardingShell({super.key, required this.child});

  final Widget child;

  static const _steps = <String>[
    '/onboarding/persona',
    '/onboarding/level',
    '/onboarding/topics',
    '/onboarding/goal',
  ];

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    final stepIndex = _steps.indexOf(loc);
    return Scaffold(
      body: stepIndex < 0
          ? child
          : Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: _StepBar(
                      total: _steps.length,
                      current: stepIndex,
                    ),
                  ),
                ),
                Expanded(child: child),
              ],
            ),
    );
  }
}

class _StepBar extends StatelessWidget {
  const _StepBar({required this.total, required this.current});

  final int total;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final filled = i <= current;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              height: 3,
              decoration: BoxDecoration(
                color: filled
                    ? AppColors.ctaAmber
                    : AppColors.inkHairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      }),
    );
  }
}
