import 'package:flutter/foundation.dart';
import '../models/horoscope.dart';
import '../services/horoscope_service.dart';

class HoroscopeProvider extends ChangeNotifier {
  Horoscope? _todaysHoroscope;
  String? _userZodiacSign;
  DateTime? _lastFetched;
  bool _isLoading = false;

  Horoscope? get todaysHoroscope => _todaysHoroscope;
  String? get userZodiacSign => _userZodiacSign;
  bool get isLoading => _isLoading;

  set userZodiacSign(String? sign) {
    if (_userZodiacSign != sign) {
      print('HoroscopeProvider - Setting zodiac sign to: $sign (was: $_userZodiacSign)');
      _userZodiacSign = sign;
      // Force refresh of horoscope when zodiac sign changes
      if (sign != null) {
        fetchTodaysHoroscope();
      } else {
        // If sign is null, reset the horoscope and notify
        _todaysHoroscope = null;
        _lastFetched = null;
        notifyListeners();
      }
    } else {
      notifyListeners();
    }
  }

  // Fetch today's real horoscope
  Future<void> fetchTodaysHoroscope() async {
    print('HoroscopeProvider - fetchTodaysHoroscope called for sign: $_userZodiacSign');
    
    if (_userZodiacSign == null) {
      // If no zodiac sign is set, return a default message
      _todaysHoroscope = Horoscope(
        sunSign: 'Unknown',
        date: DateTime.now().toString().split(' ')[0],
        horoscopeText: 'Please set your zodiac sign in your profile to get personalized horoscopes.',
        mood: 'Neutral',
        compatibility: 'Not available',
      );
      _lastFetched = DateTime.now();
      print('HoroscopeProvider - No zodiac sign set, showing default message');
      notifyListeners();
      return;
    }

    // Check if we already have today's horoscope for this zodiac sign
    if (_lastFetched != null && 
        _lastFetched!.day == DateTime.now().day &&
        _lastFetched!.month == DateTime.now().month &&
        _lastFetched!.year == DateTime.now().year &&
        _todaysHoroscope?.sunSign == _userZodiacSign) {
      print('HoroscopeProvider - Already have today\'s horoscope for ${_userZodiacSign}, not fetching again');
      // Already fetched today's horoscope for this specific zodiac sign
      notifyListeners(); // Still notify in case other data changed
      return;
    }

    // Set loading state
    _isLoading = true;
    notifyListeners(); // Notify to show loading state

    try {
      // Fetch real horoscope from API
      _todaysHoroscope = await _fetchRealHoroscope(_userZodiacSign!);
      _lastFetched = DateTime.now();
      print('HoroscopeProvider - Successfully fetched horoscope for ${_userZodiacSign}');
    } finally {
      _isLoading = false;
      notifyListeners(); // Notify to update with new data and hide loading
    }
  }

  Future<Horoscope> _fetchRealHoroscope(String zodiacSign) async {
    try {
      // Fetch real horoscope text from API
      String horoscopeText = await HoroscopeService.getHoroscope(zodiacSign);
      
      // For mood and compatibility, we'll generate some values based on the zodiac sign
      // to maintain the same structure
      final List<String> moods = ['Optimistic', 'Cautious', 'Energetic', 'Reflective', 'Playful', 'Serious', 'Romantic', 'Ambitious'];
      final List<String> compatibilities = ['Leo', 'Scorpio', 'Aquarius', 'Virgo', 'Gemini', 'Pisces', 'Aries', 'Taurus', 'Cancer', 'Sagittarius', 'Capricorn'];

      // Create a seed based on the zodiac sign to make mood and compatibility somewhat consistent per sign
      int zodiacSeed = _calculateZodiacSeed(zodiacSign);
      int daySeed = DateTime.now().day;
      int combinedSeed = (zodiacSeed + daySeed) % 1000;

      return Horoscope(
        sunSign: zodiacSign,
        date: DateTime.now().toString().split(' ')[0],
        horoscopeText: horoscopeText,
        mood: moods[combinedSeed % moods.length],
        compatibility: compatibilities[combinedSeed % compatibilities.length],
      );
    } catch (e) {
      print('Error fetching real horoscope: $e');
      // Fallback to a default message if API fails
      return Horoscope(
        sunSign: zodiacSign,
        date: DateTime.now().toString().split(' ')[0],
        horoscopeText: 'Unable to fetch horoscope. Please check your connection.',
        mood: 'Neutral',
        compatibility: 'Not available',
      );
    }
  }

  // Helper function to convert zodiac sign to a numeric seed
  int _calculateZodiacSeed(String zodiacSign) {
    int seed = 0;
    for (int i = 0; i < zodiacSign.length; i++) {
      seed += zodiacSign.codeUnitAt(i);
    }
    return seed;
  }

  void refreshHoroscope() {
    _lastFetched = null;
    fetchTodaysHoroscope();
  }
}