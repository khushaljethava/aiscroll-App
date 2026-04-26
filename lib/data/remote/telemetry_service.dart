import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../local/preferences_service.dart';

/// Fire-and-forget event pipeline — never throws, never blocks the UI.
///
/// Behavior:
///   - Events are appended to an in-memory queue and flushed to the admin
///     every [flushInterval] OR when the queue hits [flushBatchSize].
///   - On process exit / app background, `flush(force: true)` is called by
///     the app lifecycle owner.
///   - When offline or the admin returns non-2xx, events are persisted to
///     SharedPreferences so they survive a cold restart.
///   - When no admin URL is configured, the service is a no-op — safe to
///     ship builds without a backend.
///
/// Set base URL via:
///   flutter run --dart-define=ADMIN_API_URL=http://10.0.2.2:3000
class TelemetryService {
  TelemetryService({Dio? dio, PreferencesService? prefs})
      : _dio = dio ?? Dio(),
        _prefs = prefs ?? PreferencesService.instance,
        _sessionId = const Uuid().v4() {
    _restorePending();
    _startFlushTimer();
  }

  final Dio _dio;
  final PreferencesService _prefs;
  final String _sessionId;

  // Raw env value; [_baseUrl] strips a trailing slash so the
  // `/api/events/ingest` composition is canonical.
  static const _rawBaseUrl = String.fromEnvironment('ADMIN_API_URL');
  static const flushInterval = Duration(seconds: 30);
  static const flushBatchSize = 20;
  static const maxQueueSize = 500; // hard cap to avoid unbounded growth

  static String get _baseUrl => _rawBaseUrl.endsWith('/')
      ? _rawBaseUrl.substring(0, _rawBaseUrl.length - 1)
      : _rawBaseUrl;

  final List<Map<String, dynamic>> _queue = [];
  Timer? _timer;
  bool _flushing = false;

  bool get isConfigured => _rawBaseUrl.isNotEmpty;
  String get sessionId => _sessionId;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Enqueues an event. Cheap + sync — safe to call from StateNotifier
  /// methods. Never throws.
  void log(
    String name, {
    required String guestId,
    String? userId,
    Map<String, Object?> props = const {},
  }) {
    if (!isConfigured) return; // build has no backend — drop silently
    try {
      final event = <String, dynamic>{
        'id': const Uuid().v4(),
        'name': name,
        'userId': userId,
        'guestId': guestId,
        'sessionId': _sessionId,
        'ts': DateTime.now().toUtc().toIso8601String(),
        'props': props,
      };
      _queue.add(event);
      if (_queue.length >= maxQueueSize) {
        _queue.removeRange(0, _queue.length - maxQueueSize); // trim oldest
      }
      if (_queue.length >= flushBatchSize) {
        // Kick a flush, but don't await.
        unawaited(flush());
      }
    } catch (e) {
      // Never let telemetry kill a user action.
      debugPrint('TelemetryService.log failed silently: $e');
    }
  }

  /// Sends whatever is queued right now. Safe to call repeatedly; guards
  /// against concurrent flushes. Pass [force] to ignore the empty-queue
  /// shortcut when shutting down.
  Future<void> flush({bool force = false}) async {
    if (!isConfigured) return;
    if (_flushing) return;
    if (_queue.isEmpty && !force) return;
    _flushing = true;
    final batch = List<Map<String, dynamic>>.from(_queue);
    try {
      final response = await _dio.post<dynamic>(
        '$_baseUrl/api/events/ingest',
        data: {'events': batch},
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        // Accepted — drop the events we just sent (batch may be a prefix
        // of the queue if new events arrived mid-flight).
        _queue.removeRange(0, batch.length.clamp(0, _queue.length));
        await _persistPending();
      } else {
        // 4xx — admin rejected the payload. Log and drop so we don't
        // replay a poison batch forever.
        debugPrint(
          'TelemetryService: admin rejected batch '
          '(HTTP ${response.statusCode}); dropping ${batch.length} events.',
        );
        _queue.removeRange(0, batch.length.clamp(0, _queue.length));
        await _persistPending();
      }
    } on DioException catch (e) {
      // Network failure — keep the events and persist them for next time.
      debugPrint('TelemetryService: flush failed (${e.type.name}); queued.');
      await _persistPending();
    } catch (e) {
      debugPrint('TelemetryService: unexpected flush error: $e');
      await _persistPending();
    } finally {
      _flushing = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    // Best-effort final flush. Fire-and-forget; a dispose shouldn't await.
    unawaited(flush(force: true));
  }

  // ---------------------------------------------------------------------------
  // Convenience wrappers — keep call sites terse and the event names
  // consistent with the schema in .claude/plan/...md §3.5.
  // ---------------------------------------------------------------------------

  void logCardViewed(
    String cardId, {
    required String guestId,
    String? userId,
    int dwellMs = 0,
    bool wasDue = false,
  }) =>
      log('card_viewed',
          guestId: guestId,
          userId: userId,
          props: {'cardId': cardId, 'dwellMs': dwellMs, 'wasDue': wasDue});

  void logCardLearned(String cardId,
          {required String guestId, String? userId}) =>
      log('card_learned_swipe',
          guestId: guestId, userId: userId, props: {'cardId': cardId});

  void logQuizAnswered(
    String quizId, {
    required String cardId,
    required bool correct,
    required int selected,
    required String guestId,
    String? userId,
  }) =>
      log('quiz_answered', guestId: guestId, userId: userId, props: {
        'quizId': quizId,
        'cardId': cardId,
        'correct': correct,
        'selected': selected,
      });

  void logXp(int amount, String source,
          {required String guestId, String? userId}) =>
      log('xp_awarded',
          guestId: guestId,
          userId: userId,
          props: {'amount': amount, 'source': source});

  void logStreakDay(int streak, {required String guestId, String? userId}) =>
      log('streak_day',
          guestId: guestId, userId: userId, props: {'streak': streak});

  void logSessionStart({required String guestId, String? userId}) =>
      log('session_start', guestId: guestId, userId: userId);

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  void _restorePending() {
    final raw = _prefs.loadPendingEventsJsonSync();
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List;
      for (final e in list) {
        if (e is Map) _queue.add(Map<String, dynamic>.from(e));
      }
      if (_queue.length > maxQueueSize) {
        _queue.removeRange(0, _queue.length - maxQueueSize);
      }
    } catch (_) {
      // ignore: discarded_futures
      _prefs.clearPendingEvents();
    }
  }

  Future<void> _persistPending() async {
    if (_queue.isEmpty) {
      await _prefs.clearPendingEvents();
    } else {
      await _prefs.savePendingEventsJson(jsonEncode(_queue));
    }
  }

  void _startFlushTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(flushInterval, (_) => unawaited(flush()));
  }
}
