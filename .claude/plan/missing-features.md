# Implementation Plan: Missing Features (Notifications, Boss Quiz, Profile Edit, Search, Streak Freeze, Haptics)

> **Scope**: Six standalone features that close obvious gaps. Bundled because each is small (≤ ½ day) and they share zero data — no benefit to splitting them across separate plans.
> **Order**: smallest first to build momentum (haptics → streak freeze → search → profile edit → boss quiz → notifications).

---

## Task Type
- [x] Frontend (new screens, search bars, edit form)
- [x] Backend (UserProfile fields, NotificationService, streak math)
- [x] Native config (Android `POST_NOTIFICATIONS`, iOS `DarwinInitializationSettings`)

---

## Architecture Decisions (cross-checked)

| # | Decision | Rationale |
|---|---|---|
| A | **NotificationService singleton**, called from `UserNotifier` mutators | `flutter_local_notifications` is imperative — modeling as reactive provider invites double-scheduling. Profile is state-of-record; service owns the OS contract. |
| B | Streak freeze grant lives in a separate **`weeklyHousekeeping()`** invoked from `load()`; only **one freeze consumable per gap** | Weekly cadence ≠ daily cadence; conflating makes future tuning painful. One-per-gap matches Duolingo, prevents hoard-and-disappear. |
| C | Boss quiz XP is **one-time per track**; replay allowed for practice (no XP) | Unbounded XP farming via the easiest content destroys the economy. Decouple XP grant from `trackProgress` increment — check-then-award. |
| D | Sound uses **`SystemSound.play(SystemSoundType.click)`** (no new dep) gated by a settings toggle | Audioplayers/just_audio adds ~300 KB to the binary for one click sfx; system sound is free and platform-native. |

---

## Feature 1 — Haptics + Sound

### What
Subtle feedback at every meaningful interaction. Sound is opt-in (default OFF) — most users dislike app sounds. Haptics on by default but toggleable.

### Touchpoints
- `lib/data/models/user_model.dart` → add `bool hapticsEnabled = true`, `bool soundEnabled = false`.
- New `lib/core/feedback/feedback_service.dart`:
  ```dart
  class FeedbackService {
    static void light(WidgetRef ref) { /* if hapticsEnabled: HapticFeedback.lightImpact() */ }
    static void medium(WidgetRef ref) { ... }
    static void heavy(WidgetRef ref) { ... }
    static void click(WidgetRef ref) { /* if soundEnabled: SystemSound.play(SystemSoundType.click) */ }
    static void success(WidgetRef ref) { medium(ref); click(ref); }
  }
  ```
- Wire calls at:
  - **light**: card double-tap (already triggers like), bookmark toggle (`feed_screen._handleBookmark`), card tap-to-expand (`learning_card_widget`), quiz option select (`_OptionButton.onTap`), page change in feed.
  - **medium**: right-swipe "Learned" (`feed_screen._onLearnedSwipe`), quiz pass (`feed_screen._buildQuizPage onAnswer correct`).
  - **heavy / success**: boss quiz pass (Feature 5), level-up trigger (`gamification_provider.triggerLevelUp`).
- Add toggles in `profile_screen.dart` settings section: `SwitchListTile` for "Haptic feedback" and "Sound effects".

### New `UserNotifier` methods
```dart
Future<void> setHapticsEnabled(bool v) => ... copyWith + _scheduleSave
Future<void> setSoundEnabled(bool v)   => ...
```

---

## Feature 2 — Streak Freeze

### What
Once-a-week safety net so users don't lose a long streak from one bad day. Granted weekly, consumed automatically when needed, capped at 2.

### UserProfile additions
```dart
final int freezesAvailable;   // default 1, max 2
final int freezesUsedTotal;   // lifetime counter for stats
final DateTime? lastFreezeGrantedAt;
```

### Logic — `lib/data/providers/user_provider.dart`

**`updateStreak()` (modify existing)** — when computing missed-day diff:
```
if diff == 0 OR diff == 1: existing logic, unchanged
elif diff == 2 AND freezesAvailable > 0:
  state.copyWith(
    freezesAvailable: freezesAvailable - 1,
    freezesUsedTotal: freezesUsedTotal + 1,
    lastActiveDate: now,
    // currentStreak unchanged — we "patched" yesterday
  )
else:
  // diff >= 2 with no freezes, or diff >= 3: reset (one freeze max per gap)
  state.copyWith(currentStreak: 1, lastActiveDate: now)
```

**New `weeklyHousekeeping()`** — called from `load()`:
```
if lastFreezeGrantedAt is null OR (today - lastFreezeGrantedAt).inDays >= 7:
  if freezesAvailable < 2:
    state.copyWith(
      freezesAvailable: freezesAvailable + 1,
      lastFreezeGrantedAt: today,
    )
```

### UI
- `feed_screen._StreakWidget` → if `freezesAvailable > 0`, show a small ❄️ chip next to the flame: "🔥 5 day streak · ❄️1".
- Profile stat: replace 4-up with 5-up if it fits, else add a "Freezes used" stat to the existing row.

### Tests
- `streak_freeze_test.dart`:
  - diff=2, freezes=1 → streak unchanged, freezes decremented
  - diff=2, freezes=0 → streak reset
  - diff=3, freezes=1 → streak reset (only one consumed, not enough)
  - weeklyHousekeeping grants on day 7+ and not before
  - Cap of 2 — third weekly grant is no-op

---

## Feature 3 — Search + Filter on Saved/Tracks

### What
Single SearchBar at the top of each screen; debounced 150ms; filters in-memory. No backend.

### Saved screen — `lib/features/saved/screens/saved_screen.dart`
- Convert from `ConsumerWidget` to `ConsumerStatefulWidget` (need TextEditingController).
- Add SliverAppBar `bottom: PreferredSize(child: _SearchField(...))`.
- Filter: `card.title.toLowerCase().contains(q) || card.takeaway.toLowerCase().contains(q) || card.topicTag.toLowerCase().contains(q)`.
- Empty result: "No matches for '<q>'" placeholder above the regular empty state.

### Tracks screen — `lib/features/tracks/screens/tracks_screen.dart`
- Already has a `_FilterRow` (difficulty chips). Add a `_SearchField` above it in the SliverToBoxAdapter.
- Filter: `track.name.contains(q) || track.description.contains(q) || any(card.title for card in track.cardIds where card.id matches)`.
- Combine with existing difficulty filter (intersection).

### New shared widget
`lib/shared/widgets/search_field.dart`:
```dart
class SearchField extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final String hintText;
  // Internal: TextEditingController, debounce Timer (150ms)
}
```

### Tests
- `search_field_test.dart`: debounces — 5 keystrokes within 150ms produce 1 onChanged call.

---

## Feature 4 — Profile Editing

### What
Let users change name, email, daily goal, persona, knowledge level, topics — anything captured in onboarding plus name/email which were never editable.

### New screen — `lib/features/profile/screens/edit_profile_screen.dart`
Form with sections matching the onboarding visual style:
- **Identity**: name `TextFormField` (max 30 chars), email `TextFormField` (optional, validated on submit only)
- **Persona**: 3 chips (student/professional/curious), reusing the visual style from `persona_screen.dart`
- **Knowledge level**: slider 0-3, reusing `_StyledSlider` extracted to a shared file
- **Topics**: multi-select chip wrap, reusing `_TopicChip` extracted to a shared file
- **Daily goal**: 3 chips (5/10/15) reusing the visual style from `daily_goal_screen.dart`

Bottom: Save button (disabled when no changes), Cancel button.

### Routing
- New route `AppRoutes.profileEdit = '/profile/edit'` mounted as a top-level route (full-screen, no bottom nav).
- `profile_screen.dart` settings section → "Edit profile" tile that pushes the route.

### State
- Local `EditProfileState` inside the screen; on Save, build a `UserProfile.copyWith(...)` and call `userProvider.notifier.saveProfile(updated)` (which flushes immediately).

### Validation
- Name required (≥ 1 char trimmed).
- Email if non-empty must match a simple regex.
- Daily goal must be > 0 (the chips guarantee this).
- Topics: must keep ≥ 3 (matches onboarding requirement).

### Refactor opportunity (optional, scoped)
Extract `_StyledSlider`, `_TopicChip`, `_GoalCard` from the onboarding screens into `lib/features/onboarding/widgets/` so both flows share them. Keeps onboarding as the canonical visual; edit reuses without copy-paste drift.

### Tests
- Widget test: opening edit screen pre-populates current values; tapping Save with changes calls `saveProfile`.

---

## Feature 5 — Boss Quiz

### What
Real boss quiz screen replacing the TODO dialog in `track_detail_screen.dart`. Random 5-7 questions from the track's quiz pool, 70% pass threshold, one-time 200 XP reward per track.

### New screen — `lib/features/tracks/screens/boss_quiz_screen.dart`
- `ConsumerStatefulWidget` taking `trackId`.
- On init: load all `seedQuizzes` where `parentCardId in track.cardIds`, shuffle, take `min(7, available)`. If fewer than 3, show error: "Not enough quiz content to run the boss quiz" (defensive).
- Render question by question — reuse `QuizCardWidget` with `onAnswer` capturing `(correct, parentCardId)` into a local `List<bool> answers`.
- After last question: show `_BossResultScreen`:
  - Score: `correct / total` (e.g., "5 / 7")
  - Pass threshold: 70% → ⌈total * 0.7⌉ correct required.
  - On pass:
    - If `userProfile.trackProgress[trackId] == 0` (first pass): award `XPConstants.trackComplete` (200), `triggerXP(200)`, increment `trackProgress[trackId]`, set `gamificationProvider.triggerLevelUp` if XP crossed a threshold.
    - If already passed: show "Already mastered — replay for practice". No XP, no progress increment. Architect's call: keep the XP economy clean.
  - On fail: show retry button + "back to track" button. Track progress unchanged.
- SRS hook: each answer also fires `srsProvider.recordReview(parentCardId, correct ? 5 : 1)`.
- Quest hook: each correct answer fires `questsProvider.recordEvent(QuestType.passQuiz)`.

### Routing
- New route `'/tracks/:trackId/quiz'` nested under the existing tracks branch.
- `_BossQuizButton` in `track_detail_screen.dart` → `context.push('/tracks/$trackId/quiz')` instead of dialog.

### Helpers
`lib/features/tracks/providers/boss_quiz_provider.dart`:
```dart
final bossQuizQuestionsProvider =
    Provider.family<List<QuizQuestion>, String>((ref, trackId) {
  final track = ref.watch(trackByIdProvider(trackId))!;
  final all = ref.watch(allQuizzesProvider);
  final pool = all.where((q) => track.cardIds.contains(q.parentCardId)).toList()
    ..shuffle();
  return pool.take(7).toList();
});
```

### Tests
- `boss_quiz_logic_test.dart`:
  - Pool selection: returns ≤ 7 questions, all parent cards in track.
  - Pass threshold: 5/7 passes (71%), 4/7 fails (57%).
  - Reward gating: first pass awards 200 XP, second pass does not.

---

## Feature 6 — Daily Reminder Notifications

### What
Local notification at user-chosen time daily. Default 8 AM. Toggleable. Asks for permission on first enable.

### Dependencies (`pubspec.yaml`)
```yaml
flutter_local_notifications: ^17.0.0
timezone: ^0.9.4
```

### UserProfile additions
```dart
final bool notificationsEnabled;          // default false (require explicit opt-in)
final int reminderMinutesSinceMidnight;   // default 480 (8:00 AM)
```

### New service — `lib/core/notifications/notification_service.dart`

```dart
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _dailyId = 1001;
  static const _channelId = 'daily_reminder';
  static const _channelName = 'Daily Reminder';

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    final localTz = tz.getLocation(await _localTzName());
    tz.setLocalLocation(localTz);

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,   // we ask explicitly via toggle
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _initialized = true;
  }

  /// Returns true if granted. Triggers OS prompt on first call.
  Future<bool> requestPermission() async {
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, badge: true, sound: true)
          ?? false;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? true;
    }
    return true;
  }

  Future<void> scheduleDaily(int minutesSinceMidnight) async {
    await initialize();
    await cancel();

    final now = tz.TZDateTime.now(tz.local);
    var firstFire = tz.TZDateTime(
      tz.local, now.year, now.month, now.day,
      minutesSinceMidnight ~/ 60, minutesSinceMidnight % 60,
    );
    if (!firstFire.isAfter(now)) {
      firstFire = firstFire.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _dailyId,
      'Time to learn 🤖',
      _randomTagline(),
      firstFire,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId, _channelName,
          channelDescription: 'Daily learning reminder',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,  // repeat daily
      uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancel() async {
    await initialize();
    await _plugin.cancel(_dailyId);
  }

  String _randomTagline() {
    const taglines = [
      'Don\'t break your streak — one card today.',
      'Two minutes is all it takes.',
      'Your daily AI dose is ready.',
      'Knowledge compounds. Today\'s the day.',
    ];
    return taglines[DateTime.now().millisecondsSinceEpoch % taglines.length];
  }

  Future<String> _localTzName() async {
    // For v1, default to UTC if detection fails. Future: flutter_native_timezone.
    return DateTime.now().timeZoneName;  // fallback
  }
}
```

### Wiring

`lib/main.dart`:
```dart
await PreferencesService.init();
await NotificationService.instance.initialize();
runApp(...);
```

`lib/data/providers/user_provider.dart` — new mutators:
```dart
Future<void> setNotificationsEnabled(bool v) async {
  if (v) {
    final granted = await NotificationService.instance.requestPermission();
    if (!granted) return;  // user denied — don't flip the switch
    await NotificationService.instance
        .scheduleDaily(state.reminderMinutesSinceMidnight);
  } else {
    await NotificationService.instance.cancel();
  }
  state = state.copyWith(notificationsEnabled: v);
  await _flushSave();
}

Future<void> setReminderTime(int minutesSinceMidnight) async {
  state = state.copyWith(reminderMinutesSinceMidnight: minutesSinceMidnight);
  await _flushSave();
  if (state.notificationsEnabled) {
    await NotificationService.instance.scheduleDaily(minutesSinceMidnight);
  }
}
```

`lib/features/profile/screens/profile_screen.dart` Daily Reminder tile:
```dart
SwitchListTile(
  secondary: const Icon(Icons.notifications_rounded),
  title: const Text('Daily reminder'),
  subtitle: Text(_formatMinutes(user.reminderMinutesSinceMidnight)),
  value: user.notificationsEnabled,
  onChanged: (v) => ref.read(userProvider.notifier).setNotificationsEnabled(v),
),
ListTile(
  leading: const Icon(Icons.access_time_rounded),
  title: const Text('Reminder time'),
  enabled: user.notificationsEnabled,
  trailing: Text(_formatMinutes(user.reminderMinutesSinceMidnight)),
  onTap: () async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: user.reminderMinutesSinceMidnight ~/ 60,
        minute: user.reminderMinutesSinceMidnight % 60,
      ),
    );
    if (picked != null) {
      await ref.read(userProvider.notifier).setReminderTime(
        picked.hour * 60 + picked.minute,
      );
    }
  },
),
```

### Native config

**Android** — `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```
Inside `<application>`:
```xml
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
  <intent-filter>
    <action android:name="android.intent.action.BOOT_COMPLETED"/>
  </intent-filter>
</receiver>
```

**iOS** — `ios/Runner/Info.plist` already supports user notifications by default; no change needed for v1.

### Tests
- `notification_user_methods_test.dart`: mocks `NotificationService` (extract a thin interface), verifies that `setNotificationsEnabled(false)` calls `cancel()` and `setReminderTime` reschedules only when enabled. Skip the actual platform call (would need integration tests).

---

## Implementation Order (recommended)

1. **Haptics + sound** (~1h) — smallest, builds momentum, unblocks other features (boss quiz wants `success()` haptic).
2. **Streak freeze** (~2h) — pure UserNotifier work, well-tested logic.
3. **Search + filter** (~2h) — frontend-only, two screens.
4. **Profile editing** (~3h) — new screen + light refactor of shared chip widgets.
5. **Boss quiz** (~3h) — new screen + new route + result screen.
6. **Notifications** (~4h) — biggest unknown (native config, permissions).

**Total**: ~½ day for the small stuff, full day for boss quiz + notifications. Spread across one work day.

---

## Key Files

| File | Operation | Description |
|------|-----------|-------------|
| `lib/data/models/user_model.dart` | **Modify** | Add `hapticsEnabled`, `soundEnabled`, `freezesAvailable`, `freezesUsedTotal`, `lastFreezeGrantedAt`, `notificationsEnabled`, `reminderMinutesSinceMidnight` |
| `lib/data/providers/user_provider.dart` | **Modify** | Mutators for all new fields; `weeklyHousekeeping()` in `load()`; freeze logic in `updateStreak()` |
| `lib/core/feedback/feedback_service.dart` | **Create** | Static helpers for haptic + sound feedback gated by user settings |
| `lib/core/notifications/notification_service.dart` | **Create** | Singleton wrapping `flutter_local_notifications` |
| `lib/main.dart` | **Modify** | `await NotificationService.instance.initialize()` after `PreferencesService.init()` |
| `lib/shared/widgets/search_field.dart` | **Create** | Debounced search input |
| `lib/features/saved/screens/saved_screen.dart` | **Modify** | Convert to `ConsumerStatefulWidget`, add SearchField, filter list |
| `lib/features/tracks/screens/tracks_screen.dart` | **Modify** | Add SearchField above existing FilterRow |
| `lib/features/profile/screens/profile_screen.dart` | **Modify** | Edit profile tile, haptics/sound toggles, real reminder switch + time picker, freezes-used stat |
| `lib/features/profile/screens/edit_profile_screen.dart` | **Create** | Edit screen mirroring onboarding fields |
| `lib/core/router/app_router.dart` | **Modify** | Routes for `/profile/edit` and `/tracks/:trackId/quiz` |
| `lib/features/tracks/screens/boss_quiz_screen.dart` | **Create** | Multi-question quiz runner + result screen |
| `lib/features/tracks/providers/boss_quiz_provider.dart` | **Create** | Pool selection logic |
| `lib/features/tracks/screens/track_detail_screen.dart` | **Modify** | `_BossQuizButton` → push route instead of dialog |
| `lib/features/feed/screens/feed_screen.dart` | **Modify** | Wire `FeedbackService.light/medium` at swipe/page-change/like sites; `_StreakWidget` shows freezes |
| `lib/features/feed/widgets/quiz_card_widget.dart` | **Modify** | Wire `FeedbackService.light` on option select, `medium` on correct |
| `pubspec.yaml` | **Modify** | Add `flutter_local_notifications: ^17.0.0`, `timezone: ^0.9.4` |
| `android/app/src/main/AndroidManifest.xml` | **Modify** | Add notification permissions + boot receiver |
| `test/streak_freeze_test.dart` | **Create** | Freeze grant + consumption logic |
| `test/boss_quiz_logic_test.dart` | **Create** | Pool selection, pass threshold, reward gating |
| `test/search_field_test.dart` | **Create** | Debounce behavior |
| `test/notification_user_methods_test.dart` | **Create** | UserNotifier integration with mocked NotificationService |

---

## Risks and Mitigation

| Risk | Mitigation |
|---|---|
| **Notification permissions denied** silently → switch flips on but no notification fires | `setNotificationsEnabled` returns early without flipping `state` if `requestPermission()` returns false; UI shows the switch as off so the user retries (or directs them to system settings). |
| **Timezone detection fragility** — `DateTime.timeZoneName` returns IANA names on Linux/macOS but abbreviations on Windows/some Androids | v1: fall back to UTC if `tz.getLocation` throws. Document follow-up: add `flutter_native_timezone` for production. |
| **Daily reminder fires in the past** when user picks a time earlier than now | `scheduleDaily` adds 1 day if `firstFire <= now` (covered in pseudo-code). |
| **Streak freeze double-grant** if `load()` runs twice in a session | `lastFreezeGrantedAt` check is `(today - last).inDays >= 7`, so two `load()` calls on same day are no-op. |
| **Boss quiz with insufficient pool** (track has < 3 quizzes) | `BossQuizScreen.initState` shows an error state with "back to track" button; never crashes. Track-detail's "Take Boss Quiz" button is hidden if pool < 3. |
| **Profile edit topics validation** lets user save with < 3 topics, breaking ranker assumption | Save button disabled while `selectedTopics.length < 3`; validator on the form too. |
| **Search debounce bug** — controller fires after dispose | `dispose()` cancels the debounce Timer before disposing the controller. |
| **Sound toggle on a device with no speakers / silent mode** | `SystemSound.play` is a no-op when device is silenced; no special handling needed. |
| **Haptics on devices without a vibration motor** (some tablets) | `HapticFeedback.*` is a no-op on unsupported devices; safe. |
| **Migration**: existing users have null new fields | All defaults handled in `UserProfile` constructor and `fromMap` fallbacks (already the pattern). New fields ship with `false` / `0` / `1` defaults — no data loss possible. |

---

## Acceptance Criteria

- [ ] `flutter analyze` reports 0 issues.
- [ ] `flutter test` passes (existing 30 + new ~12 = 42+).
- [ ] Toggling "Daily reminder" ON, picking 8:00 AM, killing the app, and waiting until 8:00 next day produces a system notification (manual verify).
- [ ] Boss quiz button visible only when track has ≥ 3 questions; tapping it pushes a 5-7 question quiz; passing first time awards 200 XP; passing second time shows "already mastered" message with no XP.
- [ ] Edit profile screen pre-populates current values; saving updates the profile and is visible immediately on the home header.
- [ ] Typing in Saved search filters bookmarks live; clearing the field restores the full list.
- [ ] Streak at 5 + missed yesterday + 1 freeze available → app loads with streak still 5 and freezes 0 + a "saved by freeze" indicator (toast or chip).
- [ ] Tapping the right-swipe "Learned" produces a medium haptic when haptics are enabled and nothing when disabled.
- [ ] Sound toggle off produces no `SystemSound.click` even on level-up.

---

## Out of Scope (deferred)

- **Backend sync** of notification schedules across devices (would require a server).
- **Smart reminder timing** based on user's actual learning hours.
- **Streak repair purchase** (Duolingo monetizes broken streaks; AIScroll Pro could in v2).
- **Audio sfx** beyond the system click — needs `audioplayers` and asset shipping.
- **Profile picture** — wait for backend so URLs are stable cross-device.

---

## SESSION_ID

- CODEX_SESSION: _(not used — codeagent-wrapper not installed)_
- GEMINI_SESSION: _(not used — codeagent-wrapper not installed)_
- ARCHITECT_AGENT_ID: `af0f3922f8fd9c16c` (validated NotificationService pattern, streak-freeze cadence, boss-quiz reward gating)
