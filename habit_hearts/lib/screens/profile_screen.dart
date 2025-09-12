import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import '../providers/habit_hearts_auth_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../models/user.dart' as habit_hearts_user;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _partnerCodeController = TextEditingController();
  bool _isLinking = false;
  String? _linkError;

  @override
  void dispose() {
    _partnerCodeController.dispose();
    super.dispose();
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
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              authProvider.signOut();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Profile Section
              if (authProvider.user != null) ...[
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: authProvider.user?.photoURL != null
                            ? NetworkImage(authProvider.user!.photoURL!)
                            : null,
                        child: authProvider.user?.photoURL == null
                            ? const Icon(Icons.person, size: 50)
                            : null,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        authProvider.user?.displayName ?? 'User',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        authProvider.user?.email ?? '',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
              
              // Unique Code Section
              if (authProvider.habitHeartsUser != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Unique Code',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: themeProvider.selectedColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: themeProvider.selectedColor,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                authProvider.habitHeartsUser!.uniqueCode,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: themeProvider.selectedColor,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 24),
                                onPressed: () {
                                  _copyToClipboard(
                                    authProvider.habitHeartsUser!.uniqueCode,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Share this code with your partner to link accounts',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              
              // Theme Selection Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Theme Color',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Select your favorite color theme',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        height: 60,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (Color color in ThemeProvider.availableColors)
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: GestureDetector(
                                  onTap: () {
                                    themeProvider.updateTheme(color);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Theme updated to ${_getColorName(color)}',
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: color == themeProvider.selectedColor
                                          ? Border.all(
                                              color: Colors.white,
                                              width: 3,
                                            )
                                          : null,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 5,
                                          offset: const Offset(0, 2),
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
              const SizedBox(height: 20),
              
              // Partner Linking Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Link with Partner',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Enter your partner\'s unique code to link accounts',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: _partnerCodeController,
                        decoration: InputDecoration(
                          hintText: 'Enter partner code',
                          border: const OutlineInputBorder(),
                          errorText: _linkError,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _isLinking ? null : _linkWithPartner,
                        child: _isLinking
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text('Link with Partner'),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Note: Linking allows you to share habits, goals, and events with your partner',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Linked Partners Section
              if (authProvider.habitHeartsUser?.linkedUsers.isNotEmpty == true) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Linked Partners',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'You are currently linked with the following partners:',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 10),
                        // In a complete implementation, we would fetch partner details
                        // For now, we'll show the linked user IDs
                        for (String partnerId in authProvider.habitHeartsUser!.linkedUsers)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: themeProvider.selectedColor,
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text('Partner: ${partnerId.substring(0, min(partnerId.length, 8))}...'),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.link_off,
                                  color: AppColors.brightRed,
                                ),
                                onPressed: () => _unlinkFromPartner(partnerId),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              
              // Sign Out Button
              Center(
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
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('Sign Out'),
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
    return 'Custom Color';
  }
}