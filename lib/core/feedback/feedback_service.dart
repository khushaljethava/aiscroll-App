import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/user_provider.dart';

/// Thin wrapper around `HapticFeedback` and `SystemSound` that respects the
/// user's `hapticsEnabled` / `soundEnabled` preferences. Static methods so
/// call sites stay terse: `FeedbackService.light(ref)`.
class FeedbackService {
  FeedbackService._();

  static bool _haptics(WidgetRef ref) =>
      ref.read(userProvider).hapticsEnabled;

  static bool _sound(WidgetRef ref) =>
      ref.read(userProvider).soundEnabled;

  /// Tap / selection. Cheapest; OK to fire per-keystroke-ish.
  static void light(WidgetRef ref) {
    if (_haptics(ref)) HapticFeedback.lightImpact();
  }

  /// Meaningful action confirmation (swipe, correct quiz answer).
  static void medium(WidgetRef ref) {
    if (_haptics(ref)) HapticFeedback.mediumImpact();
  }

  /// Big win (level-up, boss quiz pass).
  static void heavy(WidgetRef ref) {
    if (_haptics(ref)) HapticFeedback.heavyImpact();
  }

  /// Selection-style haptic (quiz option tap).
  static void selection(WidgetRef ref) {
    if (_haptics(ref)) HapticFeedback.selectionClick();
  }

  /// Audible click — no new packages required.
  static void click(WidgetRef ref) {
    if (_sound(ref)) SystemSound.play(SystemSoundType.click);
  }

  /// Success combo — medium haptic + click.
  static void success(WidgetRef ref) {
    medium(ref);
    click(ref);
  }
}
