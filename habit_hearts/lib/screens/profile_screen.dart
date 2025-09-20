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
                                  color: _getDarkerShade(themeProvider.selectedColor),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 20),
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
                            // Solid colors
                            for (Color color in ThemeProvider.availableColors)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () {
                                    themeProvider.updateTheme(color);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Theme updated to ${_getColorName(color)}',
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
                            // Gradient options
                            for (var gradientOption in ThemeProvider.gradientOptions)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () {
                                    // For gradients, we'll use the first color as the primary color
                                    themeProvider.updateTheme(gradientOption.colors[0]);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Theme updated to ${gradientOption.name}',
                                        ),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: gradientOption.colors,
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      shape: BoxShape.circle,
                                      border: gradientOption.colors[0] == themeProvider.selectedColor
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
              
              // Partner Linking Section - Only show if no partner is linked
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
                        const SizedBox(height: 6),
                        const Text(
                          'Enter your partner\'s unique code to link accounts',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _partnerCodeController,
                          decoration: InputDecoration(
                            hintText: 'Enter partner code',
                            border: const OutlineInputBorder(),
                            errorText: _linkError,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLinking ? null : _linkWithPartner,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: _isLinking
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text('Link with Partner'),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Note: Linking allows you to share habits, goals, and events with your partner',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),
              ] else if (authProvider.habitHeartsUser?.linkedUsers.isNotEmpty == true) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Partner Linked',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'You currently have a partner linked. To link with a different partner, please unlink first.',
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
                                  color: AppColors.brightRed,
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
                                    color: AppColors.brightRed,
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
                                  style: TextStyle(color: AppColors.brightRed),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brightRed,
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
    if (color == AppColors.electricBlue) return 'Electric Blue';
    if (color == AppColors.hotPink) return 'Hot Pink';
    if (color == AppColors.electricGreen) return 'Electric Green';
    if (color == AppColors.vibrantOrange) return 'Vibrant Orange';
    if (color == AppColors.brightPurple) return 'Bright Purple';
    if (color == AppColors.sunnyYellow) return 'Sunny Yellow';
    if (color == AppColors.brightRed) return 'Bright Red';
    if (color == AppColors.mint) return 'Mint';
    if (color == AppColors.deepTeal) return 'Deep Teal';
    if (color == AppColors.coral) return 'Coral';
    if (color == AppColors.lavender) return 'Lavender';
    if (color == AppColors.mintGreen) return 'Mint Green';
    if (color == AppColors.peach) return 'Peach';
    if (color == AppColors.periwinkle) return 'Periwinkle';
    if (color == AppColors.rose) return 'Rose';
    if (color == AppColors.turquoise) return 'Turquoise';
    return 'Custom Color';
  }
  
  String _getGradientName(List<Color> colors) {
    // Find matching gradient option
    for (var gradientOption in ThemeProvider.gradientOptions) {
      if (listEquals(gradientOption.colors, colors)) {
        return gradientOption.name;
      }
    }
    return 'Gradient Theme';
  }
  
  Color _getDarkerShade(Color color) {
    // Calculate a darker shade by reducing brightness
    final hsv = HSVColor.fromColor(color);
    final darker = hsv.withValue((hsv.value * 0.7).clamp(0.0, 1.0));
    return darker.toColor();
  }
  
  Gradient _getThemeGradient(Color baseColor) {
    // Check if the base color matches any gradient's primary color
    for (var gradientOption in ThemeProvider.gradientOptions) {
      if (gradientOption.colors[0] == baseColor) {
        return LinearGradient(
          colors: gradientOption.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      }
    }
    
    // If no matching gradient, return a simple gradient with the base color and its darker shade
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
          title: Text(title),
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
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                authProvider.signOut();
              },
            ),
          ],
        );
      },
    );
  }
  
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}