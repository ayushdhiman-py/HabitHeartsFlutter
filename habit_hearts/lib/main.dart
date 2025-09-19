import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/habit_hearts_auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/goals_provider.dart';
import 'providers/calendar_provider.dart';
import 'providers/dark_mode_provider.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';
import 'services/api_service.dart';

import 'screens/home_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/goals_screen.dart';
import 'screens/profile_screen.dart';
import 'dart:ui' as ui;

// Widget to handle system UI overlay styling
class SystemUiOverlayController extends StatefulWidget {
  final DarkModeProvider darkModeProvider;
  final ThemeProvider themeProvider;
  final Widget child;

  const SystemUiOverlayController({
    super.key,
    required this.darkModeProvider,
    required this.themeProvider,
    required this.child,
  });

  @override
  State<SystemUiOverlayController> createState() => _SystemUiOverlayControllerState();
}

class _SystemUiOverlayControllerState extends State<SystemUiOverlayController> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateSystemUI();
  }

  @override
  void didUpdateWidget(covariant SystemUiOverlayController oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.darkModeProvider.isDarkMode != widget.darkModeProvider.isDarkMode ||
        oldWidget.themeProvider.selectedColor != widget.themeProvider.selectedColor) {
      _updateSystemUI();
    }
  }

  void _updateSystemUI() {
    // For glassmorphic effect, we'll use a semi-transparent version of the theme color
    // with appropriate brightness for status bar icons
    final statusBarColor = widget.themeProvider.selectedColor.withOpacity(0.3);
    
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: statusBarColor,
        statusBarIconBrightness: widget.darkModeProvider.isDarkMode ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: widget.darkModeProvider.isDarkMode 
            ? AppColors.darkBackground 
            : AppColors.lightBackground,
        systemNavigationBarIconBrightness: widget.darkModeProvider.isDarkMode ? Brightness.light : Brightness.dark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Clear API cache on app start
  ApiService.clearAllCache();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HabitHeartsAuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => GoalsProvider()),
        ChangeNotifierProvider(create: (_) => CalendarProvider()),
        ChangeNotifierProvider(create: (_) => DarkModeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DarkModeProvider>(
      builder: (context, darkModeProvider, child) {
        return MaterialApp(
          title: 'HabitHearts',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: darkModeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HabitHeartsAuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isAuthenticated) {
          return const MainScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late PageController _pageController;

  final List<Widget> _screens = [
    const HomeScreen(),
    const CalendarScreen(),
    const GoalsScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    // Jump to the page without rebuilding the whole screen
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DarkModeProvider>(
      builder: (context, darkModeProvider, child) {
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return SystemUiOverlayController(
              darkModeProvider: darkModeProvider,
              themeProvider: themeProvider,
              child: Scaffold(
                body: Container(
                  color: darkModeProvider.isDarkMode 
                      ? AppColors.darkBackground 
                      : AppColors.lightBackground,
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    children: _screens,
                  ),
                ),
                bottomNavigationBar: ClipRRect(
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0), // Match AppBar blur intensity
                      child: Container(
                        decoration: BoxDecoration(
                          color: themeProvider.selectedColor.withOpacity(0.3), // Match AppBar opacity
                          border: Border(
                            top: BorderSide(
                              color: themeProvider.selectedColor.withOpacity(0.25),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: BottomNavigationBar(
                          type: BottomNavigationBarType.fixed,
                          currentIndex: _currentIndex,
                          onTap: _onItemTapped,
                          backgroundColor: Colors.transparent,
                          selectedItemColor: darkModeProvider.isDarkMode 
                              ? Colors.white 
                              : Colors.black,
                          unselectedItemColor: darkModeProvider.isDarkMode 
                              ? Colors.white70 
                              : Colors.black54,
                          items: const [
                            BottomNavigationBarItem(
                              icon: Icon(Icons.home_outlined),
                              activeIcon: Icon(Icons.home),
                              label: 'Home',
                            ),
                            BottomNavigationBarItem(
                              icon: Icon(Icons.calendar_month_outlined),
                              activeIcon: Icon(Icons.calendar_month),
                              label: 'Calendar',
                            ),
                            BottomNavigationBarItem(
                              icon: Icon(Icons.flag_outlined),
                              activeIcon: Icon(Icons.flag),
                              label: 'Goals',
                            ),
                            BottomNavigationBarItem(
                              icon: Icon(Icons.person_outline),
                              activeIcon: Icon(Icons.person),
                              label: 'Profile',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
