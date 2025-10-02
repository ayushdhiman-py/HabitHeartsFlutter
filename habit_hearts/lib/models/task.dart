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
  final bool isShared; // New field for sharing

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
    this.isShared = false, // By default, it's not shared
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
      'isShared': isShared,
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
      creatorName: json['creatorName'] ?? 'Unknown',
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt']),
      status: json['status'],
      emoji: json['emoji'],
      startTime: json['startTime'],
      endTime: json['endTime'],
      isShared: json['isShared'] ?? false,
    );
  }

  Task copyWith({
    String? id,
    String? text,
    String? description,
    DateTime? dueDate,
    bool? completed,
    String? createdBy,
    String? creatorName,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
    String? emoji,
    String? startTime,
    String? endTime,
    bool? isShared,
  }) {
    return Task(
      id: id ?? this.id,
      text: text ?? this.text,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      completed: completed ?? this.completed,
      createdBy: createdBy ?? this.createdBy,
      creatorName: creatorName ?? this.creatorName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      emoji: emoji ?? this.emoji,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isShared: isShared ?? this.isShared,
    );
  }
}