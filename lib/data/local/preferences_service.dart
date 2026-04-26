import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quest_model.dart';
import '../models/user_model.dart';

class PreferencesService {
  PreferencesService._();

  static PreferencesService? _instance;
  static SharedPreferences? _prefs;

  /// Bumped on every change that affects router redirects (onboarding flag,
  /// sign-out, profile reset). Provided to GoRouter as `refreshListenable`.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static PreferencesService get instance {
    assert(
      _instance != null,
      'PreferencesService.init() must be called before accessing instance.',
    );
    return _instance!;
  }

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _instance = PreferencesService._();
    await _instance!._migrateLegacyKeys();
  }

  SharedPreferences get _p {
    assert(_prefs != null, 'SharedPreferences not initialised.');
    return _prefs!;
  }

  void _bump() => revision.value = revision.value + 1;

  // -------------------------------------------------------------------------
  // Keys
  // -------------------------------------------------------------------------

  static const _kOnboardingComplete = 'onboarding_complete';
  static const _kUserProfile = 'user_profile';
  static const _kGuestId = 'guest_id';
  static const _kDailyQuests = 'daily_quests';
  static const _kThemeMode = 'theme_mode';
  static const _kContentManifest = 'content_manifest';
  static const _kPendingEvents = 'pending_telemetry_events';
  static const _kNewsArticles = 'news_articles';
  static const _kNewsCategories = 'news_categories';
  static const _kNewsLastSyncedAt = 'news_last_synced_at';

  // Legacy keys (read once during migration, then erased).
  static const _legacyKeys = <String>[
    'last_active_date',
    'daily_card_count',
    'learned_cards',
    'bookmarks',
    'total_xp',
    'streak',
    'track_progress',
    'ai_questions_today',
  ];

  // -------------------------------------------------------------------------
  // Migration
  // -------------------------------------------------------------------------

  /// One-time cleanup of phantom-write keys from earlier builds. The data was
  /// already mirrored into `_kUserProfile`, so these keys are pure waste.
  Future<void> _migrateLegacyKeys() async {
    var removed = false;
    for (final key in _legacyKeys) {
      if (_p.containsKey(key)) {
        await _p.remove(key);
        removed = true;
      }
    }
    if (removed) {
      // No revision bump — migration is invisible to the router.
    }
  }

  // -------------------------------------------------------------------------
  // Onboarding
  // -------------------------------------------------------------------------

  Future<void> saveOnboardingComplete(bool value) async {
    await _p.setBool(_kOnboardingComplete, value);
    _bump();
  }

  bool isOnboardingCompleteSync() =>
      _p.getBool(_kOnboardingComplete) ?? false;

  // -------------------------------------------------------------------------
  // User Profile
  // -------------------------------------------------------------------------

  Future<void> saveUserProfile(UserProfile profile) async {
    final json = jsonEncode(profile.toMap());
    await _p.setString(_kUserProfile, json);
  }

  Future<UserProfile?> loadUserProfile() async {
    final json = _p.getString(_kUserProfile);
    if (json == null) return null;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return UserProfile.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // Guest ID — stable across cold starts so analytics/server can reconcile.
  // -------------------------------------------------------------------------

  String? loadGuestIdSync() => _p.getString(_kGuestId);

  Future<void> saveGuestId(String id) => _p.setString(_kGuestId, id);

  // -------------------------------------------------------------------------
  // Daily Quests — stored alongside the date that produced them; re-generated
  // on first read of a new calendar day.
  // -------------------------------------------------------------------------

  Future<void> saveDailyQuests(List<DailyQuest> quests, DateTime date) async {
    final payload = jsonEncode({
      'date': DateTime(date.year, date.month, date.day).toIso8601String(),
      'quests': quests.map((q) => q.toMap()).toList(),
    });
    await _p.setString(_kDailyQuests, payload);
  }

  /// Returns the persisted quests if they were saved for [today]'s calendar
  /// day, otherwise null (caller should regenerate from templates).
  Future<List<DailyQuest>?> loadDailyQuestsForToday(DateTime today) async {
    final raw = _p.getString(_kDailyQuests);
    if (raw == null) return null;
    try {
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      final savedDate = DateTime.parse(payload['date'] as String);
      final todayStart = DateTime(today.year, today.month, today.day);
      if (savedDate != todayStart) return null;
      final list = payload['quests'] as List;
      return list
          .map((m) => DailyQuest.fromMap(m as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // Theme Mode
  // -------------------------------------------------------------------------

  /// 0 = system, 1 = light, 2 = dark. Defaults to dark.
  int loadThemeModeIndex() => _p.getInt(_kThemeMode) ?? 2;

  Future<void> saveThemeModeIndex(int index) => _p.setInt(_kThemeMode, index);

  // -------------------------------------------------------------------------
  // Content manifest cache — last successful manifest payload from admin.
  // Stored verbatim as JSON string so ContentService can re-hydrate
  // synchronously on boot, before the network fetch completes.
  // -------------------------------------------------------------------------

  String? loadContentManifestJsonSync() => _p.getString(_kContentManifest);

  Future<void> saveContentManifestJson(String json) =>
      _p.setString(_kContentManifest, json);

  Future<void> clearContentManifest() => _p.remove(_kContentManifest);

  // -------------------------------------------------------------------------
  // Pending telemetry events — persisted when offline so we don't lose
  // progress when the app is killed before a flush. Stored as a JSON array
  // of event maps; TelemetryService owns the schema.
  // -------------------------------------------------------------------------

  String? loadPendingEventsJsonSync() => _p.getString(_kPendingEvents);

  Future<void> savePendingEventsJson(String json) =>
      _p.setString(_kPendingEvents, json);

  Future<void> clearPendingEvents() => _p.remove(_kPendingEvents);

  // -------------------------------------------------------------------------
  // News cache — raw JSON list payloads and last-sync timestamp. The news
  // service decodes these on hydrate so the feed is instantly populated on
  // launch without waiting for the network.
  // -------------------------------------------------------------------------

  String? loadNewsArticlesJsonSync() => _p.getString(_kNewsArticles);

  Future<void> saveNewsArticlesJson(String json) =>
      _p.setString(_kNewsArticles, json);

  Future<void> clearNewsArticles() => _p.remove(_kNewsArticles);

  String? loadNewsCategoriesJsonSync() => _p.getString(_kNewsCategories);

  Future<void> saveNewsCategoriesJson(String json) =>
      _p.setString(_kNewsCategories, json);

  Future<void> clearNewsCategories() => _p.remove(_kNewsCategories);

  DateTime? loadNewsLastSyncedAtSync() {
    final iso = _p.getString(_kNewsLastSyncedAt);
    if (iso == null) return null;
    try {
      return DateTime.parse(iso);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveNewsLastSyncedAt(DateTime ts) =>
      _p.setString(_kNewsLastSyncedAt, ts.toIso8601String());

  // -------------------------------------------------------------------------
  // Generic key accessors — used by services (e.g. AuthService) that hold
  // their own keys without deserving a dedicated helper pair on this class.
  // -------------------------------------------------------------------------

  String? getString(String key) => _p.getString(key);

  Future<void> setString(String key, String value) =>
      _p.setString(key, value);

  int? getInt(String key) => _p.getInt(key);

  Future<void> setInt(String key, int value) => _p.setInt(key, value);

  Future<void> remove(String key) async {
    await _p.remove(key);
  }

  // -------------------------------------------------------------------------
  // Clear All (for sign-out / reset)
  // -------------------------------------------------------------------------

  Future<void> clearAll() async {
    await _p.clear();
    _bump();
  }
}
