class Goal {
  final String id;
  final String text;
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

  Goal({
    required this.id,
    required this.text,
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
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
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
    };
  }

  factory Goal.fromJson(Map<String, dynamic> json) {
    
    return Goal(
      id: json['id'],
      text: json['text'],
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
    );
  }

  Goal copyWith({
    String? id,
    String? text,
    bool? completed,
    String? createdBy,
    String? creatorName,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
    String? emoji,
    DateTime? startDate,
    DateTime? endDate,
    bool? isHabit,
  }) {
    return Goal(
      id: id ?? this.id,
      text: text ?? this.text,
      completed: completed ?? this.completed,
      createdBy: createdBy ?? this.createdBy,
      creatorName: creatorName ?? this.creatorName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      emoji: emoji ?? this.emoji,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isHabit: isHabit ?? this.isHabit,
    );
  }
}