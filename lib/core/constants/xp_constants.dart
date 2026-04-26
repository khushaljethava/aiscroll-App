class XPConstants {
  XPConstants._();

  static const int readCard = 10;
  static const int learnedSwipe = 20;
  static const int quizPass = 30;
  static const int dailyQuest = 50;
  static const int dailyStreakBase = 25;
  static const int trackComplete = 200;
  static const int firstCardBonus = 40;

  static const List<int> levelThresholds = [
    0, 200, 500, 800, 1200, 1800, 2400, 3000, 4500, 6000,
    7000, 9000, 12000, 15000, 18000, 20000,
  ];

  static const List<String> levelTitles = [
    'AI Newbie',
    'Prompt Explorer',
    'Data Apprentice',
    'Model Thinker',
    'Model Trainer',
    'Algorithm Adept',
    'Data Scientist',
    'Neural Architect',
    'Deep Learner',
    'AI Researcher',
    'AI Engineer',
    'ML Master',
    'AI Expert',
    'Neural Master',
    'AI Visionary',
    'AI Grandmaster',
  ];

  static const List<String> levelEmojis = [
    '🌱', '🔍', '📊', '💡', '🏋️', '⚡', '🔬', '🧠',
    '🌊', '🎯', '⚙️', '🏆', '🌟', '💎', '🚀', '🏆',
  ];

  static int getLevelFromXP(int xp) {
    for (int i = levelThresholds.length - 1; i >= 0; i--) {
      if (xp >= levelThresholds[i]) return i + 1;
    }
    return 1;
  }

  static String getTitleFromXP(int xp) {
    final level = getLevelFromXP(xp);
    return levelTitles[level - 1];
  }

  static String getEmojiFromXP(int xp) {
    final level = getLevelFromXP(xp);
    return levelEmojis[level - 1];
  }

  static int xpForNextLevel(int xp) {
    final level = getLevelFromXP(xp);
    if (level >= levelThresholds.length) return 0;
    return levelThresholds[level] - xp;
  }

  static double levelProgress(int xp) {
    final level = getLevelFromXP(xp);
    if (level >= levelThresholds.length) return 1.0;
    final currentLevelXP = levelThresholds[level - 1];
    final nextLevelXP = levelThresholds[level];
    return (xp - currentLevelXP) / (nextLevelXP - currentLevelXP);
  }
}
