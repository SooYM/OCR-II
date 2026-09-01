/// MedScan Application Theme & Brightness Management Service.
///
/// Manages reactive dark/light theme switching and persistent user preferences.
///
/// ### Simple Example:
/// ```dart
/// // Toggling the theme from a settings switch
/// ThemeService.instance.toggleTheme();
/// ```
///
/// ### Advanced Example:
/// ```dart
/// // Listening to theme changes in a widget
/// ListenableBuilder(
///   listenable: ThemeService.instance,
///   builder: (context, _) => Text('Dark mode: ${ThemeService.instance.isDarkMode}'),
/// );
/// ```
library theme_service;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reactive theme controller singleton managing active [ThemeMode].
class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  late SharedPreferences _prefs;

  ThemeMode _themeMode = ThemeMode.dark;

  /// The active [ThemeMode] (`ThemeMode.dark` or `ThemeMode.light`).
  ThemeMode get themeMode => _themeMode;

  /// Whether the app is currently displaying in dark theme.
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// Private constructor for singleton pattern.
  ThemeService._();

  /// Global singleton instance of [ThemeService].
  static final ThemeService instance = ThemeService._();

  /// Initializes the theme controller and loads saved brightness preference from disk.
  ///
  /// Defaults to dark theme if no prior preference was stored.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final String? savedTheme = _prefs.getString(_themeKey);

    if (savedTheme == 'light') {
      _themeMode = ThemeMode.light;
    } else {
      // Default to dark theme as per MedScan glassmorphism design identity
      _themeMode = ThemeMode.dark;
    }
    notifyListeners();
  }

  /// Toggles between light and dark themes, persisting the change to disk.
  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.dark) {
      _themeMode = ThemeMode.light;
      await _prefs.setString(_themeKey, 'light');
    } else {
      _themeMode = ThemeMode.dark;
      await _prefs.setString(_themeKey, 'dark');
    }
    notifyListeners();
  }
}
