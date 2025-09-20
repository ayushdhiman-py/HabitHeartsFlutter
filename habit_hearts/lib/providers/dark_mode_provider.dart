import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DarkModeProvider with ChangeNotifier {
  bool _isDarkMode = false;
  static const String _darkModeKey = 'is_dark_mode';

  DarkModeProvider() {
    _loadDarkModePreference();
  }

  bool get isDarkMode => _isDarkMode;

  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    _saveDarkModePreference();
    notifyListeners();
  }

  void setDarkMode(bool value) {
    _isDarkMode = value;
    _saveDarkModePreference();
    notifyListeners();
  }

  // Load dark mode preference from shared preferences
  Future<void> _loadDarkModePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDarkMode = prefs.getBool(_darkModeKey);
      
      if (savedDarkMode != null) {
        _isDarkMode = savedDarkMode;
      }
    } catch (e) {
      print('Error loading dark mode preference: $e');
    }
  }

  // Save dark mode preference to shared preferences
  Future<void> _saveDarkModePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_darkModeKey, _isDarkMode);
    } catch (e) {
      print('Error saving dark mode preference: $e');
    }
  }
}