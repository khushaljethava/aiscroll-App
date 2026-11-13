import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/user_model.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class GamificationState {
  final int pendingXP;
  final bool showLevelUp;
  final int newLevel;
  final String? newBadgeId;
  final bool showBadge;

  const GamificationState({
    this.pendingXP = 0,
    this.showLevelUp = false,
    this.newLevel = 1,
    this.newBadgeId,
    this.showBadge = false,
  });

  GamificationState copyWith({
    int? pendingXP,
    bool? showLevelUp,
    int? newLevel,
    String? newBadgeId,
    bool? showBadge,
  }) {
    return GamificationState(
      pendingXP: pendingXP ?? this.pendingXP,
      showLevelUp: showLevelUp ?? this.showLevelUp,
      newLevel: newLevel ?? this.newLevel,
      newBadgeId: newBadgeId ?? this.newBadgeId,
      showBadge: showBadge ?? this.showBadge,
    );
  }
}

// ---------------------------------------------------------------------------
// Badge definitions
// ---------------------------------------------------------------------------

class BadgeDefinitions {
  BadgeDefinitions._();

  static const allBadges = [
    UserBadge(
      id: 'first_flame',
      emoji: '🔥',
      name: 'First Flame',
      description: 'Complete Day 1',
      rarity: BadgeRarity.common,
    ),
    UserBadge(
      id: 'deep_thinker',
      emoji: '🧠',
      name: 'Deep Thinker',
      description: 'Read expanded view on 20 cards',
      rarity: BadgeRarity.uncommon,
    ),
    UserBadge(
      id: 'quiz_ace',
      emoji: '⚡',
      name: 'Quiz Ace',
      description: 'Pass 10 quizzes',
      rarity: BadgeRarity.uncommon,
    ),
    UserBadge(
      id: 'week_warrior',
      emoji: '📅',
      name: 'Week Warrior',
      description: '7-day streak',
      rarity: BadgeRarity.common,
    ),
    UserBadge(
      id: 'month_master',
      emoji: '🚀',
      name: 'Month Master',
      description: '30-day streak',
      rarity: BadgeRarity.rare,
    ),
    UserBadge(
      id: 'track_legend',
      emoji: '🌟',
      name: 'Track Legend',
      description: 'Complete all cards in any track',
      rarity: BadgeRarity.rare,
    ),
    UserBadge(
      id: 'sharing_caring',
      emoji: '🤝',
      name: 'Sharing is Caring',
      description: 'Share 10 cards externally',
      rarity: BadgeRarity.common,
    ),
    UserBadge(
      id: 'grandmaster',
      emoji: '🏆',
      name: 'AI Grandmaster',
      description: 'Reach the top level (16)',
      rarity: BadgeRarity.legendary,
    ),
  ];

  static UserBadge? findById(String id) {
    try {
      return allBadges.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class GamificationNotifier extends StateNotifier<GamificationState> {
  GamificationNotifier() : super(const GamificationState());

  void triggerXP(int amount) {
    state = state.copyWith(pendingXP: amount);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        state = state.copyWith(pendingXP: 0);
      }
    });
  }

  void triggerLevelUp(int level) {
    state = state.copyWith(showLevelUp: true, newLevel: level);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        state = state.copyWith(showLevelUp: false);
      }
    });
  }

  void triggerBadge(String badgeId) {
    state = state.copyWith(showBadge: true, newBadgeId: badgeId);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        state = state.copyWith(showBadge: false, newBadgeId: null);
      }
    });
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final gamificationProvider =
    StateNotifierProvider<GamificationNotifier, GamificationState>(
  (ref) => GamificationNotifier(),
);
