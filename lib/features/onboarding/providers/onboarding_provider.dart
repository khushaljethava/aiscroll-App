import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/providers/user_provider.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class OnboardingState {
  final String persona;
  final double knowledgeLevel;
  final List<String> selectedTopics;
  final int dailyGoal;

  const OnboardingState({
    this.persona = 'curious',
    this.knowledgeLevel = 0.0,
    this.selectedTopics = const [],
    this.dailyGoal = 10,
  });

  OnboardingState copyWith({
    String? persona,
    double? knowledgeLevel,
    List<String>? selectedTopics,
    int? dailyGoal,
  }) {
    return OnboardingState(
      persona: persona ?? this.persona,
      knowledgeLevel: knowledgeLevel ?? this.knowledgeLevel,
      selectedTopics: selectedTopics ?? this.selectedTopics,
      dailyGoal: dailyGoal ?? this.dailyGoal,
    );
  }
}

// ---------------------------------------------------------------------------
// Knowledge level helpers
// ---------------------------------------------------------------------------

const _knowledgeLevelLabels = ['Nothing', 'A Little', 'Quite a Bit', 'A Lot'];
const _knowledgeLevelKeys = ['nothing', 'a_little', 'quite_a_bit', 'a_lot'];

String knowledgeLabelFromValue(double value) {
  final index = value.round().clamp(0, 3);
  return _knowledgeLevelLabels[index];
}

String knowledgeKeyFromValue(double value) {
  final index = value.round().clamp(0, 3);
  return _knowledgeLevelKeys[index];
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier(this._ref) : super(const OnboardingState());

  final Ref _ref;

  void setPersona(String persona) {
    state = state.copyWith(persona: persona);
  }

  void setKnowledgeLevel(double level) {
    state = state.copyWith(knowledgeLevel: level.clamp(0.0, 3.0));
  }

  void toggleTopic(String topic) {
    final current = List<String>.from(state.selectedTopics);
    if (current.contains(topic)) {
      current.remove(topic);
    } else {
      current.add(topic);
    }
    state = state.copyWith(selectedTopics: List.unmodifiable(current));
  }

  void setDailyGoal(int goal) {
    state = state.copyWith(dailyGoal: goal);
  }

  Future<void> completeOnboarding({bool stayGuest = false}) async {
    final userNotifier = _ref.read(userProvider.notifier);
    await userNotifier.setOnboardingData(
      persona: state.persona,
      knowledgeLevel: knowledgeKeyFromValue(state.knowledgeLevel),
      topics: state.selectedTopics,
      dailyGoal: state.dailyGoal,
      stayGuest: stayGuest,
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>(
  (ref) => OnboardingNotifier(ref),
);
