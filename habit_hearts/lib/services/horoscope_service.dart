import 'dart:convert';
import 'package:http/http.dart' as http;

class HoroscopeService {
  // Using a free horoscope API
  static const String baseUrl = 'https://ohmanda.com/api/horoscope/';

  static Future<String> getHoroscope(String zodiacSign) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl${zodiacSign.toLowerCase()}'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // The API returns data in a 'horoscope' field
        return data['horoscope'] ?? 'Daily horoscope not available at the moment.';
      } else {
        return 'Unable to fetch horoscope. Please try again later.';
      }
    } catch (e) {
      print('Error fetching horoscope: $e');
      return 'Unable to fetch horoscope. Please check your connection.';
    }
  }
}