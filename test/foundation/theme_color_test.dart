import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aiscroll/core/theme/app_colors.dart';
import 'package:aiscroll/core/theme/app_theme.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('brand coral defined and distinct from status reds', () {
    expect(AppColors.brandCoral, const Color(0xFFFF5A4D));
    expect(_contrast(AppColors.brandCoral, AppColors.error), greaterThan(1.4));
    expect(_contrast(AppColors.brandCoral, AppColors.advanced), greaterThan(1.4));
  });

  test('coral button text passes WCAG AA', () {
    expect(_contrast(AppColors.brandCoral, AppColors.onCoral),
        greaterThanOrEqualTo(4.5));
  });

  test('theme primary is coral in both brightnesses', () {
    expect(AppTheme.darkTheme.colorScheme.primary, AppColors.brandCoral);
    expect(AppTheme.lightTheme.colorScheme.primary, AppColors.brandCoral);
  });
}
