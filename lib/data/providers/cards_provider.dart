import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/card_model.dart';
import '../models/track_model.dart';
import 'content_provider.dart';

// ---------------------------------------------------------------------------
// Raw data providers
//
// These providers always read from `contentProvider`, which hydrates from
// cached admin manifest data and refreshes from the admin API on launch.
// ---------------------------------------------------------------------------

final allCardsProvider = Provider<List<LearningCard>>((ref) {
  return ref.watch(contentProvider.select((s) => s.cards));
});

final allTracksProvider = Provider<List<LearningTrack>>((ref) {
  return ref.watch(contentProvider.select((s) => s.tracks));
});

final allQuizzesProvider = Provider<List<QuizQuestion>>((ref) {
  return ref.watch(contentProvider.select((s) => s.quizzes));
});

// ---------------------------------------------------------------------------
// Track look-up by id
// ---------------------------------------------------------------------------

final trackByIdProvider = Provider.family<LearningTrack?, String>((ref, id) {
  final tracks = ref.watch(allTracksProvider);
  for (final t in tracks) {
    if (t.id == id) return t;
  }
  // Unlike the old `firstWhere` that threw, we return null so the UI can
  // render a "track not found" state when a manifest update drops a track
  // that was in a user's bookmarks or deep link.
  return null;
});

// ---------------------------------------------------------------------------
// Cards for a specific track
// ---------------------------------------------------------------------------

final trackCardsProvider =
    Provider.family<List<LearningCard>, String>((ref, trackId) {
  final all = ref.watch(allCardsProvider);
  return all.where((c) => c.trackId == trackId).toList();
});

// ---------------------------------------------------------------------------
// Cards filtered by difficulty
// ---------------------------------------------------------------------------

final cardsByDifficultyProvider =
    Provider.family<List<LearningCard>, Difficulty>((ref, difficulty) {
  return ref
      .watch(allCardsProvider)
      .where((c) => c.difficulty == difficulty)
      .toList();
});

// ---------------------------------------------------------------------------
// Quizzes for a specific parent card
// ---------------------------------------------------------------------------

final quizzesForCardProvider =
    Provider.family<List<QuizQuestion>, String>((ref, cardId) {
  return ref
      .watch(allQuizzesProvider)
      .where((q) => q.parentCardId == cardId)
      .toList();
});
