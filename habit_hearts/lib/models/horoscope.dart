class Horoscope {
  final String sunSign;
  final String date;
  final String horoscopeText;
  final String mood;
  final String compatibility;

  Horoscope({
    required this.sunSign,
    required this.date,
    required this.horoscopeText,
    required this.mood,
    required this.compatibility,
  });

  factory Horoscope.fromJson(Map<String, dynamic> json) {
    return Horoscope(
      sunSign: json['sunSign'] ?? '',
      date: json['date'] ?? DateTime.now().toString().split(' ')[0],
      horoscopeText: json['horoscopeText'] ?? 'No horoscope available today.',
      mood: json['mood'] ?? 'Neutral',
      compatibility: json['compatibility'] ?? 'Not specified',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sunSign': sunSign,
      'date': date,
      'horoscopeText': horoscopeText,
      'mood': mood,
      'compatibility': compatibility,
    };
  }
}