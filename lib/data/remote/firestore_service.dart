import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/srs_model.dart';
import '../models/user_model.dart';

/// Cloud Firestore mirror of [UserProfile].
///
/// All reads and writes are scoped to `users/{firebaseUid}`. Writes are
/// fire-and-forget — failures are logged but never thrown to the UI, so a
/// transient outage doesn't break the offline-first SharedPreferences
/// snapshot. The Firestore SDK itself queues writes while offline.
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  /// Reads `users/{uid}`. Returns null if the doc doesn't exist (first
  /// sign-in for this account) or the network is offline and there is no
  /// cached copy. Network errors swallowed and reported via debugPrint.
  Future<UserProfile?> fetchProfile(String uid) async {
    try {
      final doc = await _users.doc(uid).get();
      if (!doc.exists) return null;
      return UserProfile.fromFirestore(doc.data()!, uid: uid);
    } catch (e, st) {
      debugPrint('FirestoreService.fetchProfile failed: $e\n$st');
      return null;
    }
  }

  /// Upserts the profile for a signed-in user. Uses `merge: true` so a
  /// future schema bump that adds fields won't blow away existing values.
  /// No-op when [profile] is a guest.
  Future<void> writeProfile(UserProfile profile) async {
    final uid = profile.firebaseUid;
    if (uid == null || profile.isGuest) return;
    try {
      await _users.doc(uid).set(
            profile.toFirestoreMap(),
            SetOptions(merge: true),
          );
    } catch (e, st) {
      debugPrint('FirestoreService.writeProfile failed: $e\n$st');
    }
  }

  /// Creates the doc on first sign-up / first sign-in. Stamps `createdAt`
  /// with the server timestamp so we can age accounts later if needed.
  Future<void> createInitialProfile(UserProfile profile) async {
    final uid = profile.firebaseUid;
    if (uid == null) return;
    try {
      final payload = profile.toFirestoreMap();
      payload['createdAt'] = FieldValue.serverTimestamp();
      await _users.doc(uid).set(payload, SetOptions(merge: true));
    } catch (e, st) {
      debugPrint('FirestoreService.createInitialProfile failed: $e\n$st');
    }
  }

  /// Pure-function merge used during a guest → signed-in upgrade. Cloud
  /// fields win for identity; for progress fields we take the maximum
  /// scalar and the union of sets/maps so neither device's progress is
  /// dropped. Daily-rollover counters always come from local (cloud
  /// doesn't carry them).
  static UserProfile mergeForUpgrade({
    required UserProfile local,
    required UserProfile cloud,
    required String uid,
    required String? email,
    required String? displayName,
    required String? photoUrl,
  }) {
    int max(int a, int b) => a > b ? a : b;

    final mergedBookmarks = {
      ...local.bookmarkedCardIds,
      ...cloud.bookmarkedCardIds,
    }.toList();
    final mergedLearned = {
      ...local.learnedCardIds,
      ...cloud.learnedCardIds,
    }.toList();
    final mergedNewsBookmarks = {
      ...local.bookmarkedNewsIds,
      ...cloud.bookmarkedNewsIds,
    }.toList();
    final mergedReadNews = {
      ...local.readNewsIds,
      ...cloud.readNewsIds,
    }.toList();
    final mergedBadges = {
      ...local.earnedBadgeIds,
      ...cloud.earnedBadgeIds,
    }.toList();
    final mergedTopics = {
      ...local.selectedTopics,
      ...cloud.selectedTopics,
    }.toList();
    final mergedTrackProgress = <String, int>{
      ...local.trackProgress,
      for (final e in cloud.trackProgress.entries)
        e.key: max(local.trackProgress[e.key] ?? 0, e.value),
    };
    // For SRS reviews: per-card, take the entry with the latest nextReview
    // (the more advanced schedule). Falls back to whichever exists.
    final mergedReviews = <String, CardReview>{};
    final allKeys = {...local.cardReviews.keys, ...cloud.cardReviews.keys};
    for (final k in allKeys) {
      final l = local.cardReviews[k];
      final c = cloud.cardReviews[k];
      if (l == null) {
        mergedReviews[k] = c!;
      } else if (c == null) {
        mergedReviews[k] = l;
      } else {
        mergedReviews[k] =
            l.nextReview.isAfter(c.nextReview) ? l : c;
      }
    }

    return cloud.copyWith(
      // Identity from auth callback (fresh / authoritative).
      firebaseUid: uid,
      email: email ?? cloud.email ?? local.email,
      name: displayName ?? cloud.name ?? local.name,
      photoUrl: photoUrl ?? cloud.photoUrl ?? local.photoUrl,
      isGuest: false,
      // Progress: max of scalars, union of sets.
      totalXP: max(local.totalXP, cloud.totalXP),
      // The streak belongs to whichever side was active most recently —
      // max() resurrected a stale cloud streak the user had already broken.
      currentStreak: _isAfter(local.lastActiveDate, cloud.lastActiveDate)
          ? local.currentStreak
          : _isAfter(cloud.lastActiveDate, local.lastActiveDate)
              ? cloud.currentStreak
              : max(local.currentStreak, cloud.currentStreak),
      longestStreak: max(local.longestStreak, cloud.longestStreak),
      totalCardsRead: max(local.totalCardsRead, cloud.totalCardsRead),
      quizzesPassed: max(local.quizzesPassed, cloud.quizzesPassed),
      cardsShared: max(local.cardsShared, cloud.cardsShared),
      expandedCardIds:
          {...local.expandedCardIds, ...cloud.expandedCardIds}.toList(),
      bookmarkedCardIds: mergedBookmarks,
      learnedCardIds: mergedLearned,
      bookmarkedNewsIds: mergedNewsBookmarks,
      readNewsIds: mergedReadNews,
      earnedBadgeIds: mergedBadges,
      trackProgress: mergedTrackProgress,
      // Resume positions: cloud wins per-track (last value written carries),
      // unioned with local entries the cloud doesn't yet have. Acceptable
      // because mis-resuming on the wrong card is benign — user can swipe.
      lastCardByTrack: <String, String>{
        ...local.lastCardByTrack,
        ...cloud.lastCardByTrack,
      },
      cardReviews: mergedReviews,
      // Onboarding answers: prefer cloud (set first) but adopt local if
      // cloud is unset. Topic list takes union.
      persona: cloud.persona.isNotEmpty ? cloud.persona : local.persona,
      knowledgeLevel: cloud.knowledgeLevel.isNotEmpty
          ? cloud.knowledgeLevel
          : local.knowledgeLevel,
      selectedTopics: mergedTopics,
      dailyGoal: cloud.dailyGoal > 0 ? cloud.dailyGoal : local.dailyGoal,
      // Settings: cloud wins for cross-device consistency.
      isPremium: cloud.isPremium || local.isPremium,
      hapticsEnabled: cloud.hapticsEnabled,
      soundEnabled: cloud.soundEnabled,
      notificationsEnabled: cloud.notificationsEnabled,
      reminderMinutesSinceMidnight: cloud.reminderMinutesSinceMidnight,
      pushNotificationsEnabled: cloud.pushNotificationsEnabled,
      dailyReviewCap: cloud.dailyReviewCap,
      // Cloud is the account's ledger. max() let sign-out (fresh guest with
      // the default freeze) + sign-in mint a free freeze every time.
      // ponytail: a freeze a guest earned (ad/referral) before signing in is
      // dropped; track earned-vs-default if that ever matters.
      freezesAvailable: cloud.freezesAvailable,
      freezesUsedTotal: max(local.freezesUsedTotal, cloud.freezesUsedTotal),
      // Local-only daily counters keep their local values; not in cloud.
      cardsReadToday: local.cardsReadToday,
      readCardIdsToday: local.readCardIdsToday,
      reviewsDoneToday: local.reviewsDoneToday,
      lastActiveDate: _laterOf(local.lastActiveDate, cloud.lastActiveDate),
    );
  }

  /// True when [a] is set and strictly later than [b] (or [b] is unset).
  static bool _isAfter(DateTime? a, DateTime? b) =>
      a != null && (b == null || a.isAfter(b));

  static DateTime? _laterOf(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }
}

final firestoreServiceProvider =
    Provider<FirestoreService>((_) => FirestoreService());
