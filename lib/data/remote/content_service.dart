import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../local/preferences_service.dart';
import '../models/card_model.dart';
import '../models/track_model.dart';
import 'manifest_codec.dart';

/// Pulls content from the admin panel.
///
/// Layered fallback:
///   1. Cached manifest JSON in SharedPreferences (hydrated synchronously
///      during [loadCached]) — present from the second launch onward.
///   2. Network fetch (`refreshFromNetwork`) — happens on every app launch;
///      sends `?min_version=N` so the admin returns 304 when nothing changed.
///
/// Set [_baseUrl] via:
///   flutter run --dart-define=ADMIN_API_URL=http://10.0.2.2:3000
/// (10.0.2.2 = host loopback from Android emulator; iOS uses localhost.)
///
/// When unset, the service skips network and stays on cached data.
class ContentService {
  ContentService({Dio? dio, PreferencesService? prefs})
      : _dio = dio ?? Dio(),
        _prefs = prefs ?? PreferencesService.instance;

  final Dio _dio;
  final PreferencesService _prefs;

  // Raw env value; [_baseUrl] strips a trailing slash so URLs compose
  // cleanly regardless of how the build flag is supplied.
  static const _rawBaseUrl = String.fromEnvironment('ADMIN_API_URL');

  static String get _baseUrl => _rawBaseUrl.endsWith('/')
      ? _rawBaseUrl.substring(0, _rawBaseUrl.length - 1)
      : _rawBaseUrl;

  bool get isAdminConfigured => _rawBaseUrl.isNotEmpty;

  // Current payload. Starts empty until cache or admin manifest is loaded.
  List<LearningCard> _cards = const [];
  List<LearningTrack> _tracks = const [];
  List<QuizQuestion> _quizzes = const [];
  int _version = 0;
  DateTime? _lastFetchedAt;
  String? _lastError;

  List<LearningCard> get cards => _cards;
  List<LearningTrack> get tracks => _tracks;
  List<QuizQuestion> get quizzes => _quizzes;
  int get version => _version;
  DateTime? get lastFetchedAt => _lastFetchedAt;
  String? get lastError => _lastError;

  /// Reads the cached manifest (if any) and hot-swaps the in-memory lists.
  /// Call once at app boot *before* anything watches content providers.
  Future<void> loadCached() async {
    final raw = _prefs.loadContentManifestJsonSync();
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _applyPayload(ManifestCodec.decodeManifest(json));
    } catch (e) {
      // Corrupt cache — drop it so the next launch doesn't keep retrying
      // the same bad blob.
      debugPrint('ContentService: cached manifest was corrupt ($e); dropping.');
      await _prefs.clearContentManifest();
    }
  }

  /// Hits the admin and, on success, replaces the in-memory payload and
  /// persists the fresh JSON. On 304, noop. On any failure, leaves the
  /// current payload untouched so the UI never regresses.
  ///
  /// Returns true when content was updated; false on 304 or error.
  Future<bool> refreshFromNetwork() async {
    if (!isAdminConfigured) {
      _lastError = 'ADMIN_API_URL not configured; staying on cached data.';
      return false;
    }
    try {
      final response = await _dio.get<dynamic>(
        '$_baseUrl/api/content/manifest',
        queryParameters: _version > 0 ? {'min_version': _version} : null,
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          // 401 must surface as a DioException so the auth interceptor
          // refreshes the token and retries.
          validateStatus: (s) => s != null && s < 500 && s != 401,
        ),
      );

      if (response.statusCode == 304) {
        _lastFetchedAt = DateTime.now();
        _lastError = null;
        return false;
      }

      if (response.statusCode != 200) {
        _lastError =
            'Manifest fetch failed: HTTP ${response.statusCode}';
        return false;
      }

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        _lastError = 'Manifest response was not a JSON object';
        return false;
      }

      final payload = ManifestCodec.decodeManifest(data);
      _applyPayload(payload);
      await _prefs.saveContentManifestJson(jsonEncode(data));
      _lastFetchedAt = DateTime.now();
      _lastError = null;
      return true;
    } on DioException catch (e) {
      _lastError = 'Network error: ${e.message ?? e.type.name}';
      return false;
    } catch (e) {
      _lastError = 'Unexpected error: $e';
      return false;
    }
  }

  void _applyPayload(ManifestPayload payload) {
    _version = payload.version;
    _cards = payload.cards;
    _tracks = payload.tracks;
    _quizzes = payload.quizzes;
  }
}
