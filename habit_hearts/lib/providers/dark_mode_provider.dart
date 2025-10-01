import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DarkModeProvider with ChangeNotifier {
  bool _isDarkMode = false;
  bool _isLoading = true;
  static const String _darkModeKey = 'is_dark_mode';

  DarkModeProvider() {
    _initializeDarkMode();
  }

  bool get isDarkMode => _isDarkMode;
  bool get isLoading => _isLoading;

  void toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    await _saveDarkModePreference();
    notifyListeners();
  }

  void setDarkMode(bool value) async {
    _isDarkMode = value;
    await _saveDarkModePreference();
    notifyListeners();
  }

  // Initialize dark mode preference
  Future<void> _initializeDarkMode() async {
    await _loadDarkModePreference();
    _isLoading = false;
    notifyListeners();
  }

  // Load dark mode preference from shared preferences
  Future<void> _loadDarkModePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDarkMode = prefs.getBool(_darkModeKey);
      
      if (savedDarkMode != null) {
        _isDarkMode = savedDarkMode;
      } else {
        // Default to false if no preference exists
        _isDarkMode = false;
      }
    } catch (e) {
      print('Error loading dark mode preference: $e');
      _isDarkMode = false; // Default to light mode on error
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