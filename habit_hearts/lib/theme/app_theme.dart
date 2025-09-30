import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // 20 vibrant, well-balanced solid colors for theme selection
  // To change a color, just modify the value here - it will update everywhere
  static const Color electricBlue = Color(0xFF4285F4);      // Google Blue
  static const Color hotPink = Color(0xFFEA4335);           // Google Red
  static const Color vibrantGreen = Color(0xFF34A853);      // Google Green
  static const Color sunsetOrange = Color(0xFFFF6B35);      // Sunset Orange
  static const Color royalPurple = Color(0xFF9B5DE5);       // Royal Purple
  static const Color goldenYellow = Color(0xFFFFC300);      // Golden Yellow
  static const Color coralRed = Color(0xFFFF7AA2);          // Coral Pink
  static const Color turquoiseBlue = Color(0xFF00C2CB);     // Turquoise
  static const Color forestGreen = Color(0xFF2A9D8F);       // Forest Green
  static const Color deepTeal = Color(0xFF0077B6);          // Deep Teal
  static const Color lavender = Color(0xFFB56576);          // Lavender
  static const Color mintGreen = Color(0xFF90BE6D);         // Mint Green
  static const Color peach = Color(0xFFF4A261);             // Peach
  static const Color periwinkle = Color(0xFF4A90E2);        // Periwinkle
  static const Color rose = Color(0xFFE76F51);              // Rose
  static const Color emerald = Color(0xFF2D7F6A);           // Emerald
  static const Color magenta = Color(0xFFE91E63);           // Magenta
  static const Color cyan = Color(0xFF00BCD4);              // Cyan
  static const Color amber = Color(0xFFFF9800);             // Amber
  static const Color indigo = Color(0xFF3F51B5);            // Indigo

  // Method to get all available theme colors
  static List<Color> get allThemeColors => [
        electricBlue,
        hotPink,
        vibrantGreen,
        sunsetOrange,
        royalPurple,
        goldenYellow,
        coralRed,
        turquoiseBlue,
        forestGreen,
        deepTeal,
        lavender,
        mintGreen,
        peach,
        periwinkle,
        rose,
        emerald,
        magenta,
        cyan,
        amber,
        indigo,
      ];

  // Method to get color name
  static String getColorName(Color color) {
    if (color == electricBlue) return 'Electric Blue';
    if (color == hotPink) return 'Hot Pink';
    if (color == vibrantGreen) return 'Vibrant Green';
    if (color == sunsetOrange) return 'Sunset Orange';
    if (color == royalPurple) return 'Royal Purple';
    if (color == goldenYellow) return 'Golden Yellow';
    if (color == coralRed) return 'Coral Red';
    if (color == turquoiseBlue) return 'Turquoise Blue';
    if (color == forestGreen) return 'Forest Green';
    if (color == deepTeal) return 'Deep Teal';
    if (color == lavender) return 'Lavender';
    if (color == mintGreen) return 'Mint Green';
    if (color == peach) return 'Peach';
    if (color == periwinkle) return 'Periwinkle';
    if (color == rose) return 'Rose';
    if (color == emerald) return 'Emerald';
    if (color == magenta) return 'Magenta';
    if (color == cyan) return 'Cyan';
    if (color == amber) return 'Amber';
    if (color == indigo) return 'Indigo';
    return 'Custom Color';
  }

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
      cardTheme: CardThemeData(
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
      cardTheme: CardThemeData(
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