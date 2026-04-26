import 'card_model.dart';

class LearningTrack {
  final String id;
  final String emoji;
  final String name;
  final String description;
  final List<String> cardIds;
  final Difficulty level;
  final bool isPremium;
  final int totalCards;

  const LearningTrack({
    required this.id,
    required this.emoji,
    required this.name,
    required this.description,
    required this.cardIds,
    required this.level,
    this.isPremium = false,
    required this.totalCards,
  });

  int completedCount(List<String> learnedCardIds) =>
      cardIds.where((id) => learnedCardIds.contains(id)).length;

  double progressFor(List<String> learnedCardIds) {
    if (totalCards == 0) return 0;
    return completedCount(learnedCardIds) / totalCards;
  }

  bool isCompleted(List<String> learnedCardIds) =>
      completedCount(learnedCardIds) >= totalCards;

  LearningTrack copyWith({
    String? emoji,
    String? name,
    String? description,
    List<String>? cardIds,
    Difficulty? level,
    bool? isPremium,
    int? totalCards,
  }) => LearningTrack(
    id: id,
    emoji: emoji ?? this.emoji,
    name: name ?? this.name,
    description: description ?? this.description,
    cardIds: cardIds ?? this.cardIds,
    level: level ?? this.level,
    isPremium: isPremium ?? this.isPremium,
    totalCards: totalCards ?? this.totalCards,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is LearningTrack && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
