import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/srs_model.dart';
import '../../../data/providers/user_provider.dart';

/// Owns the spaced-repetition schedule. Reads from `userProvider.cardReviews`
/// (the persisted source of truth) and writes back through
/// `UserNotifier.updateReviews`. The SRS state surfaces as its own provider
/// so consumers (FeedComposer, ReviewsDueChip, profile stat) can subscribe
/// without watching the entire UserProfile.
class SRSNotifier extends StateNotifier<Map<String, CardReview>> {
  SRSNotifier(this._ref) : super(_ref.read(userProvider).cardReviews) {
    // Keep our state in sync with UserProfile mutations from elsewhere
    // (e.g. UserNotifier.load() seeding migration data).
    _ref.listen<Map<String, CardReview>>(
      userProvider.select((u) => u.cardReviews),
      (_, next) {
        if (!identical(state, next)) {
          state = next;
        }
      },
    );
  }

  final Ref _ref;

  /// Records a review with [quality] (0-5, SM-2 scale) for [cardId] and
  /// pushes the new schedule back into the persisted profile.
  Future<void> recordReview(String cardId, int quality) async {
    final clamped = quality.clamp(0, 5);
    final existing = state[cardId] ?? CardReview.fresh(cardId);
    final updated = existing.afterReview(clamped);
    final next = {...state, cardId: updated};
    state = next;
    await _ref.read(userProvider.notifier).updateReviews(next);
  }

  /// IDs of all cards whose `nextReview` is on or before [today].
  List<String> dueCardIds(DateTime today) {
    return state.entries
        .where((e) => e.value.isDue(today))
        .map((e) => e.key)
        .toList();
  }

  int dueCount(DateTime today) {
    var count = 0;
    for (final r in state.values) {
      if (r.isDue(today)) count++;
    }
    return count;
  }
}

final srsProvider =
    StateNotifierProvider<SRSNotifier, Map<String, CardReview>>((ref) {
  return SRSNotifier(ref);
});

/// Start of today; rebuilds itself at midnight so day-scoped providers
/// (e.g. the due count) don't go stale when the app stays open overnight.
final todayProvider = Provider<DateTime>((ref) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final timer = Timer(
    today.add(const Duration(days: 1)).difference(now),
    ref.invalidateSelf,
  );
  ref.onDispose(timer.cancel);
  return today;
});

/// Reactive due-count for today. Useful in widgets that show a "N due" chip.
final dueReviewCountProvider = Provider<int>((ref) {
  final reviews = ref.watch(srsProvider);
  final start = ref.watch(todayProvider);
  var count = 0;
  for (final r in reviews.values) {
    if (r.isDue(start)) count++;
  }
  return count;
});
