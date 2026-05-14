import 'package:flutter/material.dart';

/// MedScan App Theme — Premium dark medical UI
class AppTheme {
  AppTheme._();

  // ─── Brand Colors ──────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryLight = Color(0xFF8B83FF);
  static const Color primaryDark = Color(0xFF4A42DB);

  static const Color accent = Color(0xFF00D9A6);
  static const Color accentLight = Color(0xFF33E4BC);

  static const Color error = Color(0xFFFF6B6B);
  static const Color warning = Color(0xFFFFB347);
  static const Color success = Color(0xFF4ECDC4);
  static const Color info = Color(0xFF74B9FF);

  // ─── Surface Colors ────────────────────────────────────────────────────────
  static const Color background = Color(0xFF0F0F1A);
  static const Color surface = Color(0xFF1A1A2E);
  static const Color surfaceVariant = Color(0xFF222240);
  static const Color surfaceElevated = Color(0xFF2A2A4A);
  static const Color surfaceBorder = Color(0xFF333360);

  // ─── Text Colors ───────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF0F0FF);
  static const Color textSecondary = Color(0xFFA0A0C0);
  static const Color textTertiary = Color(0xFF707090);

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
          ? [background, const Color(0xFF16162D)] 
          : [backgroundLight, const Color(0xFFE8EBF9)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
  }

  // ─── Shadows ───────────────────────────────────────────────────────────────
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.3),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> primaryShadow = [
    BoxShadow(
      color: primary.withOpacity(0.3),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> primaryShadowLight = [
    BoxShadow(
      color: primary.withOpacity(0.15),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  // ─── Border Radius ─────────────────────────────────────────────────────────
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;

  // ─── Theme Data ────────────────────────────────────────────────────────────
  // ─── Surface Colors (Light) ──────────────────────────────────────────────────
  static const Color backgroundLight = Color(0xFFF8F9FE);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFF1F4FF);
  static const Color surfaceElevatedLight = Color(0xFFE8EBF9);
  static const Color surfaceBorderLight = Color(0xFFE0E4F2);

  // ─── Text Colors (Light) ─────────────────────────────────────────────────────
  static const Color textPrimaryLight = Color(0xFF0F0F1A);
  static const Color textSecondaryLight = Color(0xFF40405A);
  static const Color textTertiaryLight = Color(0xFF5A5A7A);

  // ─── Shadows (Light) ─────────────────────────────────────────────────────────
  static List<BoxShadow> cardShadowLight = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  // ─── Theme Data ────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return _buildTheme(Brightness.dark);
  }

  static ThemeData get lightTheme {
    return _buildTheme(Brightness.light);
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    final Color bgColor = isDark ? background : backgroundLight;
    final Color surfColor = isDark ? surface : surfaceLight;
    final Color surfVariant = isDark ? surfaceVariant : surfaceVariantLight;
    final Color surfElevated = isDark ? surfaceElevated : surfaceElevatedLight;
    final Color borderColor = isDark ? surfaceBorder : surfaceBorderLight;
    final Color tPrimary = isDark ? textPrimary : textPrimaryLight;
    final Color tSecondary = isDark ? textSecondary : textSecondaryLight;
    final Color tTertiary = isDark ? textTertiary : textTertiaryLight;

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
              surface: surface,
              onSurface: textPrimary,
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
              error: error,
              onError: Colors.white,
            ),
      textTheme: (isDark ? ThemeData.dark() : ThemeData.light()).textTheme.apply(
        bodyColor: tPrimary,
        displayColor: tPrimary,
        fontFamily: 'Helvetica Neue',
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfColor,
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
        backgroundColor: isDark ? surfElevated : surfColor,
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
    );
  }
}
