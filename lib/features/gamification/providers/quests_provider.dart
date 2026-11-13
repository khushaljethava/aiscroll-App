import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/xp_constants.dart';
import '../../../data/local/preferences_service.dart';
import '../../../data/models/quest_model.dart';
import '../../../data/providers/user_provider.dart';

/// Notifier that owns the active set of daily quests. Quests reset at
/// midnight (regenerated from `QuestTemplates.defaultDailyQuests`) and
/// persist their `currentCount`/`isCompleted` through the day.
class QuestsNotifier extends StateNotifier<List<DailyQuest>> {
  QuestsNotifier(this._ref) : super(QuestTemplates.defaultDailyQuests);

  final Ref _ref;
  PreferencesService get _prefs => PreferencesService.instance;

  /// Calendar day the current [state] belongs to.
  DateTime _day = DateTime.now();

  /// Loads quests for today, regenerating from templates on a new calendar
  /// day. Should be called on app start.
  Future<void> load() async {
    final today = DateTime.now();
    _day = today;
    final saved = await _prefs.loadDailyQuestsForToday(today);
    if (saved != null && saved.isNotEmpty) {
      state = saved;
    } else {
      state = QuestTemplates.defaultDailyQuests;
      await _prefs.saveDailyQuests(state, today);
    }
  }

  /// Records [delta] events of the given [type] against any matching active
  /// quest. Awards XP automatically when a quest crosses its target.
  Future<void> recordEvent(QuestType type, {int delta = 1}) async {
    if (delta <= 0) return;
    // App left open past midnight: start today's fresh quest set instead
    // of writing yesterday's progress under today's date.
    final now = DateTime.now();
    if (now.year != _day.year ||
        now.month != _day.month ||
        now.day != _day.day) {
      _day = now;
      state = QuestTemplates.defaultDailyQuests;
    }

    var awardedXP = 0;
    final updated = state.map((q) {
      if (q.type != type || q.isCompleted) return q;

      final newCount = q.currentCount + delta;
      final reachedTarget = newCount >= q.targetCount;
      if (reachedTarget) awardedXP += q.xpReward;

      return q.copyWith(
        currentCount: newCount > q.targetCount ? q.targetCount : newCount,
        isCompleted: reachedTarget,
      );
    }).toList();

    state = updated;
    await _prefs.saveDailyQuests(state, now);

    if (awardedXP > 0) {
      await _ref.read(userProvider.notifier).addXP(awardedXP);
    }
  }
}

final questsProvider =
    StateNotifierProvider<QuestsNotifier, List<DailyQuest>>((ref) {
  return QuestsNotifier(ref);
});

/// Convenience: total XP currently locked behind unfinished quests today.
final pendingQuestXPProvider = Provider<int>((ref) {
  return ref.watch(questsProvider).where((q) => !q.isCompleted).fold<int>(
        0,
        (sum, q) => sum + q.xpReward,
      );
});

// Re-export the XP source-of-truth for callers that want to know the XP
// reward for a specific quest type without looking at the active list.
int defaultXPForQuestType(QuestType type) {
  switch (type) {
    case QuestType.readCards:
      return XPConstants.dailyQuest;
    case QuestType.passQuiz:
      return 60;
    case QuestType.learnNew:
      return 50;
    case QuestType.shareCard:
      return 40;
  }
}
