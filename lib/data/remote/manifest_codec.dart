import 'package:flutter/foundation.dart';

import '../models/card_model.dart';
import '../models/track_model.dart';

/// Decodes the admin's content manifest (enums as strings) into the existing
/// Dart domain objects. Lives separately from `LearningCard.fromMap` / etc.
/// so SharedPreferences roundtrips (which use int indices) keep working.
class ManifestCodec {
  ManifestCodec._();

  static Difficulty _difficulty(Object? raw) {
    switch (raw) {
      case 'beginner':
        return Difficulty.beginner;
      case 'intermediate':
        return Difficulty.intermediate;
      case 'advanced':
        return Difficulty.advanced;
      default:
        return Difficulty.beginner;
    }
  }

  static CardType _cardType(Object? raw) {
    switch (raw) {
      case 'concept':
        return CardType.concept;
      case 'story':
        return CardType.story;
      case 'analogy':
        return CardType.analogy;
      case 'mythBuster':
        return CardType.mythBuster;
      case 'stat':
        return CardType.stat;
      case 'career':
        return CardType.career;
      case 'quiz':
        return CardType.quiz;
      default:
        return CardType.concept;
    }
  }

  static QuizType _quizType(Object? raw) {
    switch (raw) {
      case 'multipleChoice':
        return QuizType.multipleChoice;
      case 'trueFalse':
        return QuizType.trueFalse;
      case 'fillBlank':
        return QuizType.fillBlank;
      default:
        return QuizType.multipleChoice;
    }
  }

  static LearningCard cardFromJson(Map<String, dynamic> m) {
    return LearningCard(
      id: m['id'] as String,
      trackId: m['trackId'] as String,
      topicTag: m['topicTag'] as String,
      title: m['title'] as String,
      explanation: m['explanation'] as String,
      emoji: m['emoji'] as String,
      takeaway: m['takeaway'] as String,
      difficulty: _difficulty(m['difficulty']),
      type: _cardType(m['type']),
      xpReward: (m['xpReward'] as num?)?.toInt() ?? 10,
      expandedContent: m['expandedContent'] as String?,
      relatedCardIds:
          List<String>.from(m['relatedCardIds'] as List? ?? const []),
    );
  }

  static LearningTrack trackFromJson(Map<String, dynamic> m) {
    final cardIds = List<String>.from(m['cardIds'] as List? ?? const []);
    return LearningTrack(
      id: m['id'] as String,
      emoji: m['emoji'] as String,
      name: m['name'] as String,
      description: m['description'] as String,
      cardIds: cardIds,
      level: _difficulty(m['level']),
      isPremium: (m['isPremium'] as bool?) ?? false,
      totalCards: (m['totalCards'] as num?)?.toInt() ?? cardIds.length,
    );
  }

  static QuizQuestion quizFromJson(Map<String, dynamic> m) {
    return QuizQuestion(
      id: m['id'] as String,
      parentCardId: m['parentCardId'] as String,
      quizType: _quizType(m['quizType']),
      question: m['question'] as String,
      options: List<String>.from(m['options'] as List? ?? const []),
      correctIndex: (m['correctIndex'] as num?)?.toInt() ?? 0,
      explanation: m['explanation'] as String,
      xpReward: (m['xpReward'] as num?)?.toInt() ?? 30,
    );
  }

  /// Decodes each map in [raw], skipping (and logging) malformed entries so
  /// one bad row can't reject the whole manifest and freeze content updates.
  static List<T> _decodeEach<T>(
    Object? raw,
    T Function(Map<String, dynamic>) decode,
  ) {
    final out = <T>[];
    for (final m in (raw as List? ?? const []).whereType<Map<String, dynamic>>()) {
      try {
        out.add(decode(m));
      } catch (e) {
        debugPrint('ManifestCodec: skipping malformed item ${m['id']}: $e');
      }
    }
    return List.unmodifiable(out);
  }

  /// Decodes a full manifest payload into the three lists the app cares
  /// about. Returns nulls-safe: missing sections default to empty lists.
  static ManifestPayload decodeManifest(Map<String, dynamic> json) {
    final tracks = _decodeEach(json['tracks'], trackFromJson);
    final cards = _decodeEach(json['cards'], cardFromJson);
    final quizzes = _decodeEach(json['quizzes'], quizFromJson);
    final version = (json['version'] as num?)?.toInt() ?? 0;
    return ManifestPayload(
      version: version,
      cards: cards,
      tracks: tracks,
      quizzes: quizzes,
    );
  }
}

class ManifestPayload {
  final int version;
  final List<LearningCard> cards;
  final List<LearningTrack> tracks;
  final List<QuizQuestion> quizzes;

  const ManifestPayload({
    required this.version,
    required this.cards,
    required this.tracks,
    required this.quizzes,
  });
}
