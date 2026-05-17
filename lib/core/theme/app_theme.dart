import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_semantic_colors.dart';
import 'app_spacing.dart';

/// Editorial theme for 60 Second AI.
///
/// Typography blends two Google Fonts:
///  - **Newsreader** (serif) for display/headline — gives the News feature
///    its magazine feel and pairs well with photo covers.
///  - **Inter** (sans) for titles, labels, body — keeps UI chrome crisp
///    and matches what the rest of the app already used.
///
/// Shape tokens live in [AppRadius]; motion tokens in [AppMotion].
class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    const scaffold = AppColors.inkBlack;
    return base.copyWith(
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: AppColors.primary,
        onPrimary: AppColors.textPrimary,
        primaryContainer: AppColors.inkSurface,
        onPrimaryContainer: AppColors.textPrimary,
        secondary: AppColors.ctaAmber,
        onSecondary: Color(0xFF1A1200),
        secondaryContainer: Color(0xFF3A2A00),
        onSecondaryContainer: AppColors.ctaAmber,
        tertiary: AppColors.accent,
        onTertiary: AppColors.textPrimary,
        tertiaryContainer: Color(0xFF064E3B),
        onTertiaryContainer: AppColors.accent,
        error: AppColors.error,
        onError: AppColors.textPrimary,
        errorContainer: Color(0xFF7F1D1D),
        onErrorContainer: AppColors.error,
        surface: AppColors.inkSurface,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.inkSurface2,
        onSurfaceVariant: AppColors.textMutedOnInk,
        outline: Color(0xFF3A3A40),
        outlineVariant: Color(0xFF28282E),
        shadow: Colors.black,
        scrim: Colors.black54,
        inverseSurface: AppColors.paper,
        onInverseSurface: AppColors.inkOnPaper,
        inversePrimary: AppColors.primary,
      ),
      scaffoldBackgroundColor: scaffold,
      textTheme: _buildTextTheme(base.textTheme, AppColors.textPrimary),
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffold,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.textPrimary,
        titleSpacing: AppSpacing.screenGutter,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.inkSurface,
        selectedItemColor: AppColors.textPrimary,
        unselectedItemColor: AppColors.textMutedOnInk,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.inkSurface,
        indicatorColor: Colors.white.withValues(alpha: 0.06),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.textPrimary, size: 24);
          }
          return const IconThemeData(color: AppColors.textMutedOnInk, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            );
          }
          return GoogleFonts.inter(
            color: AppColors.textMutedOnInk,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          );
        }),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: AppColors.inkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inkSurface2,
        border: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: const TextStyle(color: AppColors.textMutedOnInk),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.input),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.inkHairline),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.input),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.inkSurface2,
        selectedColor: Colors.white.withValues(alpha: 0.10),
        labelStyle: GoogleFonts.inter(
          color: AppColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.chip),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 6,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.inkHairline,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: AppColors.textMutedOnInk),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.textPrimary,
        linearTrackColor: AppColors.inkSurface2,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.inkSurface2,
        contentTextStyle: GoogleFonts.inter(
          color: AppColors.textPrimary,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.input),
        behavior: SnackBarBehavior.floating,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.inkSurface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.inkSurface,
        modalBarrierColor: Colors.black54,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.inkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.inter(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: GoogleFonts.inter(
          color: AppColors.textMutedOnInk,
          fontSize: 14,
          height: 1.5,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textMutedOnInk,
        textColor: AppColors.textPrimary,
      ),
      extensions: const [AppSemanticColors.dark],
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    const scaffold = AppColors.paper;
    return base.copyWith(
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFE0E7FF),
        onPrimaryContainer: Color(0xFF3730A3),
        secondary: AppColors.ctaAmber,
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFFEF3C7),
        onSecondaryContainer: Color(0xFF78350F),
        tertiary: AppColors.accent,
        onTertiary: Colors.white,
        tertiaryContainer: Color(0xFFD1FAE5),
        onTertiaryContainer: Color(0xFF065F46),
        error: AppColors.error,
        onError: Colors.white,
        errorContainer: Color(0xFFFEE2E2),
        onErrorContainer: Color(0xFF991B1B),
        surface: Colors.white,
        onSurface: AppColors.inkOnPaper,
        surfaceContainerHighest: AppColors.paperMuted,
        onSurfaceVariant: AppColors.inkMutedOnPaper,
        outline: Color(0xFFD8D3C7),
        outlineVariant: Color(0xFFE8E4DA),
        shadow: Colors.black12,
        scrim: Colors.black26,
        inverseSurface: AppColors.inkBlack,
        onInverseSurface: AppColors.textPrimary,
        inversePrimary: Color(0xFFA5B4FC),
      ),
      scaffoldBackgroundColor: scaffold,
      textTheme: _buildTextTheme(base.textTheme, AppColors.inkOnPaper),
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffold,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.inkOnPaper,
        titleSpacing: AppSpacing.screenGutter,
        titleTextStyle: TextStyle(
          color: AppColors.inkOnPaper,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.inkOnPaper,
        unselectedItemColor: AppColors.inkMutedOnPaper,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.inkOnPaper.withValues(alpha: 0.06),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.inkOnPaper);
          }
          return const IconThemeData(color: AppColors.inkMutedOnPaper);
        }),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: const BorderSide(color: AppColors.paperHairline),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(color: AppColors.paperHairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(color: AppColors.paperHairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
        hintStyle: const TextStyle(color: AppColors.inkMutedOnPaper),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.input),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.paperHairline,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.paperMuted,
        selectedColor: AppColors.inkOnPaper.withValues(alpha: 0.08),
        labelStyle: GoogleFonts.inter(
          color: AppColors.inkOnPaper,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.chip),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 6,
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.inkMutedOnPaper),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.inkOnPaper,
        linearTrackColor: AppColors.paperMuted,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.inkOnPaper,
        contentTextStyle: GoogleFonts.inter(
          color: AppColors.paper,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.input),
        behavior: SnackBarBehavior.floating,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: Colors.white,
        modalBarrierColor: Colors.black38,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.inter(
          color: AppColors.inkOnPaper,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: GoogleFonts.inter(
          color: AppColors.inkMutedOnPaper,
          fontSize: 14,
          height: 1.5,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.inkMutedOnPaper,
        textColor: AppColors.inkOnPaper,
      ),
      extensions: const [AppSemanticColors.light],
    );
  }

  // --- Text theme -----------------------------------------------------------

  /// Builds the app text theme. Display/headline sizes use **Newsreader**
  /// (editorial serif); titles, body and labels use **Inter**.
  static TextTheme _buildTextTheme(TextTheme base, Color textColor) {
    return GoogleFonts.interTextTheme(base).copyWith(
      displayLarge: GoogleFonts.newsreader(
        fontSize: 57,
        fontWeight: FontWeight.w700,
        color: textColor,
        letterSpacing: -1.4,
        height: 1.02,
      ),
      displayMedium: GoogleFonts.newsreader(
        fontSize: 45,
        fontWeight: FontWeight.w700,
        color: textColor,
        letterSpacing: -1.1,
        height: 1.04,
      ),
      displaySmall: GoogleFonts.newsreader(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: textColor,
        letterSpacing: -0.7,
        height: 1.08,
      ),
      headlineLarge: GoogleFonts.newsreader(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: textColor,
        letterSpacing: -0.5,
        height: 1.12,
      ),
      headlineMedium: GoogleFonts.newsreader(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: textColor,
        letterSpacing: -0.4,
        height: 1.16,
      ),
      headlineSmall: GoogleFonts.newsreader(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: textColor,
        letterSpacing: -0.3,
        height: 1.2,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: textColor,
        letterSpacing: -0.2,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textColor,
        letterSpacing: 0,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textColor,
        letterSpacing: 0.1,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textColor,
        height: 1.65,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textColor,
        height: 1.55,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textColor,
        height: 1.45,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: textColor,
        letterSpacing: 0.3,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: textColor,
        letterSpacing: 0.8,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: textColor,
        letterSpacing: 1.1,
      ),
    );
  }
}
