import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class ThemeProvider with ChangeNotifier {
  Color _selectedColor = AppColors.mint;
  static const String _themeColorKey = 'selected_theme_color';

  ThemeProvider() {
    _loadThemePreferences();
  }

  Color get selectedColor => _selectedColor;

  void updateTheme(Color newColor) {
    _selectedColor = newColor;
    _saveThemePreferences();
    notifyListeners();
  }

  // Load theme preferences from shared preferences
  Future<void> _loadThemePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final colorValue = prefs.getInt(_themeColorKey);
      
      if (colorValue != null) {
        _selectedColor = Color(colorValue);
      }
    } catch (e) {
      print('Error loading theme preferences: $e');
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

  // List of available theme colors with better harmony
  static List<Color> get availableColors => [
        AppColors.electricBlue,
        AppColors.hotPink,
        AppColors.electricGreen,
        AppColors.vibrantOrange,
        AppColors.brightPurple,
        AppColors.sunnyYellow,
        AppColors.brightRed,
        AppColors.mint,
      ];
}