class Goal {
  final String id;
  final String text;
  final String? description;
  final bool completed;
  final String createdBy;
  final String creatorName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status;
  final String? emoji;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isHabit; // New field to distinguish habits from goals
  final bool isShared; // New field for sharing

  Goal({
    required this.id,
    required this.text,
    this.description,
    required this.completed,
    required this.createdBy,
    required this.creatorName,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.emoji,
    this.startDate,
    this.endDate,
    this.isHabit = false, // By default, it's a goal
    this.isShared = false, // By default, it's not shared
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'description': description,
      'completed': completed,
      'createdBy': createdBy,
      'creatorName': creatorName,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'status': status,
      'emoji': emoji,
      'startDate': startDate?.millisecondsSinceEpoch,
      'endDate': endDate?.millisecondsSinceEpoch,
      'isHabit': isHabit,
      'isShared': isShared,
    };
  }

  factory Goal.fromJson(Map<String, dynamic> json) {
    
    return Goal(
      id: json['id'],
      text: json['text'],
      description: json['description'],
      completed: json['completed'],
      createdBy: json['createdBy'],
      creatorName: json['creatorName'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt']),
      status: json['status'],
      emoji: json['emoji'],
      startDate: json['startDate'] != null ? DateTime.fromMillisecondsSinceEpoch(json['startDate']) : null,
      endDate: json['endDate'] != null ? DateTime.fromMillisecondsSinceEpoch(json['endDate']) : null,
      isHabit: json['isHabit'] ?? false,
      isShared: json['isShared'] ?? false,
    );
  }

  Goal copyWith({
    String? id,
    String? text,
    String? description,
    bool? completed,
    String? createdBy,
    String? creatorName,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
    String? emoji,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
    bool? isHabit,
    bool? isShared,
  }) {
    return Goal(
      id: id ?? this.id,
      text: text ?? this.text,
      description: description ?? this.description,
      completed: completed ?? this.completed,
      createdBy: createdBy ?? this.createdBy,
      creatorName: creatorName ?? this.creatorName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      emoji: emoji ?? this.emoji,
      startDate: clearStartDate ? null : (startDate != null ? startDate : this.startDate),
      endDate: clearEndDate ? null : (endDate != null ? endDate : this.endDate),
      isHabit: isHabit ?? this.isHabit,
      isShared: isShared ?? this.isShared,
    );
  }
}