import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aiscroll/features/onboarding/screens/onboarding_done_screen.dart';

void main() {
  testWidgets('done screen shows the all-set headline + CTA', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: OnboardingDoneScreen()),
    ));
    // Let flutter_animate entrance animations finish so no timers stay pending.
    await tester.pumpAndSettle();
    expect(find.text("You're all set"), findsOneWidget);
    expect(find.text('Start learning'), findsOneWidget);
  });
}
