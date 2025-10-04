import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

// Cache entry for horoscope data
class _HoroscopeCacheEntry {
  final String horoscope;
  final int expiry; // Expiry time in milliseconds since epoch
  
  _HoroscopeCacheEntry(this.horoscope, this.expiry);
}

class HoroscopeService {
  // Cache for horoscope responses to avoid repeated API calls
  static final Map<String, _HoroscopeCacheEntry> _cache = {};
  
  static Future<String> getHoroscope(String zodiacSign) async {
    // Check cache first
    final cacheKey = '${zodiacSign}_${DateTime.now().day}';
    final cachedEntry = _cache[cacheKey];
    if (cachedEntry != null && 
        DateTime.now().millisecondsSinceEpoch < cachedEntry.expiry) {
      return cachedEntry.horoscope;
    }
    
    // Try all APIs in parallel to get the fastest response
    return _getHoroscopeWithTimeout(zodiacSign);
  }
  
  static Future<String> _getHoroscopeWithTimeout(String zodiacSign) async {
    final timeout = Duration(seconds: 5); // 5 second timeout
    
    // Start all API requests in parallel
    final futures = <Future<String>>[
      _fetchPrimaryHoroscope(zodiacSign),
      _fetchSecondaryHoroscope(zodiacSign),
    ];
    
    // Race all API calls with a timeout
    final raceFuture = Future.any([
      ...futures,
      Future.delayed(timeout).then((_) async => 
          _generateTimeBasedHoroscope(zodiacSign))
    ]);
    
    final result = await raceFuture;
    
    // Cache the result for the rest of the day
    final cacheKey = '${zodiacSign}_${DateTime.now().day}';
    final expiry = DateTime.now().add(Duration(hours: 24)).millisecondsSinceEpoch; // Cache for 24 hours
    _cache[cacheKey] = _HoroscopeCacheEntry(result, expiry);
    
    return result;
  }
  
  static Future<String> _fetchPrimaryHoroscope(String zodiacSign) async {
    try {
      final response = await http.get(
        Uri.parse('https://ohmanda.com/api/horoscope/${zodiacSign.toLowerCase()}'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final horoscope = data['horoscope'];
        if (horoscope != null && horoscope.toString().isNotEmpty) {
          return horoscope.toString();
        }
      }
    } catch (e) {
      // Don't log error, let other APIs try
    }
    throw Exception('Primary horoscope API failed');
  }

  static Future<String> _fetchSecondaryHoroscope(String zodiacSign) async {
    try {
      // Try the aztro API - a known free horoscope API
      final response = await http.post(
        Uri.parse('https://aztro.sameerkumar.website/?sign=${zodiacSign.toLowerCase()}&day=today'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String horoscopeText = data['description'] ?? '';
        if (horoscopeText.isNotEmpty) {
          return horoscopeText;
        }
      }
    } catch (e) {
      // Don't log error, let other APIs try
    }
    throw Exception('Secondary horoscope API failed');
  }

  // Generate a time-based horoscope that changes daily
  static String _generateTimeBasedHoroscope(String zodiacSign) {
    // Create a seed based on the zodiac sign and current date for some consistency
    int seed = zodiacSign.hashCode + DateTime.now().day + DateTime.now().month + DateTime.now().year;
    
    List<String> openingPhrases = [
      "Today brings new opportunities for $zodiacSign.",
      "$zodiacSign, the stars align in your favor today.",
      "Your cosmic energy is particularly strong today, $zodiacSign.",
      "The universe has special plans for $zodiacSign today.",
      "Expect the unexpected, $zodiacSign. Today might surprise you."
    ];
    
    List<String> middlePhrases = [
      "Focus on personal relationships and connections.",
      "Financial matters may require your attention.",
      "Health and wellness should be a priority today.",
      "Career opportunities are on the horizon.",
      "Trust your instincts and inner wisdom.",
      "Communication will be your key to success today.",
      "Take time for self-reflection and inner peace.",
      "Embrace change and new experiences today."
    ];
    
    List<String> closingPhrases = [
      "Trust the journey and enjoy the process.",
      "The best is yet to come for you.",
      "Remember to stay positive and open-minded.",
      "Your patience will be rewarded soon.",
      "Success comes to those who persist.",
      "Good things come to those who believe."
    ];

    int openingIndex = seed % openingPhrases.length;
    int middleIndex = (seed * 3) % middlePhrases.length;  // Different calculation
    int closingIndex = (seed * 7) % closingPhrases.length; // Different calculation

    return "${openingPhrases[openingIndex]} ${middlePhrases[middleIndex]} ${closingPhrases[closingIndex]}";
  }
}