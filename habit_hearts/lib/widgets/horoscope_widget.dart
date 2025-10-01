import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/horoscope_provider.dart';
import '../providers/habit_hearts_auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/dark_mode_provider.dart';
import '../models/horoscope.dart';
import '../services/api_service.dart';
import '../services/horoscope_service.dart';

class HoroscopeWidget extends StatefulWidget {
  const HoroscopeWidget({super.key});

  @override
  State<HoroscopeWidget> createState() => _HoroscopeWidgetState();
}

class _HoroscopeWidgetState extends State<HoroscopeWidget> {
  @override
  void initState() {
    super.initState();
    // Fetch horoscope when widget is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final horoscopeProvider = Provider.of<HoroscopeProvider>(context, listen: false);
      horoscopeProvider.fetchTodaysHoroscope();
    });
  }

  @override
  Widget build(BuildContext context) {
    final horoscopeProvider = Provider.of<HoroscopeProvider>(context);
    final authProvider = Provider.of<HabitHeartsAuthProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final darkModeProvider = Provider.of<DarkModeProvider>(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Today\'s Horoscope',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.selectedColor,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    size: 18,
                    color: themeProvider.selectedColor,
                  ),
                  onPressed: () {
                    horoscopeProvider.refreshHoroscope();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (horoscopeProvider.isLoading)
              // Show loading indicator when fetching horoscope
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(height: 6),
                      Text('Loading horoscope...', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              )
            else if (horoscopeProvider.todaysHoroscope != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: themeProvider.selectedColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: themeProvider.selectedColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getZodiacIcon(horoscopeProvider.todaysHoroscope!.sunSign),
                          color: themeProvider.selectedColor,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          horoscopeProvider.todaysHoroscope!.sunSign,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: themeProvider.selectedColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: darkModeProvider.isDarkMode
                          ? Colors.grey[850]?.withOpacity(0.5)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: themeProvider.selectedColor.withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      horoscopeProvider.todaysHoroscope!.horoscopeText,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: darkModeProvider.isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildInfoCard('Mood', horoscopeProvider.todaysHoroscope!.mood, themeProvider.selectedColor, Icons.sentiment_satisfied, darkModeProvider),
                      const SizedBox(width: 8),
                      _buildInfoCard('Compatibility', horoscopeProvider.todaysHoroscope!.compatibility, themeProvider.selectedColor, Icons.favorite, darkModeProvider),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Linked Partners' Horoscopes Section
                  Consumer<HabitHeartsAuthProvider>(
                    builder: (context, authProvider, child) {
                      final user = authProvider.habitHeartsUser;
                      if (user?.linkedUsers.isEmpty ?? true) {
                        return const SizedBox.shrink(); // Hide if no linked users
                      }
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Partners\' Horoscopes',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Fetch partner details and show their horoscopes
                          FutureBuilder<Map<String, dynamic>>(
                            future: _fetchPartnerDetailsAndHoroscopes(authProvider, horoscopeProvider),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.0),
                                  child: Center(
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 1.5),
                                    ),
                                  ),
                                );
                              }
                              
                              if (snapshot.hasError || !snapshot.hasData) {
                                return const Text('Error loading partner horoscopes');
                              }
                              
                              final data = snapshot.data!;
                              final partnerDetails = data['partnerDetails'] as Map<String, dynamic>;
                              final partnerHoroscopes = data['horoscopes'] as Map<String, Horoscope>;
                              
                              return Column(
                                children: partnerDetails.entries.map((entry) {
                                  final partnerId = entry.key;
                                  final partnerData = entry.value;
                                  final partnerHoroscope = partnerHoroscopes[partnerId];
                                  
                                  if (partnerHoroscope == null) {
                                    return const SizedBox.shrink();
                                  }
                                  
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: darkModeProvider.isDarkMode
                                          ? Colors.grey[800]?.withOpacity(0.5)
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: themeProvider.selectedColor.withOpacity(0.2),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          partnerData['displayName'] ?? 'Partner',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: themeProvider.selectedColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          partnerHoroscope.horoscopeText,
                                          style: TextStyle(
                                            fontSize: 12,
                                            height: 1.3,
                                            color: darkModeProvider.isDarkMode 
                                                ? Colors.white60 
                                                : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _showZodiacSelectionDialog(context, authProvider, horoscopeProvider),
                      child: Text(
                        horoscopeProvider.userZodiacSign != null ? 'Change Sign' : 'Set Sign',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeProvider.selectedColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(height: 6),
                      Text('Loading...', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, Color color, IconData icon, DarkModeProvider darkModeProvider) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: darkModeProvider.isDarkMode
              ? Colors.grey[850]
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 16,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: darkModeProvider.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: darkModeProvider.isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getZodiacIcon(String zodiacSign) {
    switch (zodiacSign.toLowerCase()) {
      case 'aries':
        return Icons.star;
      case 'taurus':
        return Icons.emoji_nature;
      case 'gemini':
        return Icons.tag;
      case 'cancer':
        return Icons.waves;
      case 'leo':
        return Icons.auto_awesome;
      case 'virgo':
        return Icons.local_florist;
      case 'libra':
        return Icons.balance;
      case 'scorpio':
        return Icons.auto_awesome;
      case 'sagittarius':
        return Icons.explore;
      case 'capricorn':
        return Icons.flag;
      case 'aquarius':
        return Icons.water_drop;
      case 'pisces':
        return Icons.waves;
      default:
        return Icons.auto_awesome;
    }
  }

  void _showZodiacSelectionDialog(BuildContext context, HabitHeartsAuthProvider authProvider, HoroscopeProvider horoscopeProvider) {
    final List<String> zodiacSigns = [
      'Aries', 'Taurus', 'Gemini', 'Cancer', 
      'Leo', 'Virgo', 'Libra', 'Scorpio', 
      'Sagittarius', 'Capricorn', 'Aquarius', 'Pisces'
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Your Zodiac Sign'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SizedBox(
                width: double.maxFinite,
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: zodiacSigns.map((sign) {
                    return FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getZodiacIcon(sign),
                            size: 14,
                            color: horoscopeProvider.userZodiacSign == sign 
                                ? Colors.white 
                                : Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(sign),
                        ],
                      ),
                      selected: horoscopeProvider.userZodiacSign == sign,
                      selectedColor: Theme.of(context).primaryColor,
                      onSelected: (selected) async {
                        if (selected) {
                          // Close the dialog immediately to provide better UX
                          if (context.mounted) {
                            Navigator.of(context).pop(); 
                          }
                          
                          try {
                            // Update the user's zodiac sign in the database
                            await authProvider.updateUserZodiacSign(sign);
                            // Update the provider immediately
                            horoscopeProvider.userZodiacSign = sign;
                            // Fetch the horoscope in the background
                            await horoscopeProvider.fetchTodaysHoroscope();
                          } catch (error) {
                            // Show error message if the update fails
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error setting zodiac sign: $error')),
                              );
                            }
                          }
                        }
                      },
                    );
                  }).toList(),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
  
  // Helper method to fetch partner details and generate their horoscopes
  Future<Map<String, dynamic>> _fetchPartnerDetailsAndHoroscopes(
    HabitHeartsAuthProvider authProvider,
    HoroscopeProvider horoscopeProvider,
  ) async {
    final user = authProvider.habitHeartsUser;
    if (user?.linkedUsers.isEmpty ?? true) {
      return {'partnerDetails': {}, 'horoscopes': {}};
    }
    
    // Fetch actual partner details from the database
    Map<String, dynamic> partnerDetails = {};
    Map<String, Horoscope> partnerHoroscopes = {};
    
    // Fetch partner details using the API service
    try {
      final partnerDetailsMap = await ApiService.getBatchUsers(user!.linkedUsers);
      
      for (String partnerId in user.linkedUsers) {
        final partner = partnerDetailsMap[partnerId];
        partnerDetails[partnerId] = {
          'uid': partnerId,
          'displayName': partner?.displayName ?? 'Partner $partnerId',
          'zodiacSign': partner?.zodiacSign ?? 'Aries', // Default to Aries if not set
        };
        
        // Fetch horoscope for the partner's zodiac sign
        try {
          String horoscopeText = await HoroscopeService.getHoroscope(
            partner?.zodiacSign ?? 'Aries'
          );
          
          partnerHoroscopes[partnerId] = Horoscope(
            sunSign: partner?.zodiacSign ?? 'Aries',
            date: DateTime.now().toString().split(' ')[0],
            horoscopeText: horoscopeText,
            mood: 'Not shown', // Not displayed for partners
            compatibility: 'Not shown', // Not displayed for partners
          );
        } catch (e) {
          // Fallback if API fails
          partnerHoroscopes[partnerId] = Horoscope(
            sunSign: partner?.zodiacSign ?? 'Aries',
            date: DateTime.now().toString().split(' ')[0],
            horoscopeText: 'Unable to fetch horoscope for this partner.',
            mood: 'Not shown',
            compatibility: 'Not shown',
          );
        }
      }
    } catch (e) {
      print('Error fetching partner details: $e');
      // Fallback: create placeholder data
      for (String partnerId in user!.linkedUsers) {
        partnerDetails[partnerId] = {
          'uid': partnerId,
          'displayName': 'Partner $partnerId',
          'zodiacSign': 'Aries',
        };
        
        partnerHoroscopes[partnerId] = Horoscope(
          sunSign: 'Aries',
          date: DateTime.now().toString().split(' ')[0],
          horoscopeText: 'Unable to fetch partner details.',
          mood: 'Not shown',
          compatibility: 'Not shown',
        );
      }
    }
    
    return {'partnerDetails': partnerDetails, 'horoscopes': partnerHoroscopes};
  }
}