import '../../core/constants/topic_constants.dart';

enum Difficulty { beginner, intermediate, advanced }

enum CardType { concept, story, analogy, mythBuster, stat, career, quiz }

class LearningCard {
  final String id;
  final String trackId;
  final String topicTag;
  final String title;
  final String explanation;
  final String emoji;
  final String takeaway;
  final Difficulty difficulty;
  final CardType type;
  final int xpReward;
  final String? expandedContent;
  final List<String> relatedCardIds;

  const LearningCard({
    required this.id,
    required this.trackId,
    required this.topicTag,
    required this.title,
    required this.explanation,
    required this.emoji,
    required this.takeaway,
    required this.difficulty,
    this.type = CardType.concept,
    this.xpReward = 10,
    this.expandedContent,
    this.relatedCardIds = const [],
  });

  /// Canonical onboarding topic key derived from [topicTag]. Used by the
  /// feed ranker to match against `UserProfile.selectedTopics`.
  String get topicKey => TopicKeys.fromTag(topicTag);

  Map<String, dynamic> toMap() => {
    'id': id,
    'trackId': trackId,
    'topicTag': topicTag,
    'title': title,
    'explanation': explanation,
    'emoji': emoji,
    'takeaway': takeaway,
    'difficulty': difficulty.index,
    'type': type.index,
    'xpReward': xpReward,
    'expandedContent': expandedContent,
    'relatedCardIds': relatedCardIds,
  };

  factory LearningCard.fromMap(Map<String, dynamic> m) => LearningCard(
    id: m['id'] as String,
    trackId: m['trackId'] as String,
    topicTag: m['topicTag'] as String,
    title: m['title'] as String,
    explanation: m['explanation'] as String,
    emoji: m['emoji'] as String,
    takeaway: m['takeaway'] as String,
    difficulty: Difficulty.values[m['difficulty'] as int],
    type: CardType.values[m['type'] as int],
    xpReward: m['xpReward'] as int,
    expandedContent: m['expandedContent'] as String?,
    relatedCardIds:
        List<String>.from(m['relatedCardIds'] as List? ?? const []),
  );

  LearningCard copyWith({
    String? topicTag,
    String? title,
    String? explanation,
    String? emoji,
    String? takeaway,
    Difficulty? difficulty,
    CardType? type,
    int? xpReward,
    String? expandedContent,
    List<String>? relatedCardIds,
  }) => LearningCard(
    id: id,
    trackId: trackId,
    topicTag: topicTag ?? this.topicTag,
    title: title ?? this.title,
    explanation: explanation ?? this.explanation,
    emoji: emoji ?? this.emoji,
    takeaway: takeaway ?? this.takeaway,
    difficulty: difficulty ?? this.difficulty,
    type: type ?? this.type,
    xpReward: xpReward ?? this.xpReward,
    expandedContent: expandedContent ?? this.expandedContent,
    relatedCardIds: relatedCardIds ?? this.relatedCardIds,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is LearningCard && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

enum QuizType { multipleChoice, trueFalse, fillBlank }

class QuizQuestion {
  final String id;
  final String parentCardId;
  final QuizType quizType;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final int xpReward;

  const QuizQuestion({
    required this.id,
    required this.parentCardId,
    required this.quizType,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    this.xpReward = 30,
  });

  bool isCorrect(int selectedIndex) => selectedIndex == correctIndex;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is QuizQuestion && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
