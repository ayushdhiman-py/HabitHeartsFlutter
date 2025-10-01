import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class ThemeProvider with ChangeNotifier {
  Color _selectedColor = AppColors.electricBlue;
  bool _isLoading = true;
  static const String _themeColorKey = 'selected_theme_color';

  ThemeProvider() {
    _initializeThemePreferences();
  }

  Color get selectedColor => _selectedColor;
  bool get isLoading => _isLoading;

  void updateTheme(Color newColor) async {
    _selectedColor = newColor;
    await _saveThemePreferences();
    notifyListeners();
  }

  // Initialize theme preferences
  Future<void> _initializeThemePreferences() async {
    await _loadThemePreferences();
    _isLoading = false;
    notifyListeners();
  }

  // Load theme preferences from shared preferences
  Future<void> _loadThemePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final colorValue = prefs.getInt(_themeColorKey);
      
      if (colorValue != null) {
        _selectedColor = Color(colorValue);
      } else {
        // Default to electric blue if no preference exists
        _selectedColor = AppColors.electricBlue;
      }
    } catch (e) {
      print('Error loading theme preferences: $e');
      _selectedColor = AppColors.electricBlue; // Default to electric blue on error
    }
  }

  // Save theme preferences to shared preferences
  Future<void> _saveThemePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeColorKey, _selectedColor.value);
    } catch (e) {
      print('Error saving theme preferences: $e');
    }
  }

  // List of available theme colors
  static List<Color> get availableColors => AppColors.allThemeColors;
}