import 'dart:async';

import 'package:flutter/foundation.dart';

/// Lightweight foreground scheduler that triggers a periodic refresh while
/// the app is in the foreground.
///
/// Generic over the data source — instantiated once per provider that needs
/// auto-sync (currently news + content/tracks). Pass:
///  - [label] — human-readable identifier used in debug logs.
///  - [refresh] — the actual fetch (must not throw; should swallow + log).
///  - [lastSyncedAt] — read-only accessor for the last successful sync time;
///    used by [refreshIfStale] to decide whether to refresh on resume.
///  - [interval] — cadence for the periodic timer.
///  - [staleThreshold] — minimum age of cache before [refreshIfStale] does a
///    network call. Keep < [interval] so resume-then-tick doesn't double-fire.
///
/// Lifecycle contract:
///  - Call [start] on cold start (after the first manual refresh).
///  - Call [stop] in [AppLifecycleState.paused] so the timer doesn't burn
///    cycles when the app is backgrounded.
///  - Call [refreshIfStale] then [start] on [AppLifecycleState.resumed].
///
/// Background sync when the app is killed is intentionally out-of-scope.
class PeriodicSyncScheduler {
  PeriodicSyncScheduler({
    required this.label,
    required Future<bool> Function() refresh,
    required DateTime? Function() lastSyncedAt,
    required Duration interval,
    required Duration staleThreshold,
  })  : _refresh = refresh,
        _lastSyncedAt = lastSyncedAt,
        _interval = interval,
        _staleThreshold = staleThreshold;

  final String label;
  final Future<bool> Function() _refresh;
  final DateTime? Function() _lastSyncedAt;
  final Duration _interval;
  final Duration _staleThreshold;

  Timer? _timer;
  bool _inFlight = false;

  /// Starts the periodic timer. First tick fires after [_interval] (Timer's
  /// default behaviour — there's no tick at t=0). Idempotent: cancels any
  /// existing timer before creating a new one.
  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _safeRefresh('periodic'));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Call from the app lifecycle observer when the app returns to the
  /// foreground. Fires a refresh only if the cache is older than
  /// [_staleThreshold], so a quick app-switch doesn't spam the server.
  Future<void> refreshIfStale() async {
    final last = _lastSyncedAt();
    final stale = last == null ||
        DateTime.now().difference(last) >= _staleThreshold;
    if (stale) {
      await _safeRefresh('resume');
    }
  }

  Future<void> _safeRefresh(String source) async {
    // Drop overlapping calls — a slow network on a 2-min cadence could
    // otherwise stack fetches indefinitely.
    if (_inFlight) {
      debugPrint(
          'PeriodicSyncScheduler[$label]: $source skipped (in-flight)');
      return;
    }
    _inFlight = true;
    // Confirms in logcat that the timer is actually firing. Without this,
    // "polling never happens" complaints can't be distinguished from
    // "polling happens but server returns the same data".
    debugPrint('PeriodicSyncScheduler[$label]: $source tick @ '
        '${DateTime.now().toIso8601String()}');
    try {
      await _refresh();
    } catch (e) {
      debugPrint('PeriodicSyncScheduler[$label]: $source threw $e');
    } finally {
      _inFlight = false;
    }
  }
}
