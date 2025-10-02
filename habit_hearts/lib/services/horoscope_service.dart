import 'dart:convert';
import 'package:http/http.dart' as http;

class HoroscopeService {
  // Using a free horoscope API - multiple fallbacks for reliability
  static Future<String> getHoroscope(String zodiacSign) async {
    // Primary API: Ohmanda (free, no key required)
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
      print('Primary horoscope API failed: $e');
    }

    // Secondary API: Another free option (requires different format)
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
      print('Secondary horoscope API failed: $e');
    }

    // If both APIs fail, generate a reliable horoscope based on time
    return _generateTimeBasedHoroscope(zodiacSign);
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