class Task {
  final String id;
  final String text;
  final String? description;
  final DateTime? dueDate;
  final bool completed;
  final String? completedBy; // ID of the user who completed the task
  final String? completedByName; // Name of the user who completed the task
  final bool isCompletedByLinkedUser;
  final String createdBy;
  final String creatorName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status;
  final String? emoji;
  final String? time;
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
    this.time,
    this.isShared = false, // By default, it's not shared
    this.completedBy,
    this.completedByName,
    this.isCompletedByLinkedUser = false,
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
      'time': time,
      'isShared': isShared,
      'completedBy': completedBy,
      'completedByName': completedByName,
      'isCompletedByLinkedUser': isCompletedByLinkedUser,
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
      time: json['time'],
      isShared: json['isShared'] ?? false,
      completedBy: json['completedBy'],
      completedByName: json['completedByName'],
      isCompletedByLinkedUser: json['isCompletedByLinkedUser'] ?? false,
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
    String? time,
    bool? isShared,
    String? completedBy,
    String? completedByName,
    bool? isCompletedByLinkedUser,
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
      time: time ?? this.time,
      isShared: isShared ?? this.isShared,
      completedBy: completedBy ?? this.completedBy,
      completedByName: completedByName ?? this.completedByName,
      isCompletedByLinkedUser:
          isCompletedByLinkedUser ?? this.isCompletedByLinkedUser,
    );
  }
}