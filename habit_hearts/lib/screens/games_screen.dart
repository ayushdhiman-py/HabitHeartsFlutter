import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/dark_mode_provider.dart';
import '../theme/app_theme.dart';
import 'dart:ui' as ui;

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final darkModeProvider = Provider.of<DarkModeProvider>(context);

    return Scaffold(
      appBar: _ThemedAppBar(title: 'Games'),
      body: Container(
        width: double.infinity,
        color: darkModeProvider.isDarkMode 
            ? AppColors.darkBackground 
            : AppColors.lightBackground,
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                'Games',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Coming Soon!',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  
  const _ThemedAppBar({required this.title});
  
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final darkModeProvider = Provider.of<DarkModeProvider>(context);
    
    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          color: darkModeProvider.isDarkMode ? Colors.white : Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: Colors.transparent,
      foregroundColor: darkModeProvider.isDarkMode ? Colors.white : Colors.black,
      elevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
          child: Container(
            color: themeProvider.selectedColor.withOpacity(0.3),
          ),
        ),
      ),
    );
  }
  
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}