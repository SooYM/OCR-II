import 'package:flutter/material.dart';

/// MedScan App Theme — Premium medical UI with Light and Dark modes.
class AppTheme {
  AppTheme._();

  // ─── Shared Brand Colors ──────────────────────────────────────────────────
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryLight = Color(0xFF8B83FF);
  static const Color primaryDark = Color(0xFF4A42DB);

  static const Color accent = Color(0xFF00D9A6);
  static const Color accentLight = Color(0xFF33E4BC);

  static const Color error = Color(0xFFFF6B6B);
  static const Color warning = Color(0xFFFFB347);
  static const Color success = Color(0xFF4ECDC4);
  static const Color info = Color(0xFF74B9FF);

  // ─── Dark Palette ─────────────────────────────────────────────────────────
  static const Color backgroundDark = Color(0xFF0F0F1A);
  static const Color surfaceDark = Color(0xFF1A1A2E);
  static const Color surfaceVariantDark = Color(0xFF222240);
  static const Color surfaceElevatedDark = Color(0xFF2A2A4A);
  static const Color borderDark = Color(0xFF333360);

  static const Color textPrimaryDark = Color(0xFFF0F0FF);
  static const Color textSecondaryDark = Color(0xFFA0A0C0);
  static const Color textTertiaryDark = Color(0xFF707090);

  // ─── Light Palette ────────────────────────────────────────────────────────
  static const Color backgroundLight = Color(0xFFF8F9FE);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFF0F2F9);
  static const Color surfaceElevatedLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE1E4F2);

  static const Color textPrimaryLight = Color(0xFF1A1A2E);
  static const Color textSecondaryLight = Color(0xFF4F5E7B);
  static const Color textTertiaryLight = Color(0xFF8C9AB5);

  // Fallback/Legacy Constants (to be replaced by Theme.of(context) where possible)
  // Fallback Constants - DO NOT USE FOR NEW CODE. Use Theme.of(context) instead.
  // These are kept to avoid immediate build errors but should be phased out.
  static const Color textSecondary = Color(0xFF707090); // Neutral fallback
  static const Color textTertiary = Color(0xFF9090B0);  // Neutral fallback
  static const Color surfaceBorder = Color(0xFFE1E4F2); // Neutral fallback
  static const Color surface = Color(0xFFFFFFFF);      // Neutral fallback
  static const Color surfaceVariant = Color(0xFFF0F2F9); // Neutral fallback

  // ─── Gradients ─────────────────────────────────────────────────────────────
  static LinearGradient primaryGradient(BuildContext context) => const LinearGradient(
    colors: [primary, Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient accentGradient(BuildContext context) => const LinearGradient(
    colors: [accent, Color(0xFF00B4D8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient backgroundGradient(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return LinearGradient(
      colors: isDark 
          ? [backgroundDark, const Color(0xFF16162D)] 
          : [backgroundLight, const Color(0xFFF2F4FF)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
  }

  // ─── Shadows ───────────────────────────────────────────────────────────────
  static List<BoxShadow> cardShadow(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: isDark ? Colors.black.withOpacity(0.3) : Colors.blueGrey.withOpacity(0.08),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ];
  }

  static List<BoxShadow> primaryShadow(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: primary.withOpacity(isDark ? 0.3 : 0.15),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ];
  }


  // ─── Border Radius ─────────────────────────────────────────────────────────
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;

  // ─── Theme Building ────────────────────────────────────────────────────────
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);
  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  static ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    final Color bgColor = isDark ? backgroundDark : backgroundLight;
    final Color surfColor = isDark ? surfaceDark : surfaceLight;
    final Color surfVariant = isDark ? surfaceVariantDark : surfaceVariantLight;
    final Color borderColor = isDark ? borderDark : borderLight;
    final Color tPrimary = isDark ? textPrimaryDark : textPrimaryLight;
    final Color tSecondary = isDark ? textSecondaryDark : textSecondaryLight;
    final Color tTertiary = isDark ? textTertiaryDark : textTertiaryLight;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bgColor,
      colorScheme: isDark
          ? const ColorScheme.dark(
              primary: primary,
              onPrimary: Colors.white,
              secondary: accent,
              onSecondary: Colors.black,
              surface: surfaceDark,
              onSurface: textPrimaryDark,
              surfaceContainerHighest: surfaceVariantDark,
              outline: borderDark,
              error: error,
              onError: Colors.white,
            )
          : const ColorScheme.light(
              primary: primary,
              onPrimary: Colors.white,
              secondary: accent,
              onSecondary: Colors.white,
              surface: surfaceLight,
              onSurface: textPrimaryLight,
              surfaceContainerHighest: surfaceVariantLight,
              outline: borderLight,
              error: error,
              onError: Colors.white,
            ),
      textTheme: (isDark ? ThemeData.dark() : ThemeData.light()).textTheme.apply(
        bodyColor: tPrimary,
        displayColor: tPrimary,
        fontFamily: 'Helvetica Neue',
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Helvetica Neue',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: tPrimary,
        ),
        iconTheme: IconThemeData(color: tPrimary),
      ),
      cardTheme: CardThemeData(
        color: surfColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: borderColor, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Helvetica Neue',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tPrimary,
          side: BorderSide(color: borderColor),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Helvetica Neue',
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        labelStyle: TextStyle(color: tSecondary),
        hintStyle: TextStyle(color: tTertiary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfColor,
        selectedItemColor: primary,
        unselectedItemColor: tTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? surfaceElevatedDark : surfColor,
        contentTextStyle: TextStyle(
          fontFamily: 'Helvetica Neue',
          color: tPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: isDark ? BorderSide.none : BorderSide(color: borderColor),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: borderColor, width: 1),
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Helvetica Neue',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: tPrimary,
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'Helvetica Neue',
          fontSize: 15,
          color: tSecondary,
        ),
      ),
    );
  }
}
