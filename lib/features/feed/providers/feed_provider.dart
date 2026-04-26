import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// State
//
// Tracks in-memory feed-screen state that doesn't need to persist across
// launches: which card is currently visible and which cards are being
// dwell-timed. Persistent state (bookmarks, read/learned status) lives in
// [UserProfile] via `userProvider`.
// ---------------------------------------------------------------------------

class FeedState {
  final int currentIndex;
  final Map<String, bool> dwellTimerActive;

  const FeedState({
    this.currentIndex = 0,
    this.dwellTimerActive = const {},
  });

  FeedState copyWith({
    int? currentIndex,
    Map<String, bool>? dwellTimerActive,
  }) {
    return FeedState(
      currentIndex: currentIndex ?? this.currentIndex,
      dwellTimerActive: dwellTimerActive ?? this.dwellTimerActive,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class FeedNotifier extends StateNotifier<FeedState> {
  FeedNotifier() : super(const FeedState());

  final Map<String, DateTime> _dwellStartTimes = {};

  void setCurrentIndex(int index) {
    state = state.copyWith(currentIndex: index);
  }

  void startDwell(String cardId) {
    _dwellStartTimes[cardId] = DateTime.now();
    final active = Map<String, bool>.from(state.dwellTimerActive);
    active[cardId] = true;
    state = state.copyWith(dwellTimerActive: active);
  }

  /// Returns milliseconds spent on the card, or 0 if no timer was started.
  int endDwell(String cardId) {
    final start = _dwellStartTimes.remove(cardId);
    final active = Map<String, bool>.from(state.dwellTimerActive);
    active.remove(cardId);
    state = state.copyWith(dwellTimerActive: active);
    if (start == null) return 0;
    return DateTime.now().difference(start).inMilliseconds;
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final feedProvider = StateNotifierProvider<FeedNotifier, FeedState>(
  (ref) => FeedNotifier(),
);

final currentFeedIndexProvider = StateProvider<int>((ref) => 0);
