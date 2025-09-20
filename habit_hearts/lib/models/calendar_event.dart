class CalendarEvent {
  final String id;
  final String title;
  final String? description;
  final dynamic date; // DateTime, Timestamp, or String
  final dynamic endDate;
  final String? startTime;
  final String? endTime;
  final bool? completed;
  final String createdBy;
  final String creatorName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status;
  final String? emoji;

  CalendarEvent({
    required this.id,
    required this.title,
    this.description,
    required this.date,
    this.endDate,
    this.startTime,
    this.endTime,
    this.completed,
    required this.createdBy,
    required this.creatorName,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.emoji,
  });

  Map<String, dynamic> toJson() {
    // Handle date serialization
    dynamic serializedDate;
    if (date is DateTime) {
      serializedDate = (date as DateTime).millisecondsSinceEpoch;
    } else {
      serializedDate = date;
    }

    // Handle endDate serialization
    dynamic serializedEndDate;
    if (endDate is DateTime) {
      serializedEndDate = (endDate as DateTime).millisecondsSinceEpoch;
    } else {
      serializedEndDate = endDate;
    }

    return {
      'id': id,
      'title': title,
      'description': description,
      'date': serializedDate,
      'endDate': serializedEndDate,
      'startTime': startTime,
      'endTime': endTime,
      'completed': completed,
      'createdBy': createdBy,
      'creatorName': creatorName,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'status': status,
      'emoji': emoji,
    };
  }

  CalendarEvent copyWith({
    String? id,
    String? title,
    String? description,
    dynamic date,
    dynamic endDate,
    String? startTime,
    String? endTime,
    bool? completed,
    String? createdBy,
    String? creatorName,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
    String? emoji,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      endDate: endDate ?? this.endDate,
      startTime: _parseTimeString(startTime) ?? this.startTime,
      endTime: _parseTimeString(endTime) ?? this.endTime,
      completed: completed ?? this.completed,
      createdBy: createdBy ?? this.createdBy,
      creatorName: creatorName ?? this.creatorName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      emoji: emoji ?? this.emoji,
    );
  }

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    // Handle date parsing
    dynamic parsedDate;
    if (json['date'] is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(json['date']);
    } else if (json['date'] is String) {
      try {
        parsedDate = DateTime.parse(json['date']);
      } catch (e) {
        // print('Error parsing date string: $e');
        parsedDate = json['date']; // Keep as string if parsing fails
      }
    } else {
      parsedDate = json['date'];
    }

    // Handle endDate parsing
    dynamic parsedEndDate;
    if (json['endDate'] is int) {
      parsedEndDate = DateTime.fromMillisecondsSinceEpoch(json['endDate']);
    } else if (json['endDate'] is String) {
      try {
        parsedEndDate = DateTime.parse(json['endDate']);
      } catch (e) {
        // print('Error parsing endDate string: $e');
        parsedEndDate = json['endDate']; // Keep as string if parsing fails
      }
    } else {
      parsedEndDate = json['endDate'];
    }

    // Handle createdAt parsing
    DateTime parsedCreatedAt;
    if (json['createdAt'] is int) {
      parsedCreatedAt = DateTime.fromMillisecondsSinceEpoch(json['createdAt']);
    } else if (json['createdAt'] is String) {
      parsedCreatedAt = DateTime.parse(json['createdAt']);
    } else {
      parsedCreatedAt = json['createdAt'] as DateTime;
    }

    // Handle updatedAt parsing
    DateTime parsedUpdatedAt;
    if (json['updatedAt'] is int) {
      parsedUpdatedAt = DateTime.fromMillisecondsSinceEpoch(json['updatedAt']);
    } else if (json['updatedAt'] is String) {
      parsedUpdatedAt = DateTime.parse(json['updatedAt']);
    } else {
      parsedUpdatedAt = json['updatedAt'] as DateTime;
    }

    return CalendarEvent(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      date: parsedDate,
      endDate: parsedEndDate,
      startTime: _parseTimeString(json['startTime']),
      endTime: _parseTimeString(json['endTime']),
      completed: json['completed'],
      createdBy: json['createdBy'],
      creatorName: json['creatorName'],
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
      status: json['status'],
      emoji: json['emoji'],
    );
  }

  // Helper method to parse time strings and handle special characters
  static String? _parseTimeString(String? timeString) {
    if (timeString == null) return null;

    // Remove any non-breaking spaces or special characters
    String cleaned = timeString.replaceAll('\u00A0', ' ').trim();

    // Validate the format (should be HH:MM)
    RegExp timeRegex = RegExp(r'^\d{1,2}:\d{2}$');
    if (timeRegex.hasMatch(cleaned)) {
      return cleaned;
    }

    // If format is invalid, return null
    print('Invalid time format: $timeString (cleaned: $cleaned)');
    return null;
  }
}
