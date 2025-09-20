import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Modern gradient color palette with soft, friendly tones
  static const Color electricBlue = Color(0xFF9D84FF);     // Soft purple
  static const Color hotPink = Color(0xFFFF6AD4);          // Bright pink
  static const Color electricGreen = Color(0xFF48BB78);    // Green for success
  static const Color vibrantOrange = Color(0xFFFF8A8A);    // Soft coral
  static const Color brightPurple = Color(0xFFD4A8FF);     // Lavender
  static const Color sunnyYellow = Color(0xFFFFE36A);      // Sunshine yellow
  static const Color brightRed = Color(0xFFF56565);        // Red for errors
  static const Color mint = Color(0xFF8AE4FF);             // Sky blue
  
  // Dark theme colors
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkCardBackground = Color(0xFF1E1E1E);
  static const Color darkTextColor = Color(0xFFFFFFFF);
  static const Color darkSecondaryTextColor = Color(0xFFB0B0B0);
  static const Color darkBorderColor = Color(0xFF333333);
  
  // Light theme background colors (lighter shades)
  static const Color lightBackground = Color(0xFFFFFFFF);      // Pure white background
  static const Color lightCardBackground = Color(0xFFF8F9FA);  // Very light gray for cards
  static const Color lightSecondaryBackground = Color(0xFFE6EEF5); // Light blue
  
  // Gradient combinations
  static const List<Color> purpleToPinkGradient = [electricBlue, hotPink];
  static const List<Color> tealToBlueGradient = [mint, electricBlue];
  static const List<Color> greenToTealGradient = [electricGreen, mint];
  static const List<Color> coralToPinkGradient = [vibrantOrange, hotPink];
  
  // Background and text colors
  static const Color primaryBackground = Color(0xFFF8F9FA);     // Off-white background
  static const Color secondaryBackground = Color(0xFFE6EEF5);   // Lighter blue
  static const Color offWhiteBackground = Color(0xFFF8F9FA);    // Off-white background
  static const Color cardBackground = Color(0xFFF8F9FA);        // Off-white for cards
  static const Color textColor = Color(0xFF2D3748);             // Dark gray text
  static const Color secondaryTextColor = Color(0xFF718096);    // Muted gray text
  static const Color borderColor = Color(0xFFE2E8F0);           // Light border
  
  // Status colors
  static const Color success = Color(0xFF48BB78);               // Green for success
  static const Color error = Color(0xFFF56565);                 // Red for errors
  static const Color warning = Color(0xFFED8936);               // Orange for warnings
  static const Color info = Color(0xFF4299E1);                  // Blue for info
  static const Color completed = Color(0xFF48BB78);             // Green for completed items
}

class AppTheme {
  static ThemeData lightThemeWithColor(Color seedColor) {
    return ThemeData(
      useMaterial3: true,
      primaryColor: seedColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        primary: seedColor,
        secondary: AppColors.hotPink,
      ),
      scaffoldBackgroundColor: AppColors.lightBackground,
      textTheme: TextTheme(
        // Headings with Poppins (modern and clean)
        headlineLarge: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textColor),
        headlineMedium: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textColor),
        headlineSmall: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textColor),
        titleLarge: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textColor),
        titleMedium: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textColor),
        titleSmall: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textColor),
        // Body text with Open Sans (highly readable and professional)
        bodyLarge: GoogleFonts.openSans(fontSize: 16, color: AppColors.textColor),
        bodyMedium: GoogleFonts.openSans(fontSize: 14, color: AppColors.secondaryTextColor),
        bodySmall: GoogleFonts.openSans(fontSize: 12, color: AppColors.secondaryTextColor),
        labelLarge: GoogleFonts.openSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textColor),
        labelMedium: GoogleFonts.openSans(fontSize: 14, color: AppColors.textColor),
        labelSmall: GoogleFonts.openSans(fontSize: 12, color: AppColors.secondaryTextColor),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.textColor,
        elevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textColor,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightBackground,
        selectedItemColor: AppColors.electricBlue,
        unselectedItemColor: AppColors.secondaryTextColor,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.electricBlue,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.electricBlue,
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      cardTheme: CardTheme(
        color: AppColors.lightCardBackground,
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(
            color: AppColors.borderColor,
            width: 0.5,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightCardBackground.withOpacity(0.7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        hintStyle: GoogleFonts.openSans(
          color: AppColors.secondaryTextColor,
        ),
      ),
    );
  }
  
  static ThemeData darkThemeWithColor(Color seedColor) {
    return ThemeData(
      useMaterial3: true,
      primaryColor: seedColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        primary: seedColor,
        secondary: AppColors.hotPink,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      textTheme: TextTheme(
        // Headings with Poppins (modern and clean)
        headlineLarge: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.darkTextColor),
        headlineMedium: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.darkTextColor),
        headlineSmall: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkTextColor),
        titleLarge: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkTextColor),
        titleMedium: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkTextColor),
        titleSmall: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkTextColor),
        // Body text with Open Sans (highly readable and professional)
        bodyLarge: GoogleFonts.openSans(fontSize: 16, color: AppColors.darkTextColor),
        bodyMedium: GoogleFonts.openSans(fontSize: 14, color: AppColors.darkSecondaryTextColor),
        bodySmall: GoogleFonts.openSans(fontSize: 12, color: AppColors.darkSecondaryTextColor),
        labelLarge: GoogleFonts.openSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkTextColor),
        labelMedium: GoogleFonts.openSans(fontSize: 14, color: AppColors.darkTextColor),
        labelSmall: GoogleFonts.openSans(fontSize: 12, color: AppColors.darkSecondaryTextColor),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.darkTextColor,
        elevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.darkTextColor,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkBackground,
        selectedItemColor: AppColors.electricBlue,
        unselectedItemColor: AppColors.darkSecondaryTextColor,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.electricBlue,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.electricBlue,
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      cardTheme: CardTheme(
        color: AppColors.darkCardBackground,
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(
            color: AppColors.darkBorderColor,
            width: 0.5,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkCardBackground.withOpacity(0.7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        hintStyle: GoogleFonts.openSans(
          color: AppColors.darkSecondaryTextColor,
        ),
      ),
    );
  }
}