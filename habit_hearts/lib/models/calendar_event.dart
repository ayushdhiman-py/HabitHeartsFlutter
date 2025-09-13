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
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date is DateTime ? date.millisecondsSinceEpoch : date,
      'endDate': endDate is DateTime ? endDate.millisecondsSinceEpoch : endDate,
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
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
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
    return CalendarEvent(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      date: json['date'] is int ? DateTime.fromMillisecondsSinceEpoch(json['date']) : json['date'],
      endDate: json['endDate'] is int ? DateTime.fromMillisecondsSinceEpoch(json['endDate']) : json['endDate'],
      startTime: json['startTime'],
      endTime: json['endTime'],
      completed: json['completed'],
      createdBy: json['createdBy'],
      creatorName: json['creatorName'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt']),
      status: json['status'],
      emoji: json['emoji'],
    );
  }
}