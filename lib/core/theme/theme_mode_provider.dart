import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/preferences_service.dart';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier()
      : super(_indexToMode(PreferencesService.instance.loadThemeModeIndex()));

  static ThemeMode _indexToMode(int idx) {
    switch (idx) {
      case 1:
        return ThemeMode.light;
      case 2:
        return ThemeMode.dark;
      case 0:
      default:
        return ThemeMode.system;
    }
  }

  static int _modeToIndex(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 0;
      case ThemeMode.light:
        return 1;
      case ThemeMode.dark:
        return 2;
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await PreferencesService.instance.saveThemeModeIndex(_modeToIndex(mode));
  }

  Future<void> toggleDark(bool isDark) =>
      set(isDark ? ThemeMode.dark : ThemeMode.light);
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});
