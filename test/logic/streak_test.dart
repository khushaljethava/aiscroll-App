import 'package:aiscroll/data/local/preferences_service.dart';
import 'package:aiscroll/data/models/user_model.dart';
import 'package:aiscroll/data/providers/user_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Streak regressions: markCardRead used to stamp lastActiveDate before
/// updateStreak ran (streak stuck at 1), and load() + updateStreak both
/// spent a freeze for the same missed day.
void main() {
  Future<UserNotifier> notifierWith({
    required int daysAgo,
    required int streak,
    int freezes = 0,
  }) async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
    await PreferencesService.instance.saveUserProfile(UserProfile(
      id: 'guest-test',
      isGuest: true,
      inviteCode: 'ABC234',
      currentStreak: streak,
      longestStreak: streak,
      freezesAvailable: freezes,
      lastActiveDate: DateTime.now().subtract(Duration(days: daysAgo)),
      // Freeze grant timer set to today so weekly housekeeping stays out.
      lastFreezeGrantedAt: DateTime.now(),
    ));
    final n = UserNotifier.create();
    await n.load();
    return n;
  }

  test('reading on the next day grows the streak', () async {
    final n = await notifierWith(daysAgo: 1, streak: 3);
    await n.markCardRead('c1');
    expect(n.state.currentStreak, 4);
    expect(n.state.longestStreak, 4);
  });

  test('second read on the same day does not change the streak', () async {
    final n = await notifierWith(daysAgo: 1, streak: 3);
    await n.markCardRead('c1');
    await n.markCardRead('c2');
    expect(n.state.currentStreak, 4);
  });

  test('one missed day with a freeze spends exactly one freeze', () async {
    final n = await notifierWith(daysAgo: 2, streak: 3, freezes: 2);
    await n.markCardRead('c1');
    expect(n.state.currentStreak, 4);
    expect(n.state.freezesAvailable, 1);
  });

  test('one missed day without a freeze restarts the streak', () async {
    final n = await notifierWith(daysAgo: 2, streak: 3);
    await n.markCardRead('c1');
    expect(n.state.currentStreak, 1);
  });

  test('streak badges are granted from state', () async {
    final n = await notifierWith(daysAgo: 1, streak: 6);
    await n.markCardRead('c1');
    expect(n.state.earnedBadgeIds, containsAll(['first_flame', 'week_warrior']));
  });
}
