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

double _hueGap(Color a, Color b) {
  final d = (HSVColor.fromColor(a).hue - HSVColor.fromColor(b).hue).abs();
  return d > 180 ? 360 - d : d;
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('brand accent is the Stitch cobalt and distinct from status reds', () {
    expect(AppColors.brandAccent, const Color(0xFF2F5BFF));
    // Buttons must never read as an error: blue vs red differ in hue, not
    // brightness, so compare hue angles rather than luminance contrast.
    expect(_hueGap(AppColors.brandAccent, AppColors.error), greaterThan(90));
    expect(_hueGap(AppColors.brandAccent, AppColors.advanced), greaterThan(90));
  });

  test('accent text and fills pass WCAG AA in both themes', () {
    expect(_contrast(AppColors.brandAccent, AppColors.onBrand), greaterThanOrEqualTo(4.5));
    expect(_contrast(AppColors.brandAccent, AppColors.paper), greaterThanOrEqualTo(4.5));
    expect(_contrast(AppColors.brandAccentOnInk, AppColors.onBrandOnInk), greaterThanOrEqualTo(4.5));
    expect(_contrast(AppColors.brandAccentOnInk, AppColors.inkBlack), greaterThanOrEqualTo(4.5));
  });

  testWidgets('theme primary is cobalt: base on paper, lighter on ink',
      (WidgetTester tester) async {
    expect(AppTheme.lightTheme.colorScheme.primary, AppColors.brandAccent);
    expect(AppTheme.darkTheme.colorScheme.primary, AppColors.brandAccentOnInk);
    // Drain any pending google_fonts async font-load callbacks so they don't
    // leak past test teardown and cause a spurious failure.
    await tester.pump();
  });

  test('primary button renders the brand accent, not the legacy indigo', () {
    final cases = {
      AppTheme.lightTheme: (AppColors.brandAccent, AppColors.onBrand),
      AppTheme.darkTheme: (AppColors.brandAccentOnInk, AppColors.onBrandOnInk),
    };
    cases.forEach((theme, colors) {
      final style = theme.elevatedButtonTheme.style;
      expect(style?.backgroundColor?.resolve(<WidgetState>{}), colors.$1);
      expect(style?.foregroundColor?.resolve(<WidgetState>{}), colors.$2);
      expect(style?.backgroundColor?.resolve(<WidgetState>{}), isNot(AppColors.primary));
    });
  });
}
