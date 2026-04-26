import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/card_model.dart';
import '../../../data/providers/cards_provider.dart';

/// Resolves the boss-quiz question pool for a given track.
///
/// Pulls `QuizQuestion`s whose `parentCardId` belongs to the track's cards,
/// shuffles, and returns up to 7 — matching the plan's 5-7 question spec.
/// Returns fewer if the track has a thin pool; the screen decides what to
/// render when `< 3`.
final bossQuizPoolProvider =
    Provider.family<List<QuizQuestion>, String>((ref, trackId) {
  final allTracks = ref.watch(allTracksProvider);
  final track = allTracks.firstWhere(
    (t) => t.id == trackId,
    orElse: () => throw StateError('Track "$trackId" not in seed'),
  );
  final trackCardIds = track.cardIds.toSet();
  final pool = ref
      .watch(allQuizzesProvider)
      .where((q) => trackCardIds.contains(q.parentCardId))
      .toList();
  pool.shuffle();
  return pool.take(7).toList(growable: false);
});

/// Minimum questions required to run a valid boss quiz. Below this the
/// button is hidden and the screen shows a "not enough content" message.
const int kBossQuizMinimumQuestions = 3;
