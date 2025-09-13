class GoalProgressSummary {
  final Map<String, String> monthlyData; // YYYY-MM -> bit string
  final int currentStreak;
  final int longestStreak;
  final DateTime lastUpdated;

  GoalProgressSummary({
    this.monthlyData = const {},
    this.currentStreak = 0,
    this.longestStreak = 0,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() {
    return {
      'monthlyData': monthlyData,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'lastUpdated': lastUpdated.millisecondsSinceEpoch,
    };
  }

  factory GoalProgressSummary.fromJson(Map<String, dynamic> json) {
    return GoalProgressSummary(
      monthlyData: Map<String, String>.from(json['monthlyData'] ?? {}),
      currentStreak: json['currentStreak'] ?? 0,
      longestStreak: json['longestStreak'] ?? 0,
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(
          json['lastUpdated'] is int
              ? json['lastUpdated']
              : (json['lastUpdated'] as Map<String, dynamic>).containsKey('_seconds')
                  ? json['lastUpdated']['_seconds'] * 1000
                  : json['lastUpdated']['seconds'] * 1000),
    );
  }

  // Helper methods for bit manipulation
  bool isDayCompleted(String yearMonth, int day) {
    if (!monthlyData.containsKey(yearMonth)) return false;
    
    String bitString = monthlyData[yearMonth]!;
    if (day < 1 || day > bitString.length) return false;
    
    int index = day - 1;
    return index < bitString.length && bitString[index] == '1';
  }

  String setDayCompleted(String yearMonth, int day, bool completed, int daysInMonth) {
    // Get existing bit string or create new one
    String bitString = monthlyData[yearMonth] ?? '0' * daysInMonth;
    
    // Ensure bit string has correct length
    if (bitString.length < daysInMonth) {
      bitString = bitString.padRight(daysInMonth, '0');
    } else if (bitString.length > daysInMonth) {
      bitString = bitString.substring(0, daysInMonth);
    }
    
    // Update the specific day
    if (day >= 1 && day <= bitString.length) {
      int index = day - 1;
      List<String> bits = bitString.split('');
      bits[index] = completed ? '1' : '0';
      bitString = bits.join('');
    }
    
    return bitString;
  }

  List<int> getCompletedDays(String yearMonth) {
    if (!monthlyData.containsKey(yearMonth)) return [];
    
    String bitString = monthlyData[yearMonth]!;
    List<int> completedDays = [];
    
    for (int i = 0; i < bitString.length; i++) {
      if (bitString[i] == '1') {
        completedDays.add(i + 1); // Convert to 1-based day
      }
    }
    
    return completedDays;
  }
}