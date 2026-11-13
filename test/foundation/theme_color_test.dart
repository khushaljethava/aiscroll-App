import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aiscroll/core/theme/app_colors.dart';
import 'package:aiscroll/core/theme/app_theme.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('brand coral defined and distinct from status reds', () {
    expect(AppColors.brandCoral, const Color(0xFFFF5A4D));
    expect(_contrast(AppColors.brandCoral, AppColors.error), greaterThan(1.4));
    expect(_contrast(AppColors.brandCoral, AppColors.advanced), greaterThan(1.4));
  });

  test('coral button text passes WCAG AA', () {
    expect(_contrast(AppColors.brandCoral, AppColors.onCoral),
        greaterThanOrEqualTo(4.5));
  });

  testWidgets('theme primary is coral in both brightnesses',
      (WidgetTester tester) async {
    expect(AppTheme.darkTheme.colorScheme.primary, AppColors.brandCoral);
    expect(AppTheme.lightTheme.colorScheme.primary, AppColors.brandCoral);
    // Drain any pending google_fonts async font-load callbacks so they don't
    // leak past test teardown and cause a spurious failure.
    await tester.pump();
  });

  test('primary button theme renders coral, not indigo', () {
    for (final theme in [AppTheme.darkTheme, AppTheme.lightTheme]) {
      final bg = theme.elevatedButtonTheme.style?.backgroundColor
          ?.resolve(<WidgetState>{});
      expect(bg, AppColors.brandCoral,
          reason: 'ElevatedButton must use coral, not indigo');
      final fg = theme.elevatedButtonTheme.style?.foregroundColor
          ?.resolve(<WidgetState>{});
      expect(fg, AppColors.onCoral);
    }
  });
}
