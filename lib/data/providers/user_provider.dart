import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../local/preferences_service.dart';
import '../models/srs_model.dart';
import '../models/user_model.dart';
import '../../core/constants/xp_constants.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/referral/referral_code.dart';
import '../../features/gamification/providers/gamification_provider.dart';
import 'cards_provider.dart';
import '../remote/firestore_service.dart';
import '../remote/news_push_service.dart';
import '../remote/telemetry_service.dart';
import 'telemetry_provider.dart';

enum RedeemResult { success, invalid, selfReferral, alreadyRedeemed }

class UserNotifier extends StateNotifier<UserProfile> {
  UserNotifier._(super.initial, {Ref? ref}) : _ref = ref;

  final Ref? _ref;

  /// Builds a notifier seeded with either the persisted profile, or a guest
  /// profile whose UUID is stable across cold starts.
  factory UserNotifier.create({Ref? ref}) {
    final prefs = PreferencesService.instance;
    final guestId = prefs.loadGuestIdSync() ?? const Uuid().v4();
    if (prefs.loadGuestIdSync() == null) {
      // Fire-and-forget; persist the new guest id for future launches.
      // ignore: discarded_futures
      prefs.saveGuestId(guestId);
    }
    return UserNotifier._(
      UserProfile(
        id: guestId,
        isGuest: true,
        inviteCode: ReferralCode.generate(),
      ),
      ref: ref,
    );
  }

  // Null-safe accessor — when a notifier is built in tests without a Ref,
  // telemetry calls collapse to no-ops.
  TelemetryService? get _telemetry => _ref?.read(telemetryServiceProvider);

  String? get _userIdForTelemetry => state.isGuest ? null : state.id;

  PreferencesService get _prefs => PreferencesService.instance;

  Timer? _saveTimer;
  Timer? _cloudSaveTimer;
  static const _saveDebounce = Duration(milliseconds: 500);
  // Slightly longer than local — gives bursty mutations a single coalesced
  // network write per second while keeping latency acceptable.
  static const _cloudSaveDebounce = Duration(seconds: 1);

  FirestoreService? get _firestore => _ref?.read(firestoreServiceProvider);

  /// Schedules a coalesced write of the current state. Multiple `_scheduleSave`
  /// calls within the debounce window result in a single SharedPreferences
  /// write — important when SRS review events come in bursts during a quiz.
  /// Also kicks the cloud-write debouncer when the user is signed in.
  void _scheduleSave() {
    _awardBadges();
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDebounce, () {
      _saveTimer = null;
      // ignore: discarded_futures
      _prefs.saveUserProfile(state);
    });
    _scheduleCloudSave();
  }

  /// Grants every badge whose condition the current state now meets and
  /// pops the first new one. Runs on every save, so any mutation that
  /// unlocks a badge is caught without per-call-site wiring.
  /// ponytail: deep_thinker (expanded views) and sharing_caring (shares)
  /// have no counters on UserProfile yet, so they can't be earned; add the
  /// counters + rules here when those badges matter.
  void _awardBadges() {
    final s = state;
    final tracks = _ref?.read(allTracksProvider) ?? const [];
    final learned = s.learnedCardIds.toSet();
    final rules = <String, bool>{
      'first_flame': s.currentStreak >= 1,
      'week_warrior': s.longestStreak >= 7,
      'month_master': s.longestStreak >= 30,
      'quiz_ace': s.quizzesPassed >= 10,
      'grandmaster': XPConstants.getLevelFromXP(s.totalXP) >=
          XPConstants.levelThresholds.length,
      'track_legend': tracks.any(
          (t) => t.cardIds.isNotEmpty && t.cardIds.every(learned.contains)),
    };
    final fresh = [
      for (final e in rules.entries)
        if (e.value && !s.earnedBadgeIds.contains(e.key)) e.key,
    ];
    if (fresh.isEmpty) return;
    state = s.copyWith(earnedBadgeIds: [...s.earnedBadgeIds, ...fresh]);
    _ref?.read(gamificationProvider.notifier).triggerBadge(fresh.first);
  }

  /// Mirrors the in-memory state to Firestore for signed-in users.
  /// No-op when [state] is a guest (no `firebaseUid`). Failures are
  /// logged inside FirestoreService and never reach the UI.
  void _scheduleCloudSave() {
    if (state.isGuest || state.firebaseUid == null) return;
    final svc = _firestore;
    if (svc == null) return;
    _cloudSaveTimer?.cancel();
    _cloudSaveTimer = Timer(_cloudSaveDebounce, () {
      _cloudSaveTimer = null;
      // ignore: discarded_futures
      svc.writeProfile(state);
    });
  }

  /// Flushes any pending debounced save and writes immediately. Used by
  /// "critical" mutations (reset, onboarding completion, full profile
  /// replacement) that must hit disk before returning. Also flushes the
  /// cloud write so the next read sees the latest state.
  Future<void> _flushSave() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    await _prefs.saveUserProfile(state);
    _cloudSaveTimer?.cancel();
    _cloudSaveTimer = null;
    if (!state.isGuest && state.firebaseUid != null) {
      await _firestore?.writeProfile(state);
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _cloudSaveTimer?.cancel();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Load / Reset
  // -------------------------------------------------------------------------

  /// Loads the persisted profile (if any) and rolls over daily counters when
  /// the calendar day has advanced since `lastActiveDate`. Also seeds SRS
  /// reviews for previously learned cards on first upgrade.
  Future<void> load() async {
    final loaded = await _prefs.loadUserProfile();
    if (loaded == null) return;
    // Backfill invite code for legacy profiles created before referrals.
    final saved = (loaded.inviteCode == null || loaded.inviteCode!.isEmpty)
        ? loaded.copyWith(inviteCode: ReferralCode.generate())
        : loaded;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = saved.lastActiveDate == null
        ? null
        : DateTime(
            saved.lastActiveDate!.year,
            saved.lastActiveDate!.month,
            saved.lastActiveDate!.day,
          );

    var working = saved;

    // ----- Migration: seed SRS for previously learned cards -----
    if (working.cardReviews.isEmpty && working.learnedCardIds.isNotEmpty) {
      final seeded = <String, CardReview>{
        for (final id in working.learnedCardIds)
          id: CardReview.seededFromLearned(id, today),
      };
      working = working.copyWith(cardReviews: seeded);
    }

    // ----- Daily rollover -----
    if (lastDay == null || today.isAfter(lastDay)) {
      working = working.copyWith(
        cardsReadToday: 0,
        readCardIdsToday: const <String>[],
        reviewsDoneToday: 0,
      );
      if (lastDay != null) {
        final diff = today.difference(lastDay).inDays;
        // A single missed day with a freeze in hand is NOT settled here —
        // `updateStreak` spends the freeze on today's first activity.
        // Spending it here too consumed two freezes for one missed day.
        final rescuable = diff == 2 && working.freezesAvailable > 0;
        if (diff > 1 && !rescuable) {
          working = working.copyWith(currentStreak: 0);
        }
      }
      state = working;
      await _flushSave();
    } else {
      state = working;
      // Persist the migration if it occurred (no-op write otherwise — the
      // debounced write coalesces).
      if (saved.cardReviews.isEmpty && working.cardReviews.isNotEmpty) {
        await _flushSave();
      }
    }

    // Weekly housekeeping — separate clock from daily rollover.
    _weeklyHousekeeping(today);
  }

  /// Redeems a friend's referral code. Returns one of:
  ///   * `RedeemResult.success` — code accepted, +1 streak freeze granted.
  ///   * `RedeemResult.invalid` — malformed (not 6 chars or unknown alpha).
  ///   * `RedeemResult.selfReferral` — code matches this user's own code.
  ///   * `RedeemResult.alreadyRedeemed` — user already redeemed before.
  ///
  /// Server-side reward to the inviter is intentionally out of scope at v1
  /// — that requires a Firestore lookup keyed by code. The redeemer reward
  /// is enough to bootstrap viral loops; inviter reward can land later.
  Future<RedeemResult> redeemReferralCode(String raw) async {
    if (state.redeemedInviteCode != null &&
        state.redeemedInviteCode!.isNotEmpty) {
      return RedeemResult.alreadyRedeemed;
    }
    final code = ReferralCode.normalise(raw);
    if (code == null) return RedeemResult.invalid;
    if (state.inviteCode != null && code == state.inviteCode) {
      return RedeemResult.selfReferral;
    }
    const freezeCap = 2;
    final nextFreezes = (state.freezesAvailable + 1).clamp(0, freezeCap);
    state = state.copyWith(
      redeemedInviteCode: code,
      freezesAvailable: nextFreezes,
    );
    await _flushSave();
    _telemetry?.log(
      'referral_redeemed',
      guestId: state.id,
      userId: _userIdForTelemetry,
      props: {'code': code},
    );
    return RedeemResult.success;
  }

  /// Grants one bonus streak freeze on top of the weekly grant — used by
  /// the rewarded-ad surface in the profile screen. Capped at 2 freezes
  /// total so users can't stockpile by repeatedly watching ads.
  Future<bool> grantBonusFreeze() async {
    const freezeCap = 2;
    if (state.freezesAvailable >= freezeCap) return false;
    state = state.copyWith(freezesAvailable: state.freezesAvailable + 1);
    await _flushSave();
    _telemetry?.log(
      'rewarded_ad_redeemed',
      guestId: state.id,
      userId: _userIdForTelemetry,
      props: {'reward': 'streak_freeze'},
    );
    return true;
  }

  /// Grants one freeze per calendar week (up to the cap of 2). Called from
  /// [load] so the user sees fresh freezes the moment they open the app.
  void _weeklyHousekeeping(DateTime today) {
    const freezeCap = 2;
    const freezeGrantIntervalDays = 7;
    final last = state.lastFreezeGrantedAt;
    final eligible = last == null ||
        today.difference(DateTime(last.year, last.month, last.day)).inDays >=
            freezeGrantIntervalDays;
    if (!eligible) return;
    if (state.freezesAvailable >= freezeCap) {
      // At cap — still update the timer so the next grant is 7d from now.
      state = state.copyWith(lastFreezeGrantedAt: today);
      _scheduleSave();
      return;
    }
    state = state.copyWith(
      freezesAvailable: state.freezesAvailable + 1,
      lastFreezeGrantedAt: today,
    );
    _scheduleSave();
  }

  /// Wipes the in-memory profile back to a fresh guest. Caller should also
  /// call `PreferencesService.clearAll()` for a full sign-out.
  Future<void> reset() async {
    final freshId = const Uuid().v4();
    await _prefs.saveGuestId(freshId);
    state = UserProfile(
      id: freshId,
      isGuest: true,
      inviteCode: ReferralCode.generate(),
    );
    await _flushSave();
  }

  // -------------------------------------------------------------------------
  // XP
  // -------------------------------------------------------------------------

  Future<void> addXP(int xp, {String source = 'unknown'}) async {
    final before = XPConstants.getLevelFromXP(state.totalXP);
    state = state.copyWith(totalXP: state.totalXP + xp);
    final after = XPConstants.getLevelFromXP(state.totalXP);
    if (after > before) {
      _ref?.read(gamificationProvider.notifier).triggerLevelUp(after);
    }
    _scheduleSave();
    _telemetry?.logXp(xp, source, guestId: state.id, userId: _userIdForTelemetry);
  }

  // -------------------------------------------------------------------------
  // Card Actions
  // -------------------------------------------------------------------------

  /// Idempotent per card per day. Returns true if this call counted as a
  /// fresh read (caller awards XP only in that case).
  Future<bool> markCardRead(String cardId) async {
    if (state.readCardIdsToday.contains(cardId)) return false;

    final updatedReadToday = List<String>.from(state.readCardIdsToday)
      ..add(cardId);
    // Don't stamp lastActiveDate here: updateStreak compares against the
    // *previous* active day, then stamps it itself.
    state = state.copyWith(
      cardsReadToday: state.cardsReadToday + 1,
      totalCardsRead: state.totalCardsRead + 1,
      readCardIdsToday: updatedReadToday,
    );
    _scheduleSave();
    await updateStreak();
    _telemetry?.logCardViewed(cardId,
        guestId: state.id, userId: _userIdForTelemetry);
    return true;
  }

  /// Returns true when [cardId] was newly added to the learned list.
  Future<bool> markCardLearned(String cardId) async {
    if (state.learnedCardIds.contains(cardId)) return false;
    final updated = List<String>.from(state.learnedCardIds)..add(cardId);
    state = state.copyWith(learnedCardIds: updated);
    _scheduleSave();
    _telemetry?.logCardLearned(cardId,
        guestId: state.id, userId: _userIdForTelemetry);
    return true;
  }

  Future<void> toggleBookmark(String cardId) async {
    final bookmarks = List<String>.from(state.bookmarkedCardIds);
    if (bookmarks.contains(cardId)) {
      bookmarks.remove(cardId);
    } else {
      bookmarks.add(cardId);
    }
    state = state.copyWith(bookmarkedCardIds: bookmarks);
    _scheduleSave();
  }

  // -------------------------------------------------------------------------
  // News Actions
  // -------------------------------------------------------------------------

  /// Returns true when the item becomes bookmarked, false when it was removed.
  Future<bool> toggleNewsBookmark(String newsId) async {
    final bookmarks = List<String>.from(state.bookmarkedNewsIds);
    final nowBookmarked = !bookmarks.contains(newsId);
    if (nowBookmarked) {
      bookmarks.add(newsId);
    } else {
      bookmarks.remove(newsId);
    }
    state = state.copyWith(bookmarkedNewsIds: bookmarks);
    _scheduleSave();
    _telemetry?.log(
      nowBookmarked ? 'news_bookmark_add' : 'news_bookmark_remove',
      guestId: state.id,
      userId: _userIdForTelemetry,
      props: {'newsId': newsId},
    );
    return nowBookmarked;
  }

  /// Idempotent. No XP (news is not gamified per the plan).
  Future<bool> markNewsRead(String newsId) async {
    if (state.readNewsIds.contains(newsId)) return false;
    final updated = List<String>.from(state.readNewsIds)..add(newsId);
    state = state.copyWith(readNewsIds: updated);
    _scheduleSave();
    _telemetry?.log(
      'news_read',
      guestId: state.id,
      userId: _userIdForTelemetry,
      props: {'newsId': newsId},
    );
    return true;
  }

  void logNewsShare(String newsId) {
    _telemetry?.log(
      'news_share',
      guestId: state.id,
      userId: _userIdForTelemetry,
      props: {'newsId': newsId},
    );
  }

  void logNewsSourceOpen(String newsId) {
    _telemetry?.log(
      'news_source_open',
      guestId: state.id,
      userId: _userIdForTelemetry,
      props: {'newsId': newsId},
    );
  }

  // -------------------------------------------------------------------------
  // SRS
  // -------------------------------------------------------------------------

  /// Replaces the cardReviews map and increments the per-day review counter.
  /// Called by [SRSNotifier] after each scheduling change.
  Future<void> updateReviews(
    Map<String, CardReview> reviews, {
    bool incrementDoneToday = true,
  }) async {
    state = state.copyWith(
      cardReviews: reviews,
      reviewsDoneToday: incrementDoneToday
          ? state.reviewsDoneToday + 1
          : state.reviewsDoneToday,
    );
    _scheduleSave();
    // A review (e.g. a quiz answer) is activity: let updateStreak advance
    // the streak and stamp lastActiveDate.
    await updateStreak();
  }

  Future<void> setDailyReviewCap(int cap) async {
    state = state.copyWith(dailyReviewCap: cap.clamp(1, 200));
    _scheduleSave();
  }

  // -------------------------------------------------------------------------
  // Streak
  // -------------------------------------------------------------------------

  Future<void> updateStreak() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last = state.lastActiveDate;

    if (last == null) {
      state = state.copyWith(
        currentStreak: 1,
        longestStreak: state.longestStreak == 0 ? 1 : state.longestStreak,
        lastActiveDate: now,
      );
    } else {
      final lastDay = DateTime(last.year, last.month, last.day);
      final diff = today.difference(lastDay).inDays;

      if (diff == 0 && state.currentStreak > 0) {
        state = state.copyWith(lastActiveDate: now);
      } else if (diff == 0 && state.currentStreak == 0) {
        state = state.copyWith(currentStreak: 1, lastActiveDate: now);
      } else if (diff == 1) {
        final newStreak = state.currentStreak + 1;
        state = state.copyWith(
          currentStreak: newStreak,
          longestStreak:
              newStreak > state.longestStreak ? newStreak : state.longestStreak,
          lastActiveDate: now,
        );
      } else if (diff == 2 && state.freezesAvailable > 0) {
        // Auto-consume a freeze for the single missed day. Streak intact;
        // today's activity still counts as a +1.
        final newStreak = state.currentStreak + 1;
        state = state.copyWith(
          currentStreak: newStreak,
          longestStreak:
              newStreak > state.longestStreak ? newStreak : state.longestStreak,
          freezesAvailable: state.freezesAvailable - 1,
          freezesUsedTotal: state.freezesUsedTotal + 1,
          lastActiveDate: now,
        );
      } else {
        // Multiple-day gap or no freezes: reset.
        state = state.copyWith(currentStreak: 1, lastActiveDate: now);
      }
    }

    _scheduleSave();
    _telemetry?.logStreakDay(state.currentStreak,
        guestId: state.id, userId: _userIdForTelemetry);
  }

  // -------------------------------------------------------------------------
  // Track Progress
  // -------------------------------------------------------------------------

  Future<void> completeTrackProgress(String trackId) async {
    final progress = Map<String, int>.from(state.trackProgress);
    progress[trackId] = (progress[trackId] ?? 0) + 1;
    state = state.copyWith(trackProgress: progress);
    _scheduleSave();
  }

  /// Persists the last card the user was viewing in [trackId] so reopening
  /// the track jumps back to that page. Short-circuits on no-op writes —
  /// otherwise rapid swipe sessions would emit one Firestore mutation per
  /// page change.
  Future<void> setLastCardForTrack(String trackId, String cardId) async {
    if (state.lastCardByTrack[trackId] == cardId) return;
    final next = Map<String, String>.from(state.lastCardByTrack);
    next[trackId] = cardId;
    state = state.copyWith(lastCardByTrack: next);
    _scheduleSave();
  }

  // -------------------------------------------------------------------------
  // Profile
  // -------------------------------------------------------------------------

  Future<void> saveProfile(UserProfile profile) async {
    state = profile;
    await _flushSave();
  }

  // -------------------------------------------------------------------------
  // Firebase sign-in / sign-out
  //
  // Sign-in *preserves* everything the guest did locally — we only stamp
  // the identity fields and flip `isGuest` to false. Sign-out reverses
  // the identity fields but again keeps progress (streak, bookmarks etc.).
  // For a clean wipe the user should call [reset] instead.
  // -------------------------------------------------------------------------

  Future<void> signInWithFirebaseUser({
    required String firebaseUid,
    required String? email,
    required String? displayName,
    required String? photoUrl,
    String provider = 'google',
  }) async {
    state = state.copyWith(
      isGuest: false,
      firebaseUid: firebaseUid,
      email: email,
      name: displayName ?? state.name ?? 'Learner',
      photoUrl: photoUrl,
    );
    await _flushSave();
    _telemetry?.log(
      'user_sign_in',
      guestId: state.id,
      userId: firebaseUid,
      props: {'provider': provider},
    );
  }

  /// Sign-in path that reconciles the cloud profile with the local one.
  ///
  /// Behavior:
  ///   * Cloud doc missing → adopt local state, stamp identity, push up.
  ///     This is the "first sign-in for this account" / fresh registration
  ///     case (caller will normally route to the preference screens after).
  ///   * Cloud doc exists and local was a *guest* → merge using
  ///     [FirestoreService.mergeForUpgrade] (max scalars, union sets), so
  ///     the user doesn't lose anything they did before signing in.
  ///   * Cloud doc exists and local was already signed in (cold start on a
  ///     new device, or returning user) → cloud wins for shared state;
  ///     local-only daily counters preserved.
  ///
  /// Returns true when a complete profile was loaded (persona/topics/goal
  /// all set) so callers can decide whether to skip the preference screens.
  Future<bool> pullFromCloudAndMerge({
    required String firebaseUid,
    required String? email,
    required String? displayName,
    required String? photoUrl,
    String provider = 'google',
  }) async {
    final svc = _firestore;
    final cloud = svc == null ? null : await svc.fetchProfile(firebaseUid);

    if (cloud == null) {
      await signInWithFirebaseUser(
        firebaseUid: firebaseUid,
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
        provider: provider,
      );
      // Brand new cloud account — push the local snapshot up so even an
      // immediate force-quit doesn't lose what the user had as a guest.
      await svc?.createInitialProfile(state);
      return _hasCompleteOnboarding(state);
    }

    final wasGuest = state.isGuest;
    final merged = wasGuest
        ? FirestoreService.mergeForUpgrade(
            local: state,
            cloud: cloud,
            uid: firebaseUid,
            email: email,
            displayName: displayName,
            photoUrl: photoUrl,
          )
        : cloud.copyWith(
            firebaseUid: firebaseUid,
            email: email ?? cloud.email,
            name: displayName ?? cloud.name,
            photoUrl: photoUrl ?? cloud.photoUrl,
            isGuest: false,
            // Preserve local daily-rollover counters — cloud doesn't carry them.
            cardsReadToday: state.cardsReadToday,
            readCardIdsToday: state.readCardIdsToday,
            reviewsDoneToday: state.reviewsDoneToday,
          );

    state = merged;
    await _flushSave();
    _telemetry?.log(
      'user_sign_in',
      guestId: state.id,
      userId: firebaseUid,
      props: {
        'provider': provider,
        'mergedFromGuest': wasGuest,
      },
    );
    return _hasCompleteOnboarding(state);
  }

  static bool _hasCompleteOnboarding(UserProfile p) =>
      p.persona.isNotEmpty &&
      p.knowledgeLevel.isNotEmpty &&
      p.dailyGoal > 0 &&
      p.selectedTopics.isNotEmpty;

  Future<void> signOutKeepProgress() async {
    final previousUid = state.firebaseUid;
    state = state.copyWith(
      isGuest: true,
      firebaseUid: null,
      email: null,
      name: null,
      photoUrl: null,
    );
    await _flushSave();
    if (previousUid != null) {
      _telemetry?.log(
        'user_sign_out',
        guestId: state.id,
        userId: previousUid,
      );
    }
  }

  Future<void> setOnboardingData({
    required String persona,
    required String knowledgeLevel,
    required List<String> topics,
    required int dailyGoal,
    bool stayGuest = false,
  }) async {
    state = state.copyWith(
      persona: persona,
      knowledgeLevel: knowledgeLevel,
      selectedTopics: topics,
      dailyGoal: dailyGoal,
      isGuest: stayGuest,
    );
    await _flushSave();
    await _prefs.saveOnboardingComplete(true);
  }

  // -------------------------------------------------------------------------
  // Quizzes
  // -------------------------------------------------------------------------

  Future<void> recordQuizPass() async {
    state = state.copyWith(quizzesPassed: state.quizzesPassed + 1);
    _scheduleSave();
    await addXP(XPConstants.quizPass, source: 'quiz_pass');
  }

  // -------------------------------------------------------------------------
  // Feedback settings
  // -------------------------------------------------------------------------

  Future<void> setHapticsEnabled(bool v) async {
    state = state.copyWith(hapticsEnabled: v);
    _scheduleSave();
  }

  Future<void> setSoundEnabled(bool v) async {
    state = state.copyWith(soundEnabled: v);
    _scheduleSave();
  }

  // -------------------------------------------------------------------------
  // Notifications
  // -------------------------------------------------------------------------

  /// Toggles the daily reminder. On enable, requests system permission and
  /// schedules. If the user denies, state stays disabled (UI reflects
  /// reality, not the user's wish).
  Future<bool> setNotificationsEnabled(bool v) async {
    if (v) {
      final granted = await NotificationService.instance.requestPermission();
      if (!granted) {
        // Reflect the denial in state — UI toggle should show OFF.
        state = state.copyWith(notificationsEnabled: false);
        await _flushSave();
        return false;
      }
      await NotificationService.instance
          .scheduleDaily(state.reminderMinutesSinceMidnight);
    } else {
      await NotificationService.instance.cancel();
    }
    state = state.copyWith(notificationsEnabled: v);
    await _flushSave();
    return true;
  }

  Future<void> setReminderTime(int minutesSinceMidnight) async {
    final clamped = minutesSinceMidnight.clamp(0, 24 * 60 - 1);
    state =
        state.copyWith(reminderMinutesSinceMidnight: clamped);
    await _flushSave();
    if (state.notificationsEnabled) {
      await NotificationService.instance.scheduleDaily(clamped);
    }
  }

  /// Toggles FCM news-topic subscription. On enable, prompts the user for
  /// system permission (Android 13+ / iOS) and subscribes the device.
  /// State reflects reality: if permission is denied, the toggle stays off.
  Future<bool> setPushEnabled(bool v) async {
    final svc = _ref?.read(newsPushServiceProvider);
    if (svc == null) {
      // Tests / harness without a Ref — treat as a no-op success.
      state = state.copyWith(pushNotificationsEnabled: v);
      await _flushSave();
      return v;
    }
    if (v) {
      final granted = await svc.requestPermissionAndSubscribe();
      state = state.copyWith(pushNotificationsEnabled: granted);
      await _flushSave();
      return granted;
    }
    await svc.unsubscribe();
    state = state.copyWith(pushNotificationsEnabled: false);
    await _flushSave();
    return true;
  }

  // -------------------------------------------------------------------------
  // Profile editing
  // -------------------------------------------------------------------------

  /// Updates the user-editable profile fields in one atomic save.
  Future<void> updateProfileFields({
    String? name,
    String? email,
    int? dailyGoal,
    String? persona,
    String? knowledgeLevel,
    List<String>? selectedTopics,
  }) async {
    state = state.copyWith(
      name: name,
      email: email,
      dailyGoal: dailyGoal,
      persona: persona,
      knowledgeLevel: knowledgeLevel,
      selectedTopics: selectedTopics,
    );
    await _flushSave();
  }

  // -------------------------------------------------------------------------
  // Boss quiz reward (gated to one-time per track)
  // -------------------------------------------------------------------------

  /// Awards track-complete XP iff this is the first successful boss quiz
  /// for [trackId]. Returns true when XP was actually awarded.
  Future<bool> awardBossQuizCompletion(String trackId) async {
    final current = state.trackProgress[trackId] ?? 0;
    final progress = Map<String, int>.from(state.trackProgress);
    progress[trackId] = current + 1;
    state = state.copyWith(trackProgress: progress);
    _scheduleSave();

    if (current > 0) return false; // replay — no XP.
    await addXP(XPConstants.trackComplete, source: 'track_complete:$trackId');
    return true;
  }
}

final userProvider = StateNotifierProvider<UserNotifier, UserProfile>((ref) {
  return UserNotifier.create(ref: ref);
});
