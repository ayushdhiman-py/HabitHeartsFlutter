class Task {
  final String id;
  final String text;
  final String? description;
  final DateTime? dueDate;
  final bool completed;
  final String createdBy;
  final String creatorName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status;
  final String? emoji;
  final String? startTime;
  final String? endTime;

  Task({
    required this.id,
    required this.text,
    this.description,
    this.dueDate,
    required this.completed,
    required this.createdBy,
    required this.creatorName,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.emoji,
    this.startTime,
    this.endTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'description': description,
      'dueDate': dueDate?.millisecondsSinceEpoch,
      'completed': completed,
      'createdBy': createdBy,
      'creatorName': creatorName,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'status': status,
      'emoji': emoji,
      'startTime': startTime,
      'endTime': endTime,
    };
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      text: json['text'],
      description: json['description'],
      dueDate: json['dueDate'] != null ? DateTime.fromMillisecondsSinceEpoch(json['dueDate']) : null,
      completed: json['completed'],
      createdBy: json['createdBy'],
      creatorName: json['creatorName'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt']),
      status: json['status'],
      emoji: json['emoji'],
      startTime: json['startTime'],
      endTime: json['endTime'],
    );
  }
}