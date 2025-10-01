import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import '../providers/habit_hearts_auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/dark_mode_provider.dart';
import '../theme/app_theme.dart';
import '../models/user.dart' as habit_hearts_user;
import '../services/api_service.dart';
import 'dart:ui' as ui;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _partnerCodeController = TextEditingController();
  bool _isLinking = false;
  String? _linkError;
  Map<String, habit_hearts_user.User> _partnerDetails = {};
  bool _isLoadingPartnerDetails = false;
  String? _partnerDetailsError;

  @override
  void initState() {
    super.initState();
    _loadPartnerDetails();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload partner details when dependencies change (e.g., when coming back to this screen)
    _loadPartnerDetails();
  }

  @override
  void dispose() {
    _partnerCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadPartnerDetails() async {
    final authProvider = Provider.of<HabitHeartsAuthProvider>(context, listen: false);
    
    if (authProvider.habitHeartsUser?.linkedUsers.isNotEmpty == true) {
      setState(() {
        _isLoadingPartnerDetails = true;
        _partnerDetailsError = null;
      });
      
      try {
        final partnerDetails = await ApiService.getBatchUsers(authProvider.habitHeartsUser!.linkedUsers);
        if (mounted) {
          setState(() {
            _partnerDetails = partnerDetails;
            _isLoadingPartnerDetails = false;
          });
        }
      } catch (e) {
        print('Error loading partner details: $e');
        if (mounted) {
          setState(() {
            _isLoadingPartnerDetails = false;
            _partnerDetailsError = 'Failed to load partner details';
          });
        }
      }
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  Future<void> _linkWithPartner() async {
    final authProvider = Provider.of<HabitHeartsAuthProvider>(
      context,
      listen: false,
    );
    
    setState(() {
      _isLinking = true;
      _linkError = null;
    });

    try {
      await authProvider.linkWithPartner(_partnerCodeController.text);
      _partnerCodeController.clear();
      
      // Reload partner details after linking
      await _loadPartnerDetails();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully linked with partner')),
      );
    } catch (e) {
      setState(() {
        _linkError = 'Failed to link with partner. Please check the code.';
      });
    } finally {
      setState(() {
        _isLinking = false;
      });
    }
  }

  Future<void> _unlinkFromPartner(String partnerUid) async {
    final authProvider = Provider.of<HabitHeartsAuthProvider>(
      context,
      listen: false,
    );
    
    try {
      await authProvider.unlinkFromPartner(partnerUid);
      
      // Reload partner details after unlinking
      await _loadPartnerDetails();
      
      // Clear the partner details for the unlinked partner
      setState(() {
        _partnerDetails.remove(partnerUid);
        _isLoadingPartnerDetails = false;
        _partnerDetailsError = null;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully unlinked from partner')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to unlink from partner')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<HabitHeartsAuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final darkModeProvider = Provider.of<DarkModeProvider>(context);
    
    return Scaffold(
      appBar: _ThemedAppBar(title: 'Profile'),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Profile Section
              if (authProvider.user != null) ...[
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: authProvider.user?.photoURL != null
                            ? NetworkImage(authProvider.user!.photoURL!)
                            : null,
                        child: authProvider.user?.photoURL == null
                            ? const Icon(Icons.person, size: 40)
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        authProvider.user?.displayName ?? 'User',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        authProvider.user?.email ?? '',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              
              // Unique Code Section
              if (authProvider.habitHeartsUser != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Unique Code',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: _getThemeGradient(themeProvider.selectedColor),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: themeProvider.selectedColor,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                authProvider.habitHeartsUser!.uniqueCode,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: themeProvider.selectedColor,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.copy, 
                                  size: 20,
                                  color: themeProvider.selectedColor,
                                ),
                                onPressed: () {
                                  _copyToClipboard(
                                    authProvider.habitHeartsUser!.uniqueCode,
                                  );
                                },
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Share this code with your partner to link accounts',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),
              ],

              // Link with Partner Section
              if (authProvider.habitHeartsUser?.linkedUsers.isEmpty == true) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Link with Partner',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Consumer<DarkModeProvider>(
                          builder: (context, darkModeProvider, child) {
                            return TextField(
                              controller: _partnerCodeController,
                              style: TextStyle(
                                color: darkModeProvider.isDarkMode ? Colors.white : Colors.black,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Partner\'s Unique Code',
                                labelStyle: TextStyle(
                                  color: darkModeProvider.isDarkMode ? Colors.grey[300] : Colors.grey[700],
                                ),
                                border: const OutlineInputBorder(),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: darkModeProvider.isDarkMode ? Colors.grey[600]! : Colors.grey[400]!,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: themeProvider.selectedColor,
                                    width: 2.0,
                                  ),
                                ),
                                suffixIcon: _isLinking
                                    ? const Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : null,
                                errorText: _linkError,
                                errorStyle: TextStyle(
                                  color: darkModeProvider.isDarkMode ? Colors.redAccent : Colors.red,
                                ),
                              ),
                              enabled: !_isLinking,
                              cursorColor: themeProvider.selectedColor,
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLinking ? null : _linkWithPartner,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeProvider.selectedColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Link Accounts'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'You can link with one partner for free. To link with more partners, please consider buying a subscription.',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),
              ],
              
              // Theme Selection Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Theme Color',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Select your favorite color theme',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 50,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            // Solid colors using the simpler approach
                            for (Color color in ThemeProvider.availableColors)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () {
                                    themeProvider.updateTheme(color);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Theme updated to ${AppColors.getColorName(color)}',
                                        ),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: color == themeProvider.selectedColor
                                          ? Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            )
                                          : null,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 3,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),
              
              // Linked Partners Section
              if (authProvider.habitHeartsUser?.linkedUsers.isNotEmpty == true) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Linked Partners',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'You are currently linked with the following partners (only one partner can be linked at a time):',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'To link with a different partner, please unlink first.',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
              
              const SizedBox(height: 8),
                        // Display linked partners with their details
                        if (_isLoadingPartnerDetails) ...[
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Text(
                                'Loading partner details...',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                        ] else if (_partnerDetailsError != null) ...[
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text(
                                'Error: $_partnerDetailsError',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.coralRed,
                                ),
                              ),
                            ),
                          ),
                        ] else
                          for (String partnerId in authProvider.habitHeartsUser!.linkedUsers)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                leading: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: themeProvider.selectedColor,
                                  backgroundImage: _partnerDetails.containsKey(partnerId) && 
                                      _partnerDetails[partnerId]!.photoURL != null
                                      ? NetworkImage(_partnerDetails[partnerId]!.photoURL!)
                                      : null,
                                  child: (_partnerDetails.containsKey(partnerId) && 
                                          _partnerDetails[partnerId]!.photoURL == null) || 
                                        !_partnerDetails.containsKey(partnerId)
                                      ? const Icon(
                                          Icons.person,
                                          size: 20,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                title: Text(
                                  _partnerDetails.containsKey(partnerId) 
                                    ? _partnerDetails[partnerId]!.displayName ?? 'Partner'
                                    : 'Partner',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                subtitle: _partnerDetails.containsKey(partnerId)
                                  ? Text(
                                      _partnerDetails[partnerId]!.email ?? '',
                                      style: const TextStyle(fontSize: 12),
                                    )
                                  : null,
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.link_off,
                                    size: 20,
                                    color: AppColors.coralRed,
                                  ),
                                  onPressed: () => _unlinkFromPartner(partnerId),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),
              ],
              
              // Sign Out Button
              Center(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Sign Out'),
                            content: const Text(
                                'Are you sure you want to sign out?'),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  authProvider.signOut();
                                },
                                child: const Text(
                                  'Sign Out',
                                  style: TextStyle(color: AppColors.coralRed),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.coralRed,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 45),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('Sign Out'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
    String _getColorName(Color color) {
    return AppColors.getColorName(color);
  }
  
  Color _getDarkerShade(Color color) {
    // Calculate a darker shade by reducing brightness
    final hsv = HSVColor.fromColor(color);
    final darker = hsv.withValue((hsv.value * 0.7).clamp(0.0, 1.0));
    return darker.toColor();
  }
  
  Gradient _getThemeGradient(Color baseColor) {
    // Return a simple gradient with the base color and its lighter shade for a subtle effect
    return LinearGradient(
      colors: [baseColor.withOpacity(0.3), baseColor.withOpacity(0.1)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}

class _ThemedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  
  const _ThemedAppBar({required this.title});
  
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<HabitHeartsAuthProvider>(context);
    return Consumer<DarkModeProvider>(
      builder: (context, darkModeProvider, child) {
        return AppBar(
          systemOverlayStyle: darkModeProvider.isDarkMode 
              ? SystemUiOverlayStyle.light 
              : SystemUiOverlayStyle.dark,
          title: Consumer<HabitHeartsAuthProvider>(
            builder: (context, authProvider, child) {
                  String subscriptionText = 'Free';
                  Color subscriptionColor = themeProvider.selectedColor;
                  Color subscriptionBgColor = themeProvider.selectedColor.withOpacity(0.15);
                  
                  if (authProvider.habitHeartsUser != null) {
                    String sub = authProvider.habitHeartsUser!.subscription.toLowerCase();
                    switch (sub) {
                      case 'premium':
                        subscriptionText = 'Premium';
                        subscriptionColor = const Color(0xFFFF9800); // Orange
                        subscriptionBgColor = const Color(0xFFFF9800).withOpacity(0.2);
                        break;
                      case 'family':
                        subscriptionText = 'Family';
                        subscriptionColor = const Color(0xFF9C27B0); // Purple
                        subscriptionBgColor = const Color(0xFF9C27B0).withOpacity(0.2);
                        break;
                      default:
                        subscriptionText = 'Free';
                        subscriptionColor = themeProvider.selectedColor;
                        subscriptionBgColor = themeProvider.selectedColor.withOpacity(0.15);
                    }
                  }
                  
              return GestureDetector(
                onTap: () {
                  _showSubscriptionModal(context, themeProvider, darkModeProvider);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: subscriptionBgColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: subscriptionColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.workspace_premium,
                        size: 16,
                        color: subscriptionColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Current Plan: $subscriptionText',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: subscriptionColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          titleTextStyle: TextStyle(
            color: darkModeProvider.isDarkMode ? Colors.white : Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          backgroundColor: Colors.transparent,
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
              child: Container(
                color: themeProvider.selectedColor.withOpacity(0.3),
              ),
            ),
          ),
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(
                darkModeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              ),
              onPressed: () {
                darkModeProvider.toggleDarkMode();
              },
            ),

          ],
        );
      },
    );
  }
  
  void _showSubscriptionModal(BuildContext context, ThemeProvider themeProvider, DarkModeProvider darkModeProvider) {
    // Get the user's current subscription
    final authProvider = Provider.of<HabitHeartsAuthProvider>(context, listen: false);
    String currentSubscription = 'free';
    if (authProvider.habitHeartsUser != null) {
      currentSubscription = authProvider.habitHeartsUser!.subscription.toLowerCase();
    }
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95, // 95% of screen width
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85, // 85% of screen height max
            ),
            decoration: BoxDecoration(
              color: darkModeProvider.isDarkMode ? AppColors.darkBackground : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with gradient
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        themeProvider.selectedColor,
                        themeProvider.selectedColor.withOpacity(0.9),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Subscription Plans',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose the plan that fits your needs',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content with plans
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        _buildSubscriptionCard(
                          context, 
                          'Free Plan', 
                          'Perfect for getting started', 
                          '\$0/month', 
                          [
                            '1 fun game only from all the games 🎮',
                            '10 shared/unshared tasks/goals/events/habits 📋',
                            'Limited theme colors 🎨',
                            'Link with up to 1 partner 👥',
                            'Shared heatmap 📊',
                          ],
                          isCurrent: currentSubscription == 'free',
                          themeProvider: themeProvider,
                          darkModeProvider: darkModeProvider,
                        ),
                        const SizedBox(height: 12),
                        _buildSubscriptionCard(
                          context, 
                          'Premium Plan', 
                          'For dedicated habit builders', 
                          '\$4.99/month', 
                          [
                            'All the games 🎮',
                            'All theme colors 🎨',
                            'Book reading 📚',
                            'Dark/light theme 🌗',
                            'Link with up to 4 partners 👥',
                            'Shared heatmap 📈',
                            'Shared Mood tracker 😊',
                            'Shared Spin the wheel (with custom truth & dares) 🎡',
                            '20 shared/unshared tasks/goals/events/habits 📋',
                          ],
                          themeProvider: themeProvider,
                          darkModeProvider: darkModeProvider,
                          isCurrent: currentSubscription == 'premium',
                        ),
                        const SizedBox(height: 12),
                        _buildSubscriptionCard(
                          context, 
                          'Supreme Plan', 
                          'For the ultimate experience', 
                          '\$10.00/month', 
                          [
                            'All games 🎮',
                            'All theme colors 🎨',
                            'Book reading with live call 📚',
                            'Dark/light theme 🌗',
                            'Link with up to 10 partners 👥',
                            'Shared Personal daily horoscopes 🔮',
                            'Shared Mood tracker 😊',
                            'Special Shared bucket list 🎯',
                            'Spin the wheel (with custom truth & dares) 🎡',
                            'Unlimited shared/unshared tasks/goals/events/habits 📋',
                            'Shared heatmaps 📈',
                          ],
                          themeProvider: themeProvider,
                          darkModeProvider: darkModeProvider,
                          isCurrent: currentSubscription == 'family',
                        ),
                      ],
                    ),
                  ),
                ),
                // Close button
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeProvider.selectedColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildSubscriptionCard(
    BuildContext context,
    String title,
    String subtitle,
    String price,
    List<String> features,
    {
      bool isCurrent = false,
      required ThemeProvider themeProvider,
      required DarkModeProvider darkModeProvider,
    }
  ) {
    Color cardBgColor = darkModeProvider.isDarkMode 
      ? (isCurrent ? themeProvider.selectedColor.withOpacity(0.08) : Colors.grey[850]!) 
      : (isCurrent ? themeProvider.selectedColor.withOpacity(0.05) : Colors.grey[50]!);
    
    Color borderColor = isCurrent 
      ? themeProvider.selectedColor 
      : (darkModeProvider.isDarkMode ? Colors.grey[700]! : Colors.grey[200]!);
    
    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: isCurrent ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isCurrent 
                            ? themeProvider.selectedColor 
                            : (darkModeProvider.isDarkMode ? Colors.white : Colors.black87),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: darkModeProvider.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: darkModeProvider.isDarkMode 
                        ? Colors.grey[800] 
                        : themeProvider.selectedColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: darkModeProvider.isDarkMode 
                          ? Colors.grey[700]! 
                          : themeProvider.selectedColor.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    price,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: themeProvider.selectedColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...features.map((feature) {
              // Split the feature into text and emoji
              String emoji = '';
              String text = feature;
              
              // Find the emoji at the end (if it exists)
              if (feature.contains('🎮')) {
                int index = feature.lastIndexOf('🎮');
                text = feature.substring(0, index).trim();
                emoji = '🎮';
              } else if (feature.contains('📋')) {
                int index = feature.lastIndexOf('📋');
                text = feature.substring(0, index).trim();
                emoji = '📋';
              } else if (feature.contains('🎨')) {
                int index = feature.lastIndexOf('🎨');
                text = feature.substring(0, index).trim();
                emoji = '🎨';
              } else if (feature.contains('👥')) {
                int index = feature.lastIndexOf('👥');
                text = feature.substring(0, index).trim();
                emoji = '👥';
              } else if (feature.contains('📊')) {
                int index = feature.lastIndexOf('📊');
                text = feature.substring(0, index).trim();
                emoji = '📊';
              } else if (feature.contains('😊')) {
                int index = feature.lastIndexOf('😊');
                text = feature.substring(0, index).trim();
                emoji = '😊';
              } else if (feature.contains('🎡')) {
                int index = feature.lastIndexOf('🎡');
                text = feature.substring(0, index).trim();
                emoji = '🎡';
              } else if (feature.contains('🎯')) {
                int index = feature.lastIndexOf('🎯');
                text = feature.substring(0, index).trim();
                emoji = '🎯';
              } else if (feature.contains('🔮')) {
                int index = feature.lastIndexOf('🔮');
                text = feature.substring(0, index).trim();
                emoji = '🔮';
              } else if (feature.contains('📚')) {
                int index = feature.lastIndexOf('📚');
                text = feature.substring(0, index).trim();
                emoji = '📚';
              } else if (feature.contains('🌗')) {
                int index = feature.lastIndexOf('🌗');
                text = feature.substring(0, index).trim();
                emoji = '🌗';
              } else if (feature.contains('📈')) {
                int index = feature.lastIndexOf('📈');
                text = feature.substring(0, index).trim();
                emoji = '📈';
              }
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        color: themeProvider.selectedColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: themeProvider.selectedColor,
                          width: 1.2,
                        ),
                      ),
                      child: Icon(
                        Icons.check,
                        size: 12,
                        color: themeProvider.selectedColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              text,
                              style: TextStyle(
                                fontSize: 13,
                                color: darkModeProvider.isDarkMode ? Colors.white70 : Colors.black87,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            child: Text(
                              emoji,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isCurrent ? null : () {
                  // Handle subscription selection
                  _showPaymentConfirmationModal(context, title, themeProvider, darkModeProvider);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCurrent 
                    ? (darkModeProvider.isDarkMode 
                        ? themeProvider.selectedColor.withOpacity(0.1) 
                        : Colors.grey[300])
                    : themeProvider.selectedColor,
                  foregroundColor: isCurrent 
                    ? (darkModeProvider.isDarkMode 
                        ? Colors.white60 
                        : Colors.grey[500]) 
                    : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: isCurrent 
                      ? BorderSide(
                          color: darkModeProvider.isDarkMode 
                              ? Colors.grey[700]! 
                              : Colors.grey[400]!)
                      : BorderSide.none,
                  ),
                  elevation: isCurrent ? 0 : 2,
                  shadowColor: themeProvider.selectedColor.withOpacity(0.2),
                ),
                child: Text(
                  isCurrent ? 'Current Plan' : 'Select Plan',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
  
  void _showPaymentConfirmationModal(
    BuildContext context,
    String planTitle,
    ThemeProvider themeProvider,
    DarkModeProvider darkModeProvider,
  ) {
    String price = planTitle == 'Premium Plan' ? '\$4.99' : '\$10.00';
    String planEmoji = planTitle == 'Premium Plan' ? '⭐' : '👑'; // Star for Premium, crown for Supreme
    
    Navigator.of(context).pop(); // Close the subscription modal first
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: darkModeProvider.isDarkMode ? AppColors.darkBackground : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: const EdgeInsets.all(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  planEmoji,
                  style: const TextStyle(fontSize: 36),
                ),
                const SizedBox(height: 8),
                Text(
                  'Confirm Payment',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: darkModeProvider.isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Subscribe to $planTitle?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: darkModeProvider.isDarkMode ? Colors.grey[300] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: darkModeProvider.isDarkMode ? Colors.grey[800] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$price',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.selectedColor,
                        ),
                      ),
                      Text(
                        '/month',
                        style: TextStyle(
                          fontSize: 12,
                          color: darkModeProvider.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close confirmation modal
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: darkModeProvider.isDarkMode 
                              ? Colors.white 
                              : Colors.black,
                          side: BorderSide(
                            color: darkModeProvider.isDarkMode 
                                ? Colors.grey[600]! 
                                : Colors.grey[400]!,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // In a real app, this would redirect to a payment processor
                          Navigator.of(context).pop(); // Close confirmation modal
                          
                          // Show success message
                          final successSnackBar = SnackBar(
                            content: Text('🎉 ${planTitle} selected!'),
                            backgroundColor: themeProvider.selectedColor,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.all(16),
                            width: 300,
                            action: SnackBarAction(
                              label: 'OK',
                              onPressed: () {},
                            ),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(successSnackBar);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeProvider.selectedColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Confirm',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
