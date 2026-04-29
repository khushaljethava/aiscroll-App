import 'package:cloud_firestore/cloud_firestore.dart';

import 'srs_model.dart';

enum BadgeRarity { common, uncommon, rare, legendary }

class UserBadge {
  final String id;
  final String emoji;
  final String name;
  final String description;
  final BadgeRarity rarity;
  final DateTime? earnedAt;

  const UserBadge({
    required this.id,
    required this.emoji,
    required this.name,
    required this.description,
    required this.rarity,
    this.earnedAt,
  });

  bool get isEarned => earnedAt != null;

  UserBadge copyWithEarned() => UserBadge(
    id: id,
    emoji: emoji,
    name: name,
    description: description,
    rarity: rarity,
    earnedAt: DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'emoji': emoji,
    'name': name,
    'description': description,
    'rarity': rarity.index,
    'earnedAt': earnedAt?.toIso8601String(),
  };

  factory UserBadge.fromMap(Map<String, dynamic> m) => UserBadge(
    id: m['id'] as String,
    emoji: m['emoji'] as String,
    name: m['name'] as String,
    description: m['description'] as String,
    rarity: BadgeRarity.values[m['rarity'] as int],
    earnedAt: m['earnedAt'] != null
        ? DateTime.parse(m['earnedAt'] as String)
        : null,
  );
}

class UserProfile {
  final String id;
  final String? name;
  final String? email;
  // Firebase Auth identity. Populated on Google sign-in; cleared on sign-out.
  // [isGuest] stays authoritative for "logged in or not" checks.
  final String? firebaseUid;
  final String? photoUrl;
  final int totalXP;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastActiveDate;
  final int cardsReadToday;
  final int dailyGoal;
  final int totalCardsRead;
  final int quizzesPassed;
  final List<String> earnedBadgeIds;
  final List<String> bookmarkedCardIds;
  final List<String> learnedCardIds;
  final List<String> readCardIdsToday;
  final List<String> bookmarkedNewsIds;
  final List<String> readNewsIds;
  final Map<String, int> trackProgress;
  /// Per-track resume position. Maps `trackId → cardId` of the last card
  /// the user was viewing in that track. On reopen we jump to that page,
  /// or fall back to index 0 when the entry is missing or stale.
  final Map<String, String> lastCardByTrack;
  final bool isPremium;
  final bool isGuest;
  final String persona;
  final String knowledgeLevel;
  final List<String> selectedTopics;
  final Map<String, CardReview> cardReviews;
  final int reviewsDoneToday;
  final int dailyReviewCap;
  // --- feedback ---
  final bool hapticsEnabled;
  final bool soundEnabled;
  // --- streak freeze ---
  final int freezesAvailable;
  final int freezesUsedTotal;
  final DateTime? lastFreezeGrantedAt;
  // --- notifications ---
  final bool notificationsEnabled;
  final int reminderMinutesSinceMidnight;
  // FCM news-topic opt-in. Distinct from `notificationsEnabled` (which
  // governs the daily local reminder) — users may want one without the
  // other. Default off so we never auto-prompt on first launch.
  final bool pushNotificationsEnabled;

  const UserProfile({
    required this.id,
    this.name,
    this.email,
    this.firebaseUid,
    this.photoUrl,
    this.totalXP = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastActiveDate,
    this.cardsReadToday = 0,
    this.dailyGoal = 5,
    this.totalCardsRead = 0,
    this.quizzesPassed = 0,
    this.earnedBadgeIds = const [],
    this.bookmarkedCardIds = const [],
    this.learnedCardIds = const [],
    this.readCardIdsToday = const [],
    this.bookmarkedNewsIds = const [],
    this.readNewsIds = const [],
    this.trackProgress = const {},
    this.lastCardByTrack = const {},
    this.isPremium = false,
    this.isGuest = false,
    this.persona = 'curious',
    this.knowledgeLevel = 'nothing',
    this.selectedTopics = const [],
    this.cardReviews = const {},
    this.reviewsDoneToday = 0,
    this.dailyReviewCap = 20,
    this.hapticsEnabled = true,
    this.soundEnabled = false,
    this.freezesAvailable = 1,
    this.freezesUsedTotal = 0,
    this.lastFreezeGrantedAt,
    this.notificationsEnabled = false,
    this.reminderMinutesSinceMidnight = 8 * 60,
    this.pushNotificationsEnabled = false,
  });

  /// Bumped whenever the cloud-side `toFirestoreMap` schema changes in a
  /// non-backwards-compatible way. Read on hydrate so future versions can
  /// migrate gracefully.
  static const int schemaVersion = 1;

  bool get isDailyGoalMet => cardsReadToday >= dailyGoal;

  double get dailyGoalProgress =>
      dailyGoal > 0 ? (cardsReadToday / dailyGoal).clamp(0.0, 1.0) : 0.0;

  UserProfile copyWith({
    // Identity fields use an `Object? … = _sentinel` pattern so callers
    // can explicitly clear them to null (needed on sign-out). A plain
    // `String? name` would conflate "unchanged" with "clear".
    Object? name = _sentinel,
    Object? email = _sentinel,
    Object? firebaseUid = _sentinel,
    Object? photoUrl = _sentinel,
    int? totalXP,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastActiveDate,
    int? cardsReadToday,
    int? dailyGoal,
    int? totalCardsRead,
    int? quizzesPassed,
    List<String>? earnedBadgeIds,
    List<String>? bookmarkedCardIds,
    List<String>? learnedCardIds,
    List<String>? readCardIdsToday,
    List<String>? bookmarkedNewsIds,
    List<String>? readNewsIds,
    Map<String, int>? trackProgress,
    Map<String, String>? lastCardByTrack,
    bool? isPremium,
    bool? isGuest,
    String? persona,
    String? knowledgeLevel,
    List<String>? selectedTopics,
    Map<String, CardReview>? cardReviews,
    int? reviewsDoneToday,
    int? dailyReviewCap,
    bool? hapticsEnabled,
    bool? soundEnabled,
    int? freezesAvailable,
    int? freezesUsedTotal,
    DateTime? lastFreezeGrantedAt,
    bool? notificationsEnabled,
    int? reminderMinutesSinceMidnight,
    bool? pushNotificationsEnabled,
  }) => UserProfile(
    id: id,
    name: identical(name, _sentinel) ? this.name : name as String?,
    email: identical(email, _sentinel) ? this.email : email as String?,
    firebaseUid: identical(firebaseUid, _sentinel)
        ? this.firebaseUid
        : firebaseUid as String?,
    photoUrl:
        identical(photoUrl, _sentinel) ? this.photoUrl : photoUrl as String?,
    totalXP: totalXP ?? this.totalXP,
    currentStreak: currentStreak ?? this.currentStreak,
    longestStreak: longestStreak ?? this.longestStreak,
    lastActiveDate: lastActiveDate ?? this.lastActiveDate,
    cardsReadToday: cardsReadToday ?? this.cardsReadToday,
    dailyGoal: dailyGoal ?? this.dailyGoal,
    totalCardsRead: totalCardsRead ?? this.totalCardsRead,
    quizzesPassed: quizzesPassed ?? this.quizzesPassed,
    earnedBadgeIds: earnedBadgeIds ?? this.earnedBadgeIds,
    bookmarkedCardIds: bookmarkedCardIds ?? this.bookmarkedCardIds,
    learnedCardIds: learnedCardIds ?? this.learnedCardIds,
    readCardIdsToday: readCardIdsToday ?? this.readCardIdsToday,
    bookmarkedNewsIds: bookmarkedNewsIds ?? this.bookmarkedNewsIds,
    readNewsIds: readNewsIds ?? this.readNewsIds,
    trackProgress: trackProgress ?? this.trackProgress,
    lastCardByTrack: lastCardByTrack ?? this.lastCardByTrack,
    isPremium: isPremium ?? this.isPremium,
    isGuest: isGuest ?? this.isGuest,
    persona: persona ?? this.persona,
    knowledgeLevel: knowledgeLevel ?? this.knowledgeLevel,
    selectedTopics: selectedTopics ?? this.selectedTopics,
    cardReviews: cardReviews ?? this.cardReviews,
    reviewsDoneToday: reviewsDoneToday ?? this.reviewsDoneToday,
    dailyReviewCap: dailyReviewCap ?? this.dailyReviewCap,
    hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    soundEnabled: soundEnabled ?? this.soundEnabled,
    freezesAvailable: freezesAvailable ?? this.freezesAvailable,
    freezesUsedTotal: freezesUsedTotal ?? this.freezesUsedTotal,
    lastFreezeGrantedAt: lastFreezeGrantedAt ?? this.lastFreezeGrantedAt,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    reminderMinutesSinceMidnight:
        reminderMinutesSinceMidnight ?? this.reminderMinutesSinceMidnight,
    pushNotificationsEnabled:
        pushNotificationsEnabled ?? this.pushNotificationsEnabled,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'email': email,
    'firebaseUid': firebaseUid,
    'photoUrl': photoUrl,
    'totalXP': totalXP,
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    'lastActiveDate': lastActiveDate?.toIso8601String(),
    'cardsReadToday': cardsReadToday,
    'dailyGoal': dailyGoal,
    'totalCardsRead': totalCardsRead,
    'quizzesPassed': quizzesPassed,
    'earnedBadgeIds': earnedBadgeIds,
    'bookmarkedCardIds': bookmarkedCardIds,
    'learnedCardIds': learnedCardIds,
    'readCardIdsToday': readCardIdsToday,
    'bookmarkedNewsIds': bookmarkedNewsIds,
    'readNewsIds': readNewsIds,
    'trackProgress': trackProgress,
    'lastCardByTrack': lastCardByTrack,
    'isPremium': isPremium,
    'isGuest': isGuest,
    'persona': persona,
    'knowledgeLevel': knowledgeLevel,
    'selectedTopics': selectedTopics,
    'cardReviews':
        cardReviews.map((k, v) => MapEntry(k, v.toMap())),
    'reviewsDoneToday': reviewsDoneToday,
    'dailyReviewCap': dailyReviewCap,
    'hapticsEnabled': hapticsEnabled,
    'soundEnabled': soundEnabled,
    'freezesAvailable': freezesAvailable,
    'freezesUsedTotal': freezesUsedTotal,
    'lastFreezeGrantedAt': lastFreezeGrantedAt?.toIso8601String(),
    'notificationsEnabled': notificationsEnabled,
    'reminderMinutesSinceMidnight': reminderMinutesSinceMidnight,
    'pushNotificationsEnabled': pushNotificationsEnabled,
  };

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
    id: m['id'] as String,
    name: m['name'] as String?,
    email: m['email'] as String?,
    firebaseUid: m['firebaseUid'] as String?,
    photoUrl: m['photoUrl'] as String?,
    totalXP: (m['totalXP'] as int?) ?? 0,
    currentStreak: (m['currentStreak'] as int?) ?? 0,
    longestStreak: (m['longestStreak'] as int?) ?? 0,
    lastActiveDate: m['lastActiveDate'] != null
        ? DateTime.parse(m['lastActiveDate'] as String)
        : null,
    cardsReadToday: (m['cardsReadToday'] as int?) ?? 0,
    dailyGoal: (m['dailyGoal'] as int?) ?? 5,
    totalCardsRead: (m['totalCardsRead'] as int?) ?? 0,
    quizzesPassed: (m['quizzesPassed'] as int?) ?? 0,
    earnedBadgeIds: List<String>.from(m['earnedBadgeIds'] as List? ?? []),
    bookmarkedCardIds:
        List<String>.from(m['bookmarkedCardIds'] as List? ?? []),
    learnedCardIds: List<String>.from(m['learnedCardIds'] as List? ?? []),
    readCardIdsToday:
        List<String>.from(m['readCardIdsToday'] as List? ?? []),
    bookmarkedNewsIds:
        List<String>.from(m['bookmarkedNewsIds'] as List? ?? []),
    readNewsIds: List<String>.from(m['readNewsIds'] as List? ?? []),
    trackProgress: Map<String, int>.from(m['trackProgress'] as Map? ?? {}),
    lastCardByTrack:
        Map<String, String>.from(m['lastCardByTrack'] as Map? ?? {}),
    isPremium: (m['isPremium'] as bool?) ?? false,
    isGuest: (m['isGuest'] as bool?) ?? false,
    persona: (m['persona'] as String?) ?? 'curious',
    knowledgeLevel: (m['knowledgeLevel'] as String?) ?? 'nothing',
    selectedTopics: List<String>.from(m['selectedTopics'] as List? ?? []),
    cardReviews: _decodeReviews(m['cardReviews']),
    reviewsDoneToday: (m['reviewsDoneToday'] as int?) ?? 0,
    dailyReviewCap: (m['dailyReviewCap'] as int?) ?? 20,
    hapticsEnabled: (m['hapticsEnabled'] as bool?) ?? true,
    soundEnabled: (m['soundEnabled'] as bool?) ?? false,
    freezesAvailable: (m['freezesAvailable'] as int?) ?? 1,
    freezesUsedTotal: (m['freezesUsedTotal'] as int?) ?? 0,
    lastFreezeGrantedAt: m['lastFreezeGrantedAt'] != null
        ? DateTime.parse(m['lastFreezeGrantedAt'] as String)
        : null,
    notificationsEnabled: (m['notificationsEnabled'] as bool?) ?? false,
    reminderMinutesSinceMidnight:
        (m['reminderMinutesSinceMidnight'] as int?) ?? 8 * 60,
    pushNotificationsEnabled:
        (m['pushNotificationsEnabled'] as bool?) ?? false,
  );

  /// Cloud-shaped payload for `users/{uid}` in Firestore.
  ///
  /// Differs from [toMap] in three ways:
  ///   * `id` is dropped — Firestore uses `uid` as the document key.
  ///   * Daily-rollover fields (`cardsReadToday`, `readCardIdsToday`,
  ///     `reviewsDoneToday`) are dropped — they reset locally each day and
  ///     mirroring them every card-read would burn writes for no benefit.
  ///   * Adds `schemaVersion`, `updatedAt` (server timestamp), and
  ///     `lastSyncedClientAt` (device clock, for diagnostics).
  Map<String, dynamic> toFirestoreMap() {
    final m = toMap();
    m.remove('id');
    m.remove('cardsReadToday');
    m.remove('readCardIdsToday');
    m.remove('reviewsDoneToday');
    m['schemaVersion'] = schemaVersion;
    m['updatedAt'] = FieldValue.serverTimestamp();
    m['lastSyncedClientAt'] = DateTime.now().toIso8601String();
    return m;
  }

  /// Inverse of [toFirestoreMap]. Reuses [fromMap] but stamps the document
  /// id (Firestore key) onto the local-only `id` field, and tolerates the
  /// missing daily-rollover keys (they default to 0/empty in [fromMap]).
  factory UserProfile.fromFirestore(
    Map<String, dynamic> data, {
    required String uid,
  }) {
    final patched = Map<String, dynamic>.from(data);
    patched['id'] = uid;
    // Server timestamps come back as `Timestamp` — fromMap doesn't read
    // them so we just drop them; presence of `updatedAt` isn't needed
    // client-side.
    patched.remove('updatedAt');
    patched.remove('schemaVersion');
    patched.remove('lastSyncedClientAt');
    return UserProfile.fromMap(patched);
  }

  static const _sentinel = Object();

  static Map<String, CardReview> _decodeReviews(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, CardReview>{};
    raw.forEach((k, v) {
      if (k is String && v is Map) {
        try {
          out[k] = CardReview.fromMap(Map<String, dynamic>.from(v));
        } catch (_) {
          // Skip malformed entry; will be re-seeded on next interaction.
        }
      }
    });
    return out;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is UserProfile && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
