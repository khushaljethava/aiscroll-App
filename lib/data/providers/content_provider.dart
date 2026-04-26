import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/track_model.dart';
import '../remote/content_service.dart';
import '../remote/periodic_sync_scheduler.dart';
import 'auth_provider.dart';

/// Immutable snapshot of the content the app should render right now.
class ContentState {
  final List<LearningCard> cards;
  final List<LearningTrack> tracks;
  final List<QuizQuestion> quizzes;
  final int version;
  final DateTime? lastFetchedAt;
  final String? lastError;
  final bool refreshing;

  const ContentState({
    required this.cards,
    required this.tracks,
    required this.quizzes,
    required this.version,
    this.lastFetchedAt,
    this.lastError,
    this.refreshing = false,
  });

  ContentState copyWith({
    List<LearningCard>? cards,
    List<LearningTrack>? tracks,
    List<QuizQuestion>? quizzes,
    int? version,
    DateTime? lastFetchedAt,
    Object? lastError = _sentinel,
    bool? refreshing,
  }) =>
      ContentState(
        cards: cards ?? this.cards,
        tracks: tracks ?? this.tracks,
        quizzes: quizzes ?? this.quizzes,
        version: version ?? this.version,
        lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
        lastError: identical(lastError, _sentinel)
            ? this.lastError
            : lastError as String?,
        refreshing: refreshing ?? this.refreshing,
      );

  static const _sentinel = Object();
}

class ContentNotifier extends StateNotifier<ContentState> {
  ContentNotifier(this._service)
      : super(ContentState(
          cards: _service.cards,
          tracks: _service.tracks,
          quizzes: _service.quizzes,
          version: _service.version,
        )) {
    _scheduler = PeriodicSyncScheduler(
      label: 'content',
      refresh: () async {
        await refresh();
        return state.lastError == null;
      },
      lastSyncedAt: () => state.lastFetchedAt,
      // Tracks change much less often than news (cards/quizzes are curated
      // weekly at most), so a longer cadence keeps server load reasonable
      // while still feeling "auto" — bump back down if telemetry shows
      // stale-cache complaints.
      interval: const Duration(minutes: 30),
      // Pull on resume if cache is older than 1 minute.
      staleThreshold: const Duration(minutes: 1),
    );
  }

  final ContentService _service;
  late final PeriodicSyncScheduler _scheduler;

  ContentService get service => _service;
  PeriodicSyncScheduler get scheduler => _scheduler;

  /// Pulls cached JSON from SharedPreferences into memory. Call once at boot.
  Future<void> hydrateFromCache() async {
    await _service.loadCached();
    _syncFromService();
  }

  /// Background refresh — never throws. UI calls this on launch and from
  /// pull-to-refresh in the feed.
  Future<void> refresh() async {
    state = state.copyWith(refreshing: true);
    await _service.refreshFromNetwork();
    _syncFromService();
    state = state.copyWith(refreshing: false);
  }

  void _syncFromService() {
    state = state.copyWith(
      cards: _service.cards,
      tracks: _service.tracks,
      quizzes: _service.quizzes,
      version: _service.version,
      lastFetchedAt: _service.lastFetchedAt,
      lastError: _service.lastError,
    );
  }

  @override
  void dispose() {
    _scheduler.stop();
    super.dispose();
  }
}

final contentServiceProvider = Provider<ContentService>((ref) {
  // Each service owns its own Dio, then opts into the shared auth
  // interceptor via the factory. Keeps the per-request base URL / timeout
  // wiring inside each service file.
  final dio = ref.watch(authedDioFactoryProvider).attach(Dio());
  return ContentService(dio: dio);
});

final contentProvider =
    StateNotifierProvider<ContentNotifier, ContentState>((ref) {
  return ContentNotifier(ref.watch(contentServiceProvider));
});
