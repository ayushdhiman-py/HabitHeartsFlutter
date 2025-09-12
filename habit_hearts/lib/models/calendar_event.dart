class CalendarEvent {
  final String id;
  final String title;
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

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'],
      title: json['title'],
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