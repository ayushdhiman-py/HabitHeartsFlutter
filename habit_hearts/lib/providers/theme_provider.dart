import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ThemeProvider with ChangeNotifier {
  Color _selectedColor = AppColors.electricBlue;

  Color get selectedColor => _selectedColor;

  void updateTheme(Color newColor) {
    _selectedColor = newColor;
    notifyListeners();
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