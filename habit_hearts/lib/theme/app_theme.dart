import 'package:flutter/material.dart';

class AppColors {
  // Primary colors from the guide
  static const Color electricBlue = Color(0xFF00D4FF);
  static const Color hotPink = Color(0xFFFF2B9D);
  static const Color electricGreen = Color(0xFF4CAF50); // Softer, more pleasant green
  static const Color vibrantOrange = Color(0xFFFF6B00);
  static const Color brightPurple = Color(0xFF9D4AFF);
  static const Color sunnyYellow = Color(0xFFFFD400);
  static const Color brightRed = Color(0xFFFF2B2B);
  static const Color mint = Color(0xFF2BFFD4);
  
  // Additional colors for UI elements
  static const Color primaryBackground = Colors.white;
  static const Color secondaryBackground = Color(0xFFF5F5F5);
  static const Color textColor = Colors.black87;
  static const Color secondaryTextColor = Colors.black54;
  
  // Status colors
  static const Color success = Color(0xFF4CAF50); // Matching the new electricGreen
  static const Color error = Colors.red;
  static const Color warning = Colors.orange;
  static const Color info = Colors.blue;
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: AppColors.electricBlue,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.electricBlue,
        primary: AppColors.electricBlue,
        secondary: AppColors.hotPink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.electricBlue,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.electricBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.textColor,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.textColor,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textColor,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: AppColors.textColor,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: AppColors.secondaryTextColor,
        ),
      ),
    );
  }
}