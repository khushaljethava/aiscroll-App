enum QuestType { readCards, passQuiz, learnNew, shareCard }

class DailyQuest {
  final String id;
  final String title;
  final String description;
  final QuestType type;
  final int targetCount;
  final int currentCount;
  final int xpReward;
  final bool isCompleted;

  const DailyQuest({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.targetCount,
    this.currentCount = 0,
    required this.xpReward,
    this.isCompleted = false,
  });

  double get progress =>
      targetCount > 0 ? (currentCount / targetCount).clamp(0.0, 1.0) : 0.0;

  bool get canComplete => currentCount >= targetCount && !isCompleted;

  DailyQuest copyWith({int? currentCount, bool? isCompleted}) => DailyQuest(
    id: id,
    title: title,
    description: description,
    type: type,
    targetCount: targetCount,
    currentCount: currentCount ?? this.currentCount,
    xpReward: xpReward,
    isCompleted: isCompleted ?? this.isCompleted,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'type': type.index,
    'targetCount': targetCount,
    'currentCount': currentCount,
    'xpReward': xpReward,
    'isCompleted': isCompleted,
  };

  factory DailyQuest.fromMap(Map<String, dynamic> m) => DailyQuest(
    id: m['id'] as String,
    title: m['title'] as String,
    description: m['description'] as String,
    type: QuestType.values[m['type'] as int],
    targetCount: m['targetCount'] as int,
    currentCount: (m['currentCount'] as int?) ?? 0,
    xpReward: m['xpReward'] as int,
    isCompleted: (m['isCompleted'] as bool?) ?? false,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DailyQuest && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Pre-defined daily quest templates that get instantiated fresh each day.
class QuestTemplates {
  QuestTemplates._();

  static List<DailyQuest> get defaultDailyQuests => [
    const DailyQuest(
      id: 'dq_read_5',
      title: 'Knowledge Seeker',
      description: 'Read 5 AI cards today',
      type: QuestType.readCards,
      targetCount: 5,
      xpReward: 50,
    ),
    const DailyQuest(
      id: 'dq_quiz_2',
      title: 'Quiz Whiz',
      description: 'Pass 2 quizzes',
      type: QuestType.passQuiz,
      targetCount: 2,
      xpReward: 60,
    ),
    const DailyQuest(
      id: 'dq_learn_3',
      title: 'Deep Learner',
      description: 'Mark 3 cards as Learned',
      type: QuestType.learnNew,
      targetCount: 3,
      xpReward: 50,
    ),
    const DailyQuest(
      id: 'dq_share_1',
      title: 'Spread the Knowledge',
      description: 'Share 1 card with a friend',
      type: QuestType.shareCard,
      targetCount: 1,
      xpReward: 40,
    ),
  ];
}
