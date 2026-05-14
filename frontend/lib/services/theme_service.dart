import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  late SharedPreferences _prefs;
  
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeService._();
  static final ThemeService instance = ThemeService._();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final String? savedTheme = _prefs.getString(_themeKey);
    
    if (savedTheme == 'light') {
      _themeMode = ThemeMode.light;
    } else if (savedTheme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.dark; // Default to dark as per current app style
    }
    notifyListeners();
  }

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
